-- Existing projects: replace only the access-check function; no tables or data are changed.
create or replace function public.is_cmc() returns boolean
language sql stable security definer set search_path='' as $$
 select exists (
  select 1 from auth.users u join auth.identities i on i.user_id=u.id
  where u.id=auth.uid() and u.email_confirmed_at is not null
   and lower(split_part(u.email,'@',2))='students.claremontmckenna.edu'
   and i.provider='google'
   and lower(i.identity_data->>'email')=lower(u.email)
   and i.identity_data->>'email_verified'='true'
 );
$$;
revoke all on function public.is_cmc() from public;
grant execute on function public.is_cmc() to authenticated;
