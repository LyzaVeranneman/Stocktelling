-- Kassa: veilig opslaan naast de stocktelling.
-- Plak alles in Supabase > SQL Editor > New query en klik op Run. Mag opnieuw uitgevoerd worden.
--
-- Wat dit doet:
--  * Functie kassa_save: de kassapagina bewaart hiermee ENKEL het deel "kassa" van een maand.
--    Producten, aantallen, prijzen en datum van de stocktelling worden nooit aangeraakt.
--  * Beschermregel op hotel_months:
--      - de stocktelling (en de import) kan het deel "kassa" niet overschrijven of wissen;
--      - een maand met kassagegevens kan niet per ongeluk verwijderd worden.
-- Wat dit NIET doet: bestaande rijen wijzigen. Er worden geen gegevens aangepast of verwijderd.

begin;

-- 0. Voorcontrole: stopt zonder iets te wijzigen als de stocktelling-database er anders uitziet.
do $$
begin
  if to_regclass('public.hotel_months') is null then
    raise exception 'Tabel hotel_months niet gevonden. Er is niets gewijzigd.';
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'hotel_months' and column_name = 'hotel_id')
     or not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'hotel_months' and column_name = 'month')
     or not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'hotel_months' and column_name = 'data' and data_type = 'jsonb') then
    raise exception 'hotel_months heeft niet de verwachte kolommen (hotel_id, month, data). Er is niets gewijzigd.';
  end if;
end $$;

-- 1. Hulpfunctie: bevat het kassadeel echte waardes?
create or replace function public.kassa_has_values(j jsonb)
returns boolean language sql immutable set search_path = public as $$
  select coalesce(j is not null and jsonb_typeof(j) in ('object','array') and exists (
    select 1 from jsonb_path_query(j, 'strict $.**') v
    where jsonb_typeof(v) in ('string','number','boolean')
      and v not in ('""'::jsonb, 'false'::jsonb)), false)
$$;

-- 2. Opslaan van enkel het kassadeel. Werkt met de rechten van de aangemelde gebruiker
--    (dezelfde toegangsregels als de stocktelling, ook afgesloten maanden).
create or replace function public.kassa_save(p_hotel text, p_month text, p_kassa jsonb)
returns void language plpgsql security invoker set search_path = public as $$
begin
  if p_month !~ '^[0-9]{4}-[0-9]{2}$' then
    raise exception 'Ongeldige maand' using errcode = '22023';
  end if;
  if p_kassa is null or jsonb_typeof(p_kassa) <> 'object' or octet_length(p_kassa::text) > 50000 then
    raise exception 'Ongeldige kassagegevens' using errcode = '22023';
  end if;
  perform set_config('app.kassa_save', 'on', true);
  update hotel_months set data = jsonb_set(data, '{kassa}', p_kassa, true)
   where hotel_id = p_hotel and month = p_month;
  if not found then
    -- Nieuwe maand: enkel kassa, lege stocktelling. Bestaat de maand wel maar is ze
    -- niet toegankelijk (bv. afgesloten), dan geeft dit een fout en wijzigt er niets.
    insert into hotel_months (hotel_id, month, data)
    values (p_hotel, p_month, jsonb_build_object('datum', '', 'removed', '[]'::jsonb, 'cats', '{}'::jsonb, 'kassa', p_kassa));
  end if;
  perform set_config('app.kassa_save', 'off', true);
end $$;

revoke all on function public.kassa_save(text, text, jsonb) from public, anon;
grant execute on function public.kassa_save(text, text, jsonb) to authenticated;

-- 3. Beschermregel: kassa en stocktelling kunnen elkaars gegevens niet overschrijven.
create or replace function public.hotel_months_kassa_guard()
returns trigger language plpgsql set search_path = public as $$
declare
  via_kassa boolean := coalesce(current_setting('app.kassa_save', true), '') = 'on';
begin
  if tg_op = 'DELETE' then
    if kassa_has_values(old.data -> 'kassa') then
      raise exception 'Deze maand bevat kassagegevens en kan niet verwijderd worden' using errcode = '22023';
    end if;
    return old;
  end if;

  if via_kassa then
    -- Opslaan via de kassa: alles behalve "kassa" blijft exact zoals het was.
    if tg_op = 'UPDATE' then
      new.data := jsonb_set(old.data, '{kassa}', coalesce(new.data -> 'kassa', '{}'::jsonb), true);
    end if;
  else
    -- Opslaan via de stocktelling of import: "kassa" blijft exact zoals het was.
    if tg_op = 'INSERT' then
      new.data := new.data - 'kassa';
    elsif old.data ? 'kassa' then
      new.data := jsonb_set(new.data, '{kassa}', old.data -> 'kassa', true);
    else
      new.data := new.data - 'kassa';
    end if;
  end if;
  return new;
end $$;

drop trigger if exists hotel_months_kassa_guard on public.hotel_months;
create trigger hotel_months_kassa_guard
  before insert or update or delete on public.hotel_months
  for each row execute function public.hotel_months_kassa_guard();

commit;

-- 4. Controle
select 'functie' as soort, proname::text as naam from pg_proc
  where proname in ('kassa_save', 'kassa_has_values', 'hotel_months_kassa_guard')
union all
select 'trigger', tgname::text from pg_trigger where tgname = 'hotel_months_kassa_guard'
order by 1, 2;
