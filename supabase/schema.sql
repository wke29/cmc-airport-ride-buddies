-- Run once in a new Supabase project's SQL Editor.
create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 name text not null check (length(trim(name)) between 1 and 80),
 phone text not null check (phone ~ '^\+?[0-9 ().-]{7,25}$'),
 setup_complete boolean not null default false
);
create table public.rides (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.profiles(id) on delete cascade,
 direction text not null check (direction in ('outbound','inbound')),
 airport text not null check (airport in ('LAX','ONT')),
 date date not null,
 time time without time zone not null,
 comments text not null default '' check (length(comments)<=500),
 status text not null default 'looking' check (status in ('looking','one_more','full','canceled')),
 unique(user_id,direction)
);
-- Use auth.users and auth.identities, never editable user_metadata, for access decisions.
create or replace function public.is_cmc() returns boolean
language sql stable security definer set search_path='' as $$
 select exists (
  select 1 from auth.users u join auth.identities i on i.user_id=u.id
  where u.id=auth.uid() and u.email_confirmed_at is not null
   and lower(split_part(u.email,'@',2))='students.claremontmckenna.edu'
   and i.provider='google'
   and lower(i.identity_data->>'email')=lower(u.email)
   and i.identity_data->>'email_verified'='true'
   and coalesce(i.identity_data->>'hd','')<>''
 );
$$;
revoke all on function public.is_cmc() from public;
grant execute on function public.is_cmc() to authenticated;
create or replace function public.has_setup() returns boolean
language sql stable security definer set search_path='' as $$
 select public.is_cmc() and exists(select 1 from public.profiles where id=auth.uid() and setup_complete);
$$;
revoke all on function public.has_setup() from public;
grant execute on function public.has_setup() to authenticated;
alter table public.profiles enable row level security;
alter table public.rides enable row level security;
revoke all on public.profiles,public.rides from anon,authenticated;
grant select,insert,update on public.profiles,public.rides to authenticated;
create policy profile_read on public.profiles for select to authenticated using (public.is_cmc() and (id=auth.uid() or (public.has_setup() and exists(select 1 from public.rides r where r.user_id=profiles.id and r.status in ('looking','one_more') and (r.date+r.time) >= (now() at time zone 'America/Los_Angeles')))));
create policy profile_insert on public.profiles for insert to authenticated with check (public.is_cmc() and id=auth.uid());
create policy profile_update on public.profiles for update to authenticated using(public.is_cmc() and id=auth.uid()) with check(public.is_cmc() and id=auth.uid());
create policy ride_read on public.rides for select to authenticated using(public.is_cmc() and (user_id=auth.uid() or (public.has_setup() and status in ('looking','one_more') and (date+time)>=(now() at time zone 'America/Los_Angeles'))));
create policy ride_insert on public.rides for insert to authenticated with check(public.is_cmc() and user_id=auth.uid());
create policy ride_update on public.rides for update to authenticated using(public.is_cmc() and user_id=auth.uid()) with check(public.is_cmc() and user_id=auth.uid());
-- Invoker view preserves all underlying RLS policies and uses authoritative Google email.
-- Email is copied from auth.users through a protected helper rather than user input.
create or replace function public.board_email(target uuid) returns text
language sql stable security definer set search_path='' as $$
 select u.email from auth.users u where u.id=target and public.has_setup()
 and (target=auth.uid() or exists(select 1 from public.rides r where r.user_id=target and r.status in ('looking','one_more') and (r.date+r.time)>=(now() at time zone 'America/Los_Angeles')));
$$;
revoke all on function public.board_email(uuid) from public;
grant execute on function public.board_email(uuid) to authenticated;
create view public.ride_board with (security_invoker=true) as
 select r.*,p.name,p.phone,public.board_email(p.id) as email from public.rides r join public.profiles p on p.id=r.user_id;
grant select on public.ride_board to authenticated;
-- Atomically save onboarding. Completion persists even after both listings are canceled.
create or replace function public.complete_setup(display_name text,contact_phone text,trips jsonb) returns void
language plpgsql security invoker set search_path='' as $$
begin
 if not public.is_cmc() then raise exception 'A verified CMC Google account is required'; end if;
 if jsonb_typeof(trips)<>'array' or jsonb_array_length(trips) not between 1 and 2 then raise exception 'Choose one or two trips'; end if;
 insert into public.profiles(id,name,phone,setup_complete) values(auth.uid(),display_name,contact_phone,false)
 on conflict(id) do update set name=excluded.name,phone=excluded.phone;
 insert into public.rides(user_id,direction,airport,date,time,comments,status)
 select auth.uid(),x->>'direction',x->>'airport',(x->>'date')::date,(x->>'time')::time,coalesce(x->>'comments',''),'looking' from jsonb_array_elements(trips) x
 on conflict(user_id,direction) do update set airport=excluded.airport,date=excluded.date,time=excluded.time,comments=excluded.comments;
 update public.profiles set setup_complete=true where id=auth.uid();
end;
$$;
revoke all on function public.complete_setup(text,text,jsonb) from public;
grant execute on function public.complete_setup(text,text,jsonb) to authenticated;
