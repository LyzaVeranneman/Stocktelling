-- Controle na de livegang: zijn alle stocktelling-gegevens er nog?
-- Leest enkel, wijzigt niets. Mag zo vaak uitgevoerd worden als je wil.
-- Vergelijkt met de back-up uit backup.sql.

-- 1. Belangrijkste controle: ontbreekt er iets? Alle aantallen in "ontbrekend" moeten 0 zijn.
select 'hotels' as tabel,
       (select count(*) from backup_livegang.hotels b
         where not exists (select 1 from public.hotels h where h.id = b.id)) as ontbrekend
union all
select 'hotel_months',
       (select count(*) from backup_livegang.hotel_months b
         where not exists (select 1 from public.hotel_months m where m.hotel_id = b.hotel_id and m.month = b.month))
union all
select 'locks',
       (select count(*) from backup_livegang.locks b
         where not exists (select 1 from public.locks l where l.hotel_id = b.hotel_id and l.month = b.month));

-- 2. Stockgegevens per maand vergelijken (zonder het kassadeel).
--    Vlak na de livegang moet "gewijzigd" 0 zijn. Later is het normaal dat maanden die hotels
--    intussen invulden, hier verschijnen.
select count(*) filter (where (m.data - 'kassa') is distinct from (b.data - 'kassa')) as gewijzigd,
       count(*) as vergeleken
from backup_livegang.hotel_months b
join public.hotel_months m on m.hotel_id = b.hotel_id and m.month = b.month;

-- 3. Welke maanden zijn gewijzigd sinds de back-up? (lijst, leeg = niets gewijzigd)
select m.hotel_id, h.name as hotel, m.month
from backup_livegang.hotel_months b
join public.hotel_months m on m.hotel_id = b.hotel_id and m.month = b.month
left join public.hotels h on h.id = m.hotel_id
where (m.data - 'kassa') is distinct from (b.data - 'kassa')
order by 2, 3;
