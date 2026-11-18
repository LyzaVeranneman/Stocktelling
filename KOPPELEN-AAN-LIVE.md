# Stappenplan: Home, Kassa en Refunds live zetten

De stocktelling-gegevens op live blijven bij elke stap behouden:

- **Database:** de scripts voegen enkel nieuwe tabellen en functies toe en wijzigen geen bestaande rijen.
  Elk script controleert eerst of de database eruitziet zoals verwacht. Klopt iets niet, dan stopt het zonder iets te wijzigen.
- **Back-up:** je maakt eerst een volledige kopie in de database zelf.
- **Website:** de oude bestanden blijven staan, zodat je met één bestand kan terugdraaien.

Dit alles is vooraf getest op een kopie van de database met gegevens zoals op live (zie onderaan).

## Inhoud van het pakket

| Map | Wat | Waar |
|---|---|---|
| `1-database/` | 5 SQL-scripts, genummerd in volgorde | Supabase **live** project > SQL Editor |
| `2-github/` | de nieuwe website, met de **live** Supabase-gegevens in `gedeeld/config.js` | live repository `Stocktelling` |
| `3-terugdraaien/` | de huidige live `index.html` | enkel gebruiken om terug te draaien |

## Voor je begint

- [ ] **Aanbevolen: eerst een generale repetitie in de testomgeving.** Voer in het **test**project dezelfde vier scripts uit (de testrepository heeft ze al in `database/`). Test daarna de kassa en Refunds op de testsite.
- [ ] Kies een rustig moment, niet tijdens de maandafsluiting. Hotels kunnen blijven werken, maar zo is de controle in stap 5 het duidelijkst.
- [ ] Zorg dat je in Supabase in het **live** project zit. Controleer bovenaan de projectnaam. Het live adres begint met `gvmnjkwjznilaulagasg`.

## Stap 1 · Back-up maken

1. Open het live project in Supabase, ga naar **SQL Editor** en kies **New query**.
2. Plak de volledige inhoud van `1-database/1-backup.sql` en klik op **Run**.
3. Controleer de tabel onderaan: in elke rij moeten **origineel** en **backup** hetzelfde getal tonen.
4. Extra zekerheid (optioneel): ga naar **Table Editor**, open `hotel_months` en kies **Export > CSV**. Bewaar dat bestand.

> Krijg je de fout `schema "backup_livegang" already exists`? Dan bestaat er al een back-up, en die blijft onaangeroerd. Ga gewoon verder.

## Stap 2 · Refunds-tabellen

1. Kies opnieuw **New query**, plak `1-database/2-refunds.sql` en klik op **Run**.
2. Vraagt Supabase om te bevestigen omdat er "destructive operations" in staan? Klik op bevestigen. Het gaat enkel om het vernieuwen van toegangsregels van de **nieuwe** tabellen.
3. Onderaan moeten 3 regels staan: `realtime | refunds`, `tabel | hotel_info` en `tabel | refunds`.

## Stap 3 · Kassa-beveiliging

1. Kies **New query**, plak `1-database/3-kassa.sql` en klik op **Run**. Bevestig indien gevraagd.
2. Onderaan moeten 4 regels staan: 3 keer `functie` en 1 keer `trigger`.

Dit script zorgt voor twee dingen:

- De kassa kan enkel haar eigen deel van een maand opslaan. Producten, aantallen en prijzen van de stocktelling kan ze niet wijzigen.
- De stocktelling (ook de import) kan de kassagegevens niet overschrijven, en een maand met kassagegevens kan niet per ongeluk verwijderd worden.

## Stap 4 · Controle van de database

1. Kies **New query**, plak `1-database/4-controle.sql` en klik op **Run**.
2. Controleer de uitkomst:
   - **Eerste tabel:** alle getallen onder **ontbrekend** zijn **0**.
   - **Tweede tabel:** **gewijzigd** is **0**.

Klopt dat niet? Stop hier en neem contact op voordat je verder gaat. De website is dan nog niet veranderd.

## Stap 5 · Website op GitHub

1. Open de live repository `Stocktelling` op github.com.
2. Kies **Add file > Upload files**.
3. Sleep **de inhoud** van de map `2-github` in het venster. Sleep dus de mappen `database`, `gedeeld`, `home`, `kassa`, `refunds` en `stocktelling`, plus de bestanden `index.html` en `README.md`, niet de map `2-github` zelf.
4. Geef als beschrijving `Home, Kassa en Refunds` en kies **Commit directly to the main branch** > **Commit changes**.
5. **Verwijder nog niets.** De oude bestanden (`config.js`, `supabase-adapter.js`, `js/`, `supabase`) blijven staan. Ze zijn nodig om eventueel terug te draaien.

## Stap 6 · Testen op live

Wacht 1 à 2 minuten (GitHub Pages) en open de site. Vernieuw met Ctrl+F5, of op de gsm door de app te sluiten en opnieuw te openen.

- [ ] Je komt op **Home**. Kies een hotel; de samenvatting toont de juiste maand en waarde.
- [ ] Open **Stocktelling**. Bekijk minstens twee hotels: dezelfde producten en waardes als voorheen.
- [ ] Open **Kassa** en **Refunds**: beide openen zonder foutmelding.
- [ ] Meld aan als een hotel: enkel de knop **Stocktelling** is zichtbaar.
- [ ] Een oude link of het app-icoon op de gsm komt op Home uit.
- [ ] Voer `4-controle.sql` nog eens uit: **ontbrekend** blijft overal **0**.

## Stap 7 · Opruimen (pas na een week zonder problemen)

- **GitHub:** verwijder in de live repository de oude bestanden `config.js`, `supabase-adapter.js`, `js/supabase.min.js` en `supabase`. Laat `sw.js`, `manifest.webmanifest` en de icoontjes staan.
- **Back-up:** die mag blijven staan. Wil je ze later toch weg, voer dan `drop schema backup_livegang cascade;` uit, maar enkel als alles in orde is.

## Terugdraaien

| Probleem | Wat doen |
|---|---|
| De website werkt niet goed | Upload `3-terugdraaien/index.html` naar de hoofdmap van de live repository (overschrijft de doorverwijzing). De oude stocktelling werkt meteen weer, want de oude bestanden staan er nog. |
| Er ontbreken stockgegevens | Voer `4-controle.sql` uit om te zien wat. Gebruik dan deel A van `1-database/herstel-noodgeval.sql`: dat zet enkel ontbrekende gegevens terug en overschrijft niets. |
| Een maand moet terug naar de toestand van voor de livegang | Deel B van `herstel-noodgeval.sql`, per hotel en maand. Kassagegevens blijven behouden. |

De nieuwe tabellen en functies in de database hoeven bij terugdraaien niet weg; ze storen de oude stocktelling niet.

## Goed om te weten

- Hotels komen nu eerst op **Home** en klikken daar op **Stocktelling**: één klik extra.
- **Kassa** en **Refunds** zijn voorlopig enkel zichtbaar voor beheerders.
- **"Maand afsluiten" in de kassa** is dezelfde afsluiting als in de stocktelling: een maand afsluiten in de kassa sluit ze dus ook in de stocktelling voor dat hotel.
- Een hotel met kassagegevens kan niet verwijderd worden zolang die gegevens bestaan. Dat is een bewuste bescherming.

## Wat er vooraf getest is

Op een kopie van de database met dezelfde tabellen, toegangsregels en controles als live, gevuld met voorbeeldgegevens:

- Alle scripts uitgevoerd, ook twee keer na elkaar. De stockgegevens waren achteraf **byte voor byte identiek**.
- Gebruik nagebootst:
  - stocktelling bewaren met een verouderd kassadeel;
  - een import die een maand overschrijft;
  - kassa bewaren in een afgesloten maand en voor een ander hotel;
  - een maand met kassagegevens verwijderen.

  Telkens bleven zowel de stock- als de kassagegevens correct.
- Noodherstel: een maand bewust verwijderd en met `herstel-noodgeval.sql` teruggezet.
- In de browser: de kassapagina stuurt enkel het kassadeel door en schrijft nooit stockgegevens weg.
