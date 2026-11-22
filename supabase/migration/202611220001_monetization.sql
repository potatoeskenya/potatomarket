-- Potato Market Kenya monetization: 2% completed-sale commission + premium plans.
-- Apply after 202611210001_initial_marketplace.sql and 202611210002_marketplace_operations.sql.

-- Change the commission constraint safely for both new and future orders.
alter table public.orders alter column commission_rate set default 0.02;
alter table public.orders drop constraint if exists orders_commission_rate_check;
alter table public.orders add constraint orders_commission_rate_check check (commission_rate = 0.02);

create or replace function public.create_marketplace_order(p_product_id uuid, p_quantity numeric default 1)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_product public.products%rowtype; v_order_id uuid; v_subtotal numeric(12,2); v_fee numeric(12,2);
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if p_quantity is null or p_quantity<=0 then raise exception 'Quantity must be greater than zero'; end if;
 select * into v_product from public.products where id=p_product_id and status='active' for update;
 if not found then raise exception 'Listing is unavailable'; end if;
 if v_product.seller_id=auth.uid() then raise exception 'You cannot buy your own listing'; end if;
 if v_product.quantity<p_quantity then raise exception 'Insufficient stock'; end if;
 v_subtotal:=round(v_product.price*p_quantity,2);
 v_fee:=round(v_subtotal*0.02,2);
 insert into public.orders(buyer_id,seller_id,status,subtotal,commission_rate,commission_amount,total_amount)
 values(auth.uid(),v_product.seller_id,'awaiting_payment',v_subtotal,0.02,v_fee,v_subtotal) returning id into v_order_id;
 insert into public.order_items(order_id,product_id,title_snapshot,quantity,unit_price,line_total)
 values(v_order_id,v_product.id,v_product.title,p_quantity,v_product.price,v_subtotal);
 update public.products set quantity=quantity-p_quantity, updated_at=now() where id=v_product.id;
 return v_order_id;
end; $$;
revoke all on function public.create_marketplace_order(uuid,numeric) from public;
grant execute on function public.create_marketplace_order(uuid,numeric) to authenticated;

-- Featured listing state is controlled by administrators only; sellers cannot self-promote.
alter table public.products add column if not exists is_featured boolean not null default false;
alter table public.products add column if not exists featured_until timestamptz;
create or replace function public.protect_monetization_fields() returns trigger language plpgsql security definer set search_path=public as $$
begin
 if not public.is_admin() then
   if tg_op = 'INSERT' then
     new.is_featured := false;
     new.featured_until := null;
   else
     new.is_featured := old.is_featured;
     new.featured_until := old.featured_until;
   end if;
 end if;
 return new;
end; $$;
drop trigger if exists protect_monetization_fields_trigger on public.products;
create trigger protect_monetization_fields_trigger before insert or update on public.products for each row execute procedure public.protect_monetization_fields();
create index if not exists products_featured_idx on public.products(is_featured,featured_until,status,created_at desc);

-- Subscription catalogue and entitlement records. Payment creation/verification is intentionally server-only.
create table if not exists public.subscription_plans (
 id text primary key,
 name text not null,
 audience text not null check(audience in ('buyer','seller','both')),
 price_kes numeric(12,2) not null check(price_kes>0),
 duration_days integer not null check(duration_days>0),
 benefits text[] not null default '{}',
 active boolean not null default true,
 created_at timestamptz not null default now()
);
insert into public.subscription_plans(id,name,audience,price_kes,duration_days,benefits) values
 ('buyer_monthly','Buyer Pro','buyer',500,30,array['Priority access to bulk supplier listings','Saved supplier searches','Buyer request alerts']),
 ('buyer_annual','Buyer Pro Annual','buyer',5000,365,array['Priority access to bulk supplier listings','Saved supplier searches','Buyer request alerts']),
 ('seller_monthly','Seller Pro','seller',300,30,array['Featured listing eligibility','Enhanced seller profile','Listing performance insights'])
on conflict(id) do update set name=excluded.name,audience=excluded.audience,price_kes=excluded.price_kes,duration_days=excluded.duration_days,benefits=excluded.benefits;

create table if not exists public.user_subscriptions (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.profiles(id) on delete cascade,
 plan_id text not null references public.subscription_plans(id),
 status text not null default 'pending' check(status in ('pending','active','expired','cancelled','failed')),
 starts_at timestamptz,
 ends_at timestamptz,
 provider text not null default 'mpesa',
 provider_reference text unique,
 created_at timestamptz not null default now(),
 check((status='active' and starts_at is not null and ends_at is not null) or status<>'active')
);
create index if not exists user_subscriptions_user_status_idx on public.user_subscriptions(user_id,status,ends_at desc);
alter table public.subscription_plans enable row level security;
alter table public.user_subscriptions enable row level security;
drop policy if exists "active plans are public" on public.subscription_plans;
create policy "active plans are public" on public.subscription_plans for select using(active or public.is_admin());
drop policy if exists "users see own subscriptions" on public.user_subscriptions;
create policy "users see own subscriptions" on public.user_subscriptions for select using(user_id=auth.uid() or public.is_admin());
-- No client INSERT/UPDATE policies: trusted Edge Functions must verify M-Pesa before granting access.

-- Featured listing purchases are an auditable order request, not proof of payment.
create table if not exists public.featured_listing_purchases (
 id uuid primary key default gen_random_uuid(),
 product_id uuid not null references public.products(id) on delete cascade,
 seller_id uuid not null references public.profiles(id) on delete cascade,
 duration_days integer not null check(duration_days in (7,14,30)),
 amount_kes numeric(12,2) not null check(amount_kes>0),
 status text not null default 'pending' check(status in ('pending','paid','failed','cancelled')),
 provider_reference text unique,
 created_at timestamptz not null default now(),
 paid_at timestamptz
);
alter table public.featured_listing_purchases enable row level security;
drop policy if exists "seller sees own featured purchases" on public.featured_listing_purchases;
create policy "seller sees own featured purchases" on public.featured_listing_purchases for select using(seller_id=auth.uid() or public.is_admin());
-- Purchases and their paid/featured transitions are written only by trusted server functions.
