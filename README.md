# Stocktelling hotels

Webapp voor maandelijkse stocktelling per hotel. Hosting: GitHub Pages (pagina) + Supabase (aanmelden en gedeelde opslag).

- Hotels melden aan met e-mail en wachtwoord en zien alleen hun eigen gegevens. Geen Claude-account nodig.
- Editors zien alle hotels, het overzicht "Alle hotels", kunnen maanden afsluiten en importeren. Een afgesloten maand wordt door de server geweigerd voor hotels.
- De regel "product verwijderen enkel bij begin en eind 0" werkt in de pagina, niet op de server.

## Opzetten

1. Maak een gratis project op https://supabase.com.
2. Open **SQL Editor**, plak de inhoud van `schema.sql` en klik **Run**.
3. Ga naar **Authentication > Sign In / Providers** en zet "Allow new users to sign up" **uit**.
4. Ga naar **Authentication > Users > Add user**. Maak een account (e-mail + wachtwoord, vink "Auto Confirm User" aan) voor jezelf, je collega en elk hotel.
5. Maak jezelf en je collega editor, via **SQL Editor**:
   `insert into editors select id from auth.users where email in ('jij@voorbeeld.be','collega@voorbeeld.be');`
6. Ga naar **Project Settings > API**. Kopieer "Project URL" en de "anon public" key naar `config.js`. Gebruik nooit de service_role key.
7. Maak op GitHub een nieuwe repository en upload alle bestanden uit deze map.
8. Ga naar **Settings > Pages**, kies "Deploy from a branch", branch `main`, map `/ (root)`, en klik Save.
9. Na een minuut staat de pagina op `https://GEBRUIKERSNAAM.github.io/REPONAAM/`. Stuur die link naar de hotels, samen met hun aanmeldgegevens.

## Opmerkingen

- Een hotel vult bij de eerste keer de hotelnaam in.
- Een gratis Supabase-project kan na een langere periode zonder gebruik gepauzeerd worden. Je kan het in het dashboard weer starten.
- Maak af en toe een back-up (Supabase > Database > Backups, of exporteer de tabellen).
