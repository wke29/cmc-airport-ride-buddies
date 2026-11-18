-- Existing projects: expand airport choices without modifying any ride rows.
-- Run this file in Supabase SQL Editor before using the new airport options.
begin;
alter table public.rides
  drop constraint if exists rides_airport_check;
alter table public.rides
  add constraint rides_airport_check
  check (airport in ('LAX', 'ONT', 'SNA', 'BUR'));
commit;
