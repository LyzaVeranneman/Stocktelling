-- Back-up van alle stocktelling-gegevens, IN de database zelf.
-- Voer dit uit VOOR je iets anders doet. Plak alles in SQL Editor > New query > Run.
--
-- Maakt een kopie van elke tabel in een apart schema "backup_livegang".
-- Leest enkel; de echte tabellen worden niet gewijzigd.
-- De kopie is niet bereikbaar via de website of de app (enkel via de SQL Editor).
-- Bestaat de back-up al, dan stopt het script met een fout en blijft de eerste back-up ongewijzigd.

begin;

create schema backup_livegang;   -- fout "already exists" = er is al een back-up; niets overschreven
revoke all on schema backup_livegang from public, anon, authenticated;

create table backup_livegang.hotels        as table public.hotels;
create table backup_livegang.hotel_months  as table public.hotel_months;
create table backup_livegang.locks         as table public.locks;
create table backup_livegang.editors       as table public.editors;

do $$
begin
  if to_regclass('public.hotel_settings') is not null then
    execute 'create table backup_livegang.hotel_settings as table public.hotel_settings';
  end if;
end $$;

create table backup_livegang.info as
  select now() as gemaakt_op,
         (select count(*) from public.hotels)       as hotels,
         (select count(*) from public.hotel_months) as maanden,
         (select count(*) from public.locks)        as locks;

commit;

-- Controle: de aantallen links (origineel) en rechts (back-up) moeten gelijk zijn.
select 'hotels' as tabel, (select count(*) from public.hotels) as origineel, (select count(*) from backup_livegang.hotels) as backup
union all select 'hotel_months', (select count(*) from public.hotel_months), (select count(*) from backup_livegang.hotel_months)
union all select 'locks', (select count(*) from public.locks), (select count(*) from backup_livegang.locks)
union all select 'editors', (select count(*) from public.editors), (select count(*) from backup_livegang.editors);
