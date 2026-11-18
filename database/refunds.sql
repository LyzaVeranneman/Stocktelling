-- Refunds: tabellen en toegangsregels.
-- Plak alles in Supabase > SQL Editor > New query en klik op Run.
-- Mag meerdere keren uitgevoerd worden. Eerst in het testproject; later hetzelfde script in het live project.
-- Vereist de bestaande stocktelling-tabellen (hotels, editors, is_editor).
-- Voegt enkel NIEUWE tabellen toe (refunds, hotel_info). Bestaande gegevens worden niet gewijzigd.

begin;

-- 0. Voorcontrole: stopt zonder iets te wijzigen als de stocktelling-database er anders uitziet.
do $$
begin
  if to_regclass('public.hotels') is null
     or not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'hotels' and column_name = 'id' and data_type = 'text') then
    raise exception 'Tabel hotels (met tekstkolom id) niet gevonden. Er is niets gewijzigd.';
  end if;
  if to_regprocedure('public.is_editor()') is null then
    raise exception 'Functie is_editor() niet gevonden. Er is niets gewijzigd.';
  end if;
end $$;

-- 1. Tabellen ---------------------------------------------------------------

create table if not exists public.refunds (
  id           uuid primary key default gen_random_uuid(),
  hotel_id     text not null references public.hotels(id) on delete cascade,
  created_at   timestamptz not null default now(),
  created_by   uuid default auth.uid(),
  updated_at   timestamptz not null default now(),
  request_date date not null default current_date,
  iban         text not null check (iban ~ '^[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}$'),
  bic          text not null default '' check (bic = '' or bic ~ '^[A-Z]{6}[A-Z0-9]{2}([A-Z0-9]{3})?$'),
  naam         text not null check (char_length(naam) between 1 and 140),
  bedrag       numeric(12,2) not null check (bedrag > 0 and bedrag < 100000),
  mededeling   text not null default '' check (char_length(mededeling) <= 140),
  reden        text not null check (char_length(reden) between 1 and 1000),
  gm           text not null check (char_length(gm) between 1 and 100),
  -- open: hotel vult in · afgesloten: hotel heeft afgesloten, klaar voor betaling
  -- uitbetaald / geweigerd: door de beheerder
  status       text not null default 'open' check (status in ('open','afgesloten','uitbetaald','geweigerd')),
  afgesloten_op timestamptz,
  betaald_op   date,
  opmerking    text not null default '' check (char_length(opmerking) <= 500)
);
alter table public.refunds add column if not exists afgesloten_op timestamptz;
create index if not exists refunds_hotel_idx on public.refunds (hotel_id, request_date desc);

-- Gegevens voor de hoofding van het refundblad (adres, BTW, ...). Herbruikbaar door andere modules.
create table if not exists public.hotel_info (
  hotel_id   text primary key references public.hotels(id) on delete cascade,
  info       jsonb not null default '{}'::jsonb
             check (jsonb_typeof(info) = 'object' and octet_length(info::text) < 4000),
  updated_at timestamptz not null default now()
);

-- 2. Een hotel mag enkel invullen en afsluiten; uitbetaald/geweigerd is voor de beheerder

create or replace function public.refunds_guard()
returns trigger language plpgsql set search_path = public as $$
begin
  new.updated_at := now();
  if not is_editor() then
    if new.status not in ('open','afgesloten') then
      new.status := case when tg_op = 'INSERT' then 'open' else old.status end;
    end if;
    if tg_op = 'INSERT' then
      new.betaald_op := null; new.opmerking := '';
      new.created_by := auth.uid(); new.created_at := now();
    else
      new.betaald_op := old.betaald_op; new.opmerking := old.opmerking;
      new.created_by := old.created_by; new.created_at := old.created_at; new.hotel_id := old.hotel_id;
    end if;
  end if;
  if new.status = 'open' then new.afgesloten_op := null;
  elsif new.afgesloten_op is null then new.afgesloten_op := now(); end if;
  if new.status <> 'uitbetaald' then new.betaald_op := null; end if;
  return new;
end $$;

drop trigger if exists refunds_guard on public.refunds;
create trigger refunds_guard before insert or update on public.refunds
  for each row execute function public.refunds_guard();

-- 3. Toegangsregels -----------------------------------------------------------

alter table public.refunds    enable row level security;
alter table public.hotel_info enable row level security;

drop policy if exists refunds_select on public.refunds;
create policy refunds_select on public.refunds for select to authenticated
  using (is_editor() or hotel_id = auth.uid()::text);

drop policy if exists refunds_insert on public.refunds;
create policy refunds_insert on public.refunds for insert to authenticated
  with check (is_editor() or hotel_id = auth.uid()::text);

-- Een hotel kan een refund enkel aanpassen of afsluiten zolang ze open is.
drop policy if exists refunds_update on public.refunds;
create policy refunds_update on public.refunds for update to authenticated
  using (is_editor() or (hotel_id = auth.uid()::text and status = 'open'))
  with check (is_editor() or hotel_id = auth.uid()::text);

-- Een hotel kan een refund enkel verwijderen zolang ze open is.
drop policy if exists refunds_delete on public.refunds;
create policy refunds_delete on public.refunds for delete to authenticated
  using (is_editor() or (hotel_id = auth.uid()::text and status = 'open'));

drop policy if exists hotel_info_select on public.hotel_info;
create policy hotel_info_select on public.hotel_info for select to authenticated
  using (is_editor() or hotel_id = auth.uid()::text);
drop policy if exists hotel_info_write on public.hotel_info;
create policy hotel_info_write on public.hotel_info for all to authenticated
  using (is_editor() or hotel_id = auth.uid()::text)
  with check (is_editor() or hotel_id = auth.uid()::text);

revoke all on public.refunds, public.hotel_info from anon;
grant select, insert, update, delete on public.refunds, public.hotel_info to authenticated;

-- 4. Realtime (lijst werkt live bij) -------------------------------------------

do $$
begin
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'refunds') then
    alter publication supabase_realtime add table public.refunds;
  end if;
end $$;

commit;

-- 5. Controle -------------------------------------------------------------------

select 'tabel' as soort, tablename::text as naam from pg_tables
  where schemaname = 'public' and tablename in ('refunds','hotel_info')
union all
select 'realtime', tablename::text from pg_publication_tables
  where pubname = 'supabase_realtime' and tablename = 'refunds'
order by 1, 2;
