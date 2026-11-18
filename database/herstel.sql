-- ENKEL IN NOODGEVAL: stocktelling-gegevens terugzetten uit de back-up (backup.sql).
-- Voer eerst controle.sql uit om te zien wat er ontbreekt of gewijzigd is.
-- Kassagegevens blijven altijd behouden.

-- A. Enkel ONTBREKENDE gegevens terugzetten (veilig: overschrijft niets).
begin;
insert into public.hotels select * from backup_livegang.hotels on conflict (id) do nothing;
insert into public.hotel_months select * from backup_livegang.hotel_months on conflict (hotel_id, month) do nothing;
insert into public.locks select * from backup_livegang.locks on conflict (hotel_id, month) do nothing;
commit;

-- B. Een maand volledig terugzetten naar de toestand van de back-up.
--    LET OP: wat het hotel sindsdien in die maand invulde, gaat verloren.
--    Haal de streepjes (--) weg voor de vier regels hieronder, vul hotel en maand in, en voer uit.
-- update public.hotel_months m set data = b.data
--   from backup_livegang.hotel_months b
--  where m.hotel_id = b.hotel_id and m.month = b.month
--    and m.hotel_id = 'HOTEL-ID-HIER' and m.month = '2026-11';
