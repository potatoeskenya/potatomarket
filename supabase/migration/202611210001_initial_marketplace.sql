-- Kenya Potato Farmers Marketplace: initial schema
create extension if not exists pgcrypto;
create type public.account_role as enum ('buyer','seller','both','transporter','admin');
create type public.product_status as enum ('draft','active','paused','rejected','sold_out');
create type public.order_status as enum ('awaiting_payment','paid','processing','dispatched','delivered','completed','cancelled','disputed','refunded');
create type public.payment_status as enum ('pending','succeeded','failed','refunded');
create type public.payout_status as enum ('not_eligible','queued','processing','paid','failed','held');

create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text not null default '', username text unique,
 role public.account_role not null default 'buyer', farm_name text,
 county text, sub_county text, ward text, avatar_url text,
 rating numeric(3,2) not null default 0 check(rating between 0 and 5),
 rating_count integer not null default 0 check(rating_count>=0),
 verified_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.seller_payout_accounts (
 user_id uuid primary key references public.profiles(id) on delete cascade, phone text not null, provider text not null default 'mpesa', verified_at timestamptz, updated_at timestamptz not null default now()
);
create table public.products (
 id uuid primary key default gen_random_uuid(), seller_id uuid not null references public.profiles(id),
 title text not null, category text not null check(category in ('Certified seeds','Ware potatoes','Farm inputs','Transport','Farm machinery','Agricultural services')),
 variety text, description text, price numeric(12,2) not null check(price>0), unit text not null,
 quantity numeric(12,2) not null check(quantity>=0), county text not null, image_url text,
 status public.product_status not null default 'draft', is_certified boolean not null default false,
 certification_status text not null default 'unverified' check(certification_status in ('unverified','pending','verified','rejected','expired')),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index products_search_idx on public.products using gin(to_tsvector('simple',coalesce(title,'')||' '||coalesce(variety,'')||' '||coalesce(description,'')));
create index products_filter_idx on public.products(status,category,county,created_at desc);
create or replace function public.protect_seed_certification_fields() returns trigger language plpgsql security definer set search_path=public as $$
begin
 if not public.is_admin() then
   new.is_certified:=false;
   new.certification_status:='unverified';
 end if;
 return new;
end; $$;
create trigger protect_seed_certification before insert or update on public.products for each row execute procedure public.protect_seed_certification_fields();
create table public.seed_certifications (
 id uuid primary key default gen_random_uuid(), product_id uuid not null references public.products(id) on delete cascade,
 seller_id uuid not null references public.profiles(id), document_path text not null,
 issuing_authority text, certificate_reference text, valid_until date, status text not null default 'pending' check(status in ('pending','verified','rejected','expired')),
 reviewed_by uuid references public.profiles(id), reviewed_at timestamptz, review_note text, created_at timestamptz not null default now()
);
create table public.orders (
 id uuid primary key default gen_random_uuid(), buyer_id uuid not null references public.profiles(id), seller_id uuid not null references public.profiles(id),
 status public.order_status not null default 'awaiting_payment', currency text not null default 'KES',
 subtotal numeric(12,2) not null check(subtotal>0), commission_rate numeric(5,4) not null default 0.05 check(commission_rate=0.05),
 commission_amount numeric(12,2) not null check(commission_amount>=0), total_amount numeric(12,2) not null check(total_amount>=subtotal),
 buyer_confirmed_at timestamptz, delivered_at timestamptz, delivery_address text, delivery_method text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 check(buyer_id<>seller_id)
);
create table public.order_items (
 id uuid primary key default gen_random_uuid(), order_id uuid not null references public.orders(id) on delete cascade,
 product_id uuid not null references public.products(id), title_snapshot text not null, quantity numeric(12,2) not null check(quantity>0),
 unit_price numeric(12,2) not null check(unit_price>0), line_total numeric(12,2) not null check(line_total>0)
);
create table public.payments (
 id uuid primary key default gen_random_uuid(), order_id uuid not null unique references public.orders(id),
 provider text not null default 'daraja', merchant_request_id text, checkout_request_id text unique,
 mpesa_receipt text unique, phone text, amount numeric(12,2) not null, status public.payment_status not null default 'pending',
 provider_result jsonb, paid_at timestamptz, created_at timestamptz not null default now()
);
create table public.payouts (
 id uuid primary key default gen_random_uuid(), order_id uuid not null unique references public.orders(id), seller_id uuid not null references public.profiles(id),
 gross_amount numeric(12,2) not null, commission_amount numeric(12,2) not null, net_amount numeric(12,2) not null,
 status public.payout_status not null default 'not_eligible', provider_reference text unique, failure_reason text,
 requested_at timestamptz, paid_at timestamptz, created_at timestamptz not null default now()
);
create table public.reviews (
 id uuid primary key default gen_random_uuid(), order_id uuid not null unique references public.orders(id), buyer_id uuid not null references public.profiles(id), seller_id uuid not null references public.profiles(id),
 rating integer not null check(rating between 1 and 5), comment text, created_at timestamptz not null default now()
);
create table public.conversations (
 id uuid primary key default gen_random_uuid(), buyer_id uuid not null references public.profiles(id), seller_id uuid not null references public.profiles(id), product_id uuid references public.products(id), order_id uuid references public.orders(id), created_at timestamptz not null default now(),
 check(buyer_id<>seller_id)
);
create table public.messages (
 id uuid primary key default gen_random_uuid(), conversation_id uuid not null references public.conversations(id) on delete cascade,
 sender_id uuid not null references public.profiles(id), body text not null, attachment_path text, moderation_status text not null default 'clear' check(moderation_status in ('clear','flagged','removed')),
 created_at timestamptz not null default now(), read_at timestamptz
);
create table public.notifications (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade,
 title text not null, body text not null, link text, read_at timestamptz, created_at timestamptz not null default now()
);
create table public.disputes (
 id uuid primary key default gen_random_uuid(), order_id uuid not null unique references public.orders(id), opened_by uuid not null references public.profiles(id), reason text not null, details text,
 status text not null default 'open' check(status in ('open','investigating','resolved_buyer','resolved_seller','refunded')), resolution text, resolved_by uuid references public.profiles(id), created_at timestamptz not null default now(), resolved_at timestamptz
);
create table public.account_sanctions (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id), reason text not null, evidence jsonb not null default '{}'::jsonb,
 status text not null default 'pending_review' check(status in ('pending_review','active','appealed','reversed','expired')), starts_at timestamptz, ends_at timestamptz, reviewed_by uuid references public.profiles(id), created_at timestamptz not null default now()
);
create table public.farmer_groups (
 id uuid primary key default gen_random_uuid(), name text not null, description text, county text, created_by uuid not null references public.profiles(id), is_public boolean not null default true, created_at timestamptz not null default now()
);
create table public.group_members (
 group_id uuid not null references public.farmer_groups(id) on delete cascade, user_id uuid not null references public.profiles(id) on delete cascade, role text not null default 'member', joined_at timestamptz not null default now(), primary key(group_id,user_id)
);
create table public.farming_projects (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references public.profiles(id), title text not null, description text, county text, status text not null default 'open', created_at timestamptz not null default now()
);
create table public.opportunities (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references public.profiles(id), title text not null, description text, county text, closes_at timestamptz, created_at timestamptz not null default now()
);
create table public.meetings (
 id uuid primary key default gen_random_uuid(), organiser_id uuid not null references public.profiles(id), title text not null, description text, venue text, starts_at timestamptz not null, created_at timestamptz not null default now()
);
create table public.audit_logs (
 id uuid primary key default gen_random_uuid(), actor_id uuid references public.profiles(id), action text not null, entity_type text not null, entity_id uuid, details jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);

create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from profiles where id=auth.uid() and role='admin'); $$;
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$ begin insert into public.profiles(id,full_name,role) values(new.id,coalesce(new.raw_user_meta_data->>'full_name',''),coalesce((new.raw_user_meta_data->>'account_type')::public.account_role,'buyer')); return new; exception when invalid_text_representation then insert into public.profiles(id,full_name,role) values(new.id,coalesce(new.raw_user_meta_data->>'full_name',''),'buyer'); return new; end; $$;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

-- RLS: public can browse active listings and public seller profile fields. Private financial and contact details stay restricted.
alter table public.profiles enable row level security;
create policy "profiles visible" on public.profiles for select using (true);
create policy "profile owner update" on public.profiles for update using(id=auth.uid() or public.is_admin()) with check(id=auth.uid() or public.is_admin());
create policy "profile owner insert" on public.profiles for insert with check(id=auth.uid() or public.is_admin());
alter table public.products enable row level security;
create policy "active products public" on public.products for select using(status='active' or seller_id=auth.uid() or public.is_admin());
create policy "seller creates products" on public.products for insert with check(seller_id=auth.uid() and exists(select 1 from profiles p where p.id=auth.uid() and p.role in ('seller','both','admin')));
create policy "seller updates own products" on public.products for update using(seller_id=auth.uid() or public.is_admin()) with check((seller_id=auth.uid() and exists(select 1 from profiles p where p.id=auth.uid() and p.role in ('seller','both','admin'))) or public.is_admin());
create policy "seller deletes own products" on public.products for delete using(seller_id=auth.uid() or public.is_admin());
alter table public.seed_certifications enable row level security;
create policy "cert owner and admin read" on public.seed_certifications for select using(seller_id=auth.uid() or public.is_admin());
create policy "seller submit cert" on public.seed_certifications for insert with check(seller_id=auth.uid());
create policy "admin review cert" on public.seed_certifications for update using(public.is_admin()) with check(public.is_admin());

alter table public.orders enable row level security;
create policy "order participants read" on public.orders for select using(buyer_id=auth.uid() or seller_id=auth.uid() or public.is_admin());
-- Orders are created only through create_marketplace_order RPC; no direct client INSERT policy.
-- No direct client UPDATE policy on orders: financial/status transitions are server-controlled.
alter table public.order_items enable row level security;
create policy "order item participants read" on public.order_items for select using(exists(select 1 from orders o where o.id=order_id and (o.buyer_id=auth.uid() or o.seller_id=auth.uid() or public.is_admin())));
-- Order items are inserted only by the trusted order-creation RPC.
alter table public.payments enable row level security;
create policy "payment participants read" on public.payments for select using(exists(select 1 from orders o where o.id=order_id and (o.buyer_id=auth.uid() or o.seller_id=auth.uid() or public.is_admin())));
alter table public.payouts enable row level security;
create policy "seller sees own payouts" on public.payouts for select using(seller_id=auth.uid() or public.is_admin());
alter table public.reviews enable row level security;
create policy "reviews public read" on public.reviews for select using(true);
create policy "buyer reviews completed order" on public.reviews for insert with check(buyer_id=auth.uid() and exists(select 1 from orders o where o.id=order_id and o.buyer_id=auth.uid() and o.status='completed'));
alter table public.conversations enable row level security;
create policy "conversation participants" on public.conversations for select using(buyer_id=auth.uid() or seller_id=auth.uid() or public.is_admin());
create policy "buyer starts conversation" on public.conversations for insert with check(buyer_id=auth.uid());
alter table public.messages enable row level security;
create policy "message participants read" on public.messages for select using(exists(select 1 from conversations c where c.id=conversation_id and (c.buyer_id=auth.uid() or c.seller_id=auth.uid() or public.is_admin())));
create policy "participants send message" on public.messages for insert with check(sender_id=auth.uid() and exists(select 1 from conversations c where c.id=conversation_id and (c.buyer_id=auth.uid() or c.seller_id=auth.uid())));
alter table public.notifications enable row level security;
create policy "user sees own notifications" on public.notifications for select using(user_id=auth.uid() or public.is_admin());
create policy "user updates own notifications" on public.notifications for update using(user_id=auth.uid()) with check(user_id=auth.uid());
alter table public.disputes enable row level security;
create policy "dispute participants read" on public.disputes for select using(opened_by=auth.uid() or public.is_admin() or exists(select 1 from orders o where o.id=order_id and (o.buyer_id=auth.uid() or o.seller_id=auth.uid())));
create policy "order buyer opens dispute" on public.disputes for insert with check(opened_by=auth.uid() and exists(select 1 from orders o where o.id=order_id and (o.buyer_id=auth.uid() or o.seller_id=auth.uid())));
alter table public.account_sanctions enable row level security;
create policy "user sees own sanctions" on public.account_sanctions for select using(user_id=auth.uid() or public.is_admin());
alter table public.farmer_groups enable row level security;
create policy "public groups visible" on public.farmer_groups for select using(is_public or public.is_admin());
create policy "authenticated creates group" on public.farmer_groups for insert with check(created_by=auth.uid());
alter table public.group_members enable row level security;
create policy "group membership visible" on public.group_members for select using(user_id=auth.uid() or exists(select 1 from farmer_groups g where g.id=group_id and g.is_public) or public.is_admin());
create policy "self joins group" on public.group_members for insert with check(user_id=auth.uid());
alter table public.farming_projects enable row level security;
create policy "projects public read" on public.farming_projects for select using(true);
create policy "owner creates project" on public.farming_projects for insert with check(owner_id=auth.uid());
alter table public.opportunities enable row level security;
create policy "opportunities public read" on public.opportunities for select using(true);
create policy "owner creates opportunity" on public.opportunities for insert with check(owner_id=auth.uid());
alter table public.meetings enable row level security;
create policy "meetings public read" on public.meetings for select using(true);
create policy "organiser creates meeting" on public.meetings for insert with check(organiser_id=auth.uid());
alter table public.audit_logs enable row level security;
create policy "admin reads audit" on public.audit_logs for select using(public.is_admin());


alter table public.seller_payout_accounts enable row level security;
create policy "seller manages own payout account" on public.seller_payout_accounts for select using(user_id=auth.uid() or public.is_admin());
create policy "seller inserts own payout account" on public.seller_payout_accounts for insert with check(user_id=auth.uid());
create policy "seller updates own payout account" on public.seller_payout_accounts for update using(user_id=auth.uid() or public.is_admin()) with check(user_id=auth.uid() or public.is_admin());

-- Server-side order creation: derive seller and price from the live listing and compute the fixed 5% commission.
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
 v_subtotal:=round(v_product.price*p_quantity,2); v_fee:=round(v_subtotal*0.05,2);
 insert into public.orders(buyer_id,seller_id,status,subtotal,commission_rate,commission_amount,total_amount)
 values(auth.uid(),v_product.seller_id,'awaiting_payment',v_subtotal,0.05,v_fee,v_subtotal) returning id into v_order_id;
 insert into public.order_items(order_id,product_id,title_snapshot,quantity,unit_price,line_total)
 values(v_order_id,v_product.id,v_product.title,p_quantity,v_product.price,v_subtotal);
 update public.products set quantity=quantity-p_quantity, updated_at=now() where id=v_product.id;
 return v_order_id;
end; $$;
revoke all on function public.create_marketplace_order(uuid,numeric) from public;
grant execute on function public.create_marketplace_order(uuid,numeric) to authenticated;

-- Private financial state transitions must be performed only by trusted Edge Functions using service role.
