-- Operational modules: delivery, transport, moderation, refund cases and hardened roles.
create table if not exists public.transporters (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade,
 vehicle_type text not null, capacity_kg numeric(12,2) not null check(capacity_kg>0), base_county text not null,
 routes text, price_per_km numeric(12,2) not null default 0 check(price_per_km>=0), verified boolean not null default false,
 availability text not null default 'available' check(availability in ('available','busy','inactive')),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.deliveries (
 id uuid primary key default gen_random_uuid(), order_id uuid references public.orders(id) on delete set null,
 buyer_id uuid not null references public.profiles(id), seller_id uuid not null references public.profiles(id),
 transporter_id uuid references public.profiles(id), pickup_location text not null, dropoff_location text not null,
 status text not null default 'requested' check(status in ('requested','assigned','picked_up','in_transit','delivered','cancelled')),
 tracking_note text, proof_of_delivery_path text, estimated_delivery timestamptz, delivered_at timestamptz,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.refund_requests (
 id uuid primary key default gen_random_uuid(), order_id uuid not null references public.orders(id), requested_by uuid not null references public.profiles(id),
 reason text not null, amount numeric(12,2) not null check(amount>0), status text not null default 'requested' check(status in ('requested','under_review','approved','rejected','processed')),
 provider_reference text, reviewed_by uuid references public.profiles(id), reviewed_at timestamptz, created_at timestamptz not null default now()
);
create table if not exists public.message_moderation_events (
 id uuid primary key default gen_random_uuid(), conversation_id uuid references public.conversations(id) on delete set null,
 user_id uuid references public.profiles(id), message_excerpt text, reason text not null, severity text not null default 'warning',
 action_taken text not null default 'blocked_pending_review', created_at timestamptz not null default now()
);
create table if not exists public.payout_provider_events (
 id uuid primary key default gen_random_uuid(), payout_id uuid references public.payouts(id), provider text not null,
 provider_reference text, event_type text not null, payload jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);
create index if not exists deliveries_participants_idx on public.deliveries(buyer_id,seller_id,transporter_id,status);
create index if not exists payouts_status_idx on public.payouts(status,created_at);
create index if not exists disputes_status_idx on public.disputes(status,created_at);

-- Never allow self-service role escalation to administrator.
create or replace function public.guard_profile_privileges() returns trigger language plpgsql security definer set search_path=public as $$
begin
 if auth.uid() is not null and not public.is_admin() and pg_trigger_depth()=1 then
   if new.role is distinct from old.role then new.role:=old.role; end if;
   if new.verified_at is distinct from old.verified_at then new.verified_at:=old.verified_at; end if;
 end if;
 return new;
end; $$;
drop trigger if exists guard_profile_privileges_trigger on public.profiles;
create trigger guard_profile_privileges_trigger before update on public.profiles for each row execute procedure public.guard_profile_privileges();

-- Restrict public signups to non-privileged roles, regardless of submitted metadata.
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
declare requested_role text;
begin
 requested_role:=coalesce(new.raw_user_meta_data->>'account_type','buyer');
 if requested_role not in ('buyer','seller','both','transporter') then requested_role:='buyer'; end if;
 insert into public.profiles(id,full_name,role) values(new.id,coalesce(new.raw_user_meta_data->>'full_name',''),requested_role::public.account_role);
 return new;
end; $$;

alter table public.transporters enable row level security;
create policy "transporters public browse" on public.transporters for select using(availability<>'inactive' or user_id=auth.uid() or public.is_admin());
create policy "transporters manage own" on public.transporters for insert with check(user_id=auth.uid());
create policy "transporters update own or admin" on public.transporters for update using(user_id=auth.uid() or public.is_admin()) with check(user_id=auth.uid() or public.is_admin());
alter table public.deliveries enable row level security;
create policy "delivery participants read" on public.deliveries for select using(buyer_id=auth.uid() or seller_id=auth.uid() or transporter_id=auth.uid() or public.is_admin());
create policy "buyer seller request delivery" on public.deliveries for insert with check((buyer_id=auth.uid() or seller_id=auth.uid()) and exists(select 1 from public.orders o where o.id=order_id and (o.buyer_id=auth.uid() or o.seller_id=auth.uid())));
create policy "assigned transporter updates delivery" on public.deliveries for update using(transporter_id=auth.uid() or public.is_admin()) with check(transporter_id=auth.uid() or public.is_admin());
alter table public.refund_requests enable row level security;
create policy "refund parties read" on public.refund_requests for select using(requested_by=auth.uid() or public.is_admin() or exists(select 1 from public.orders o where o.id=order_id and (o.buyer_id=auth.uid() or o.seller_id=auth.uid())));
create policy "order participant requests refund" on public.refund_requests for insert with check(requested_by=auth.uid() and exists(select 1 from public.orders o where o.id=order_id and (o.buyer_id=auth.uid() or o.seller_id=auth.uid())));
alter table public.message_moderation_events enable row level security;
create policy "moderation events admin only" on public.message_moderation_events for select using(public.is_admin());
alter table public.payout_provider_events enable row level security;
create policy "payout events admin only" on public.payout_provider_events for select using(public.is_admin());

-- Admin-only certificate queue read is required by the admin console; existing owner policy is retained.
drop policy if exists "cert owner and admin read" on public.seed_certifications;
create policy "cert owner and admin read" on public.seed_certifications for select using(seller_id=auth.uid() or public.is_admin());

-- Storage bucket for certificate evidence. Private bucket; signed access must be issued by trusted server after authorization.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('certification-documents','certification-documents',false,10485760,array['application/pdf','image/jpeg','image/png','image/webp'])
on conflict(id) do nothing;
create policy "seller uploads own certification files" on storage.objects for insert to authenticated with check(bucket_id='certification-documents' and (storage.foldername(name))[1]=auth.uid()::text);
create policy "seller reads own certification files" on storage.objects for select to authenticated using(bucket_id='certification-documents' and (storage.foldername(name))[1]=auth.uid()::text);
create policy "admin reads certification files" on storage.objects for select to authenticated using(bucket_id='certification-documents' and public.is_admin());

-- Realtime subscriptions for private messages and delivery status.
alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.deliveries;

-- Force all message writes through the contact-moderation Edge Function (service role only).
drop policy if exists "participants send message" on public.messages;
-- Admins can review and update refund requests; users cannot approve their own requests.
create policy "admin reviews refunds" on public.refund_requests for update using(public.is_admin()) with check(public.is_admin());

-- Prevent users from editing their own reputation metrics.
create or replace function public.guard_profile_privileges() returns trigger language plpgsql security definer set search_path=public as $$
begin
 if auth.uid() is not null and not public.is_admin() and pg_trigger_depth()=1 then
   if new.role is distinct from old.role then new.role:=old.role; end if;
   if new.verified_at is distinct from old.verified_at then new.verified_at:=old.verified_at; end if;
   if new.rating is distinct from old.rating then new.rating:=old.rating; end if;
   if new.rating_count is distinct from old.rating_count then new.rating_count:=old.rating_count; end if;
 end if;
 return new;
end; $$;

-- Tie seller reviews to the actual seller on the completed order.
drop policy if exists "buyer reviews completed order" on public.reviews;
create policy "buyer reviews completed order" on public.reviews for insert with check(
 buyer_id=auth.uid() and exists(select 1 from public.orders o where o.id=order_id and o.buyer_id=auth.uid() and o.seller_id=reviews.seller_id and o.status='completed')
);

-- Certificate evidence can only be submitted for the submitting seller's own listing.
drop policy if exists "seller submit cert" on public.seed_certifications;
create policy "seller submit cert" on public.seed_certifications for insert with check(
 seller_id=auth.uid() and exists(select 1 from public.products p where p.id=product_id and p.seller_id=auth.uid() and p.category='Certified seeds')
);

-- Refunds are buyer-originated and cannot exceed the order's charged amount.
drop policy if exists "order participant requests refund" on public.refund_requests;
create policy "buyer requests bounded refund" on public.refund_requests for insert with check(
 requested_by=auth.uid() and exists(select 1 from public.orders o where o.id=order_id and o.buyer_id=auth.uid() and amount<=o.total_amount)
);

-- Delivery participant IDs must match the selected order; transporters must be registered in the transporter role.
drop policy if exists "buyer seller request delivery" on public.deliveries;
create policy "buyer seller request delivery" on public.deliveries for insert with check(
 (buyer_id=auth.uid() or seller_id=auth.uid()) and exists(select 1 from public.orders o where o.id=order_id and o.buyer_id=deliveries.buyer_id and o.seller_id=deliveries.seller_id and (o.buyer_id=auth.uid() or o.seller_id=auth.uid()))
 and (transporter_id is null or exists(select 1 from public.profiles p where p.id=transporter_id and p.role in ('transporter','admin')))
);

-- Only accounts registered as transporters can publish transport capacity.
drop policy if exists "transporters manage own" on public.transporters;
create policy "transporters manage own" on public.transporters for insert with check(user_id=auth.uid() and exists(select 1 from public.profiles p where p.id=auth.uid() and p.role in ('transporter','admin')));

-- Public users may join public groups only; private groups require a controlled invitation workflow.
drop policy if exists "self joins group" on public.group_members;
create policy "self joins public group" on public.group_members for insert with check(user_id=auth.uid() and exists(select 1 from public.farmer_groups g where g.id=group_id and g.is_public));

-- Keep profile rating aggregates derived from verified transaction reviews.
create or replace function public.refresh_seller_rating() returns trigger language plpgsql security definer set search_path=public as $$
declare target uuid;
begin
 target:=coalesce(new.seller_id,old.seller_id);
 update public.profiles p set rating=coalesce((select round(avg(r.rating)::numeric,2) from public.reviews r where r.seller_id=target),0),
 rating_count=(select count(*) from public.reviews r where r.seller_id=target),updated_at=now() where p.id=target;
 if TG_OP='DELETE' then return old; else return new; end if;
end; $$;
drop trigger if exists refresh_seller_rating_trigger on public.reviews;
create trigger refresh_seller_rating_trigger after insert or update or delete on public.reviews for each row execute procedure public.refresh_seller_rating();

create or replace view public.seller_leaderboard as
select p.id as seller_id,p.full_name,p.farm_name,p.county,p.rating,p.rating_count,
 (select count(*) from public.orders o where o.seller_id=p.id and o.status='completed') as completed_orders,
 (select count(*) from public.orders o where o.seller_id=p.id and o.status='cancelled') as cancelled_orders,
 (select count(*) from public.orders o where o.seller_id=p.id) as total_orders,
 case when (select count(*) from public.orders o where o.seller_id=p.id)=0 then 0::numeric
 else round(100.0*(select count(*) from public.orders o where o.seller_id=p.id and o.status='completed')/(select count(*) from public.orders o where o.seller_id=p.id),2) end as completion_rate
from public.profiles p where p.role in ('seller','both')
order by p.rating desc,p.rating_count desc,completed_orders desc,completion_rate desc;
grant select on public.seller_leaderboard to anon,authenticated;
alter table public.payouts add column if not exists provider_amount numeric(12,2);
