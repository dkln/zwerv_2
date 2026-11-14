# Verhaal, missies en gesprekken aanpassen

Alles wat er in het spel gezegd wordt en elke missie staat in gewone JSON-bestanden in deze
map. Je past ze aan met een teksteditor (of in Godot: dubbelklik op het bestand). Ze worden
gelezen als het spel start. Controleer na een wijziging met:

    tools/godot.sh --headless --script tests/run_unit_tests.gd

Die test meldt een kapot bestand, een missie zonder titel, een onbekend doel of een
snackbar-item dat niet bestaat.

Let op bij JSON: teksten tussen `"aanhalingstekens"`, een komma tussen alle onderdelen
(niet na het laatste), geen komma's na de laatste regel van een lijst.

## Missies — `missies/*.json`

Elk bestand is één missie. Ze worden gelezen in de volgorde van de bestandsnamen
(`01_lege_maag.json`, `02_bekend_gezicht.json`, ..., zijmissies achteraan: `90_blikjesronde.json`).
Een nieuwe missie: kopieer er een, geef het een nieuwe naam en een nieuwe `"id"`.

| veld                        | wat                                                                                                                     |
| --------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `id`                        | unieke naam, bv. `"missie_3_papieren"`                                                                                  |
| `label`, `titel`            | boven in beeld en in het questlog: `"MISSIE 2"`, `"Bekend gezicht"`                                                     |
| `gever`, `beschrijving`     | van wie de opdracht komt en wat het is (questlog)                                                                       |
| `soort`                     | `"verhaal"` (standaard) of `"zij"` (een zijmissie)                                                                      |
| `start`                     | `"na_proloog"`, of `"na:missie_1_lege_maag"` (als die klaar is)                                                         |
| `xp`                        | XP voor de hele missie                                                                                                  |
| `beloningen`                | teksten in het questlog, bv. `["KROKET", "+40 HONGER"]`                                                                 |
| `geeft`                     | items die je krijgt als de hele missie klaar is, bv. `[{"item": "koffie", "aantal": 1}]` (ook per stap)                 |
| `start_paginas`             | wat er verteld wordt als de missie begint                                                                               |
| `stappen`                   | de stappen, na elkaar (de volgende is doorzichtig tot de vorige klaar is)                                               |
| `einde_paginas`             | wat er verteld wordt als alles klaar is (een pagina met `"als": "check:overtuigen_wim"` alleen als die check gelukt is) |
| `opent_na_afloop`           | gebieden die daarna open gaan (zie **Gebieden** hieronder)                                                              |
| `markeringen`               | plekken die daarna voorgoed op de kaart gemarkeerd staan (een ring), bv. `["malieveld"]`                                |
| `gesprekken_na_afloop`      | welk gesprek een personage daarna heeft: `{"ome_wim": "klaar"}`                                                         |
| `herhaalbaar`, `herhaal_na` | `true`: de missie begint `herhaal_na` seconden na afloop opnieuw (de blikjesronde)                                      |

Een **stap**:

```json
{
  "id": "kroket",
  "tekst": "Koop een kroket en eet hem op [F]",
  "xp": 60,
  "doel": { "soort": "gebruiken", "item": "kroket" },
  "plekken": { "soort": "snackbars", "aantal": 3 },
  "klaar_paginas": [{ "soort": "gedachte", "tekst": "Eindelijk een kroket." }]
}
```

Wat een stap verder kan (het meeste gebeurt zodra de stap begint):

| veld                                | wat                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| ----------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `optioneel`                         | `true`: houdt de volgende stappen niet tegen; kan zolang de missie loopt                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| `verborgen_tot_open`                | `true`: de stap staat niet in de takenlijst (tracker, missies in het spelmenu), ook niet op slot, tot hij aan de beurt is; bv. het bedelen in missie 1, dat pas na het statiegeld (en de gedachte dat je tekortkomt) verschijnt                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| `zet_stats`                         | zet stats, bv. `{"honger": 74}` (dan merk je de honger snel)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| `ontgrendelt`                       | zet iets van het spel open (bij het begin van de stap): `["menu"]` = het spelmenu (Tab), `["bedelen"]` = mensen om kleingeld vragen, `["handelaars"]` = praten met wie iets verkoopt (de frietkar, een snackbar, de winkels; missie 1, allebei na het statiegeld), `["springen"]` = springen met de spatiebalk (missie 1, via `bij_binnenkomst` in het station), `["snackkaart"]` = de hele kaart van de frietkar en de snackbars (wat in `snackbarhouder.json` een `"slot": "snackkaart"` heeft; missie 1, na de kroket: daarvoor alleen de kroket), `["kleingeld"]` / `["pinpassen"]` = kleingeld en pinpassen die op straat liggen (heel zeldzaam; nog geen missie zet ze open); tot dan kan het niet |
| `opent`                             | gebieden die open gaan (zie **Gebieden**)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| `groeit`                            | `{"per": "blikje", "tot": "supermarkt"}`: het startgebied groeit met elk verzameld blikje, tot de dichtstbijzijnde supermarkt erin ligt                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| `opent_tot`                         | `"supermarkt"`: het startgebied wordt zo groot dat de dichtstbijzijnde supermarkt erin ligt                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| `blikjes_buiten`, `blikjes_station` | bij een stap met `"plekken": {"soort": "blikjes"}`: precies zoveel blikjes in de prullenbakken rond de start (de andere daar leeg, en niets bijgevuld zolang de stap loopt), de rest (hoogstens 2) in Den Haag Centraal, achter de poortjes: elk in een eigen prullenbak op een perron (de tweede bij voorkeur op een ander perron); als de blikjes buiten op zijn, wijst het kaartje buiten naar de ingang van Centraal en binnen naar de blikjes zelf                                                                                                                                                                                                                                                  |
| `tussen_paginas`                    | `[{"bij": 3, "paginas": [...]}]`: pagina's zodra je er zoveel van het doel hebt (eenmalig)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| `bij_binnenkomst`                   | `{"binnen": "centraal", "vanaf": 4, "ontgrendelt": ["springen"], "paginas": [...]}`: pagina's (bv. de verteller) zodra je tijdens de stap een binnenruimte van die soort binnenkomt (`centraal`, `snackbar`, `derrek`, `alfred_steyhn`, `stadhuis`) met minstens `vanaf` van het doel op zak; eenmalig per spel, en wat `ontgrendelt` gaat dan open. Missie 1: in het station de twee blikjes op de perrons, een manier verzinnen om erop te komen, de conducteurs (€ 50 boete; niet betalen = eruit gezet, en `terug_na` seconden niet meer naar binnen)                                                                                                                                                |
| `eerste_scherm`                     | `{"kop": "GEVONDEN", "titel": "Je eerste blikje"}`: het eerste item van het doel dat je krijgt (oppakt uit een prullenbak of in het station, of koopt: de eerste kroket) komt in het **beloningsscherm** in plaats van als tekstje boven je hoofd; eenmalig per spel (onthouden in de save), de volgende krijgen weer het tekstje                                                                                                                                                                                                                                                                                                                                                                        |
| `storing`                           | `{"tekst": "TIJDELIJK BUITEN GEBRUIK", "paginas": [...]}`: de eerste statiegeldautomaat die je probeert is stuk; de stap toont dan `tekst_storing`, wijst naar een andere supermarkt en het gebied groeit tot daar. Met `"persoon": "bertus"` (een personage met `zwerft`) komt dat personage op dat moment de stad in en blijft daar voorgoed rondlopen; het kaartje wijst (en volgt) hem in plaats van een andere supermarkt, en het gebied groeit niet. Missie 1: Blikken Bertus koopt je blikjes, voor minder dan de automaat                                                                                                                                                                        |
| `gesprekken`                        | welk gesprek een personage nu heeft: `{"ome_wim": "rondje"}`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |

Een stap met `"overslaan_als": {"startgeld_minstens": 2.0}` wordt overgeslagen (meteen
klaar, zonder XP) voor een karakter dat met minstens zoveel geld begint.

Een stap kan ook items geven: `"geeft": [{"item": "stroopwafel", "aantal": 2}]` (de ids van
`scripts/player/items.gd`). Wat een stap of missie oplevert (de XP en de items) komt na de
`klaar_paginas` in een eigen **beloningsscherm**: het item groot in beeld, langzaam draaiend
als voxelmodel met stralen erachter, zijn naam en tekstje, met een eigen deuntje
(`deuntje_beloning`); wegdrukken met Enter.

Soorten **doel**:

| soort           | velden                                 | klaar als                                                                                                                                                                            |
| --------------- | -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `geld_verdiend` | `bedrag`                               | je zoveel gevonden of gekregen geld nog op zak hebt (wat je uitgeeft telt weer af, je startgeld telt niet mee; hetzelfde bedrag als in je portemonnee)                               |
| `geld_op_zak`   | `bedrag`                               | je zoveel in je portemonnee hebt, hoe dan ook (startgeld, gevonden, gekregen); heb je het al als de stap begint, dan is hij meteen klaar (missie 1: € 2 voor de kroket)              |
| `kopen`         | `item`                                 | je het gekocht hebt (een item uit `scripts/player/items.gd`)                                                                                                                         |
| `gebruiken`     | `item`                                 | je het gegeten, gedronken of gebruikt hebt (in het menu, of met F: eet iets uit je zakken)                                                                                           |
| `verzamelen`    | `item`, `aantal`                       | je er zoveel van op zak hebt                                                                                                                                                         |
| `statiegeld`    |                                        | een statiegeldautomaat je geld heeft gegeven                                                                                                                                         |
| `praten_met`    | `persoon`                              | je met zo iemand gepraat hebt (een `id` uit de gesprekken of een personage, of `"iemand"`); klaar als het gesprek voorbij is, de `klaar_paginas` komen erna                          |
| `naar_plek`     | `plek`, `straal`                       | je binnen `straal` meter van die plek bent                                                                                                                                           |
| `naar_persoon`  | `persoon`, `straal`                    | je binnen `straal` meter van dat personage bent                                                                                                                                      |
| `lopen`         | `meter`                                | je zover gelopen hebt sinds de stap begon                                                                                                                                            |
| `stat_onder`    | `stat`, `waarde`                       | die stat onder de waarde zakt (bv. `honger`)                                                                                                                                         |
| `menu_open`     | `tab`                                  | je het spelmenu op die tab opent (`inventaris`, `quests`, `kaart`)                                                                                                                   |
| `check`         | `check`                                | een vaardigheidscheck in een gesprek gelukt is (zie **Personages**)                                                                                                                  |
| `begeleiden`    | `persoon`, `route`, `wacht`            | je met het personage langs de plekken van `route` gelopen bent (het wacht als je achterblijft; met `"wacht": false` loopt het in één keer door en ben je klaar zodra je er ook bent) |
| `werver`        | `persoon`, `straal`, `plek`, `voorbij` | het personage staat op `plek` in de weg; klaar als je ermee praat of er voorbij bent (dichter bij `voorbij`)                                                                         |

**Plekken** op het kaartje en de kaart (optioneel): `{"soort": "snackbars", "aantal": 3}`
(de dichtstbijzijnde), `{"soort": "supermarkten", "aantal": 1}`, `{"soort": "blikjes", "aantal": 3}`
(prullenbakken met een blikje; met `"in_zicht": true` en `blikjes_buiten` alleen bakken zonder gebouw tussen de start en de bak: op het plein en bij de tramhalte voor Centraal, nooit erachter), `{"soort": "plek", "plek": "koekamp"}` of
`{"soort": "plekken", "plekken": ["koekamp", "centraal"]}`. De namen van plekken staan in
`scenes/stad.tscn` onder `metadata/places` (o.a. `centraal`, `koekamp`, `plein`, `spui`,
`snackbar_hertenkamp`, `malieveld`). Bij `naar_plek`, `naar_persoon`, `praten_met` (een
personage) en `begeleiden` wordt de plek vanzelf aangewezen. Alleen wat open is (de
gebieden) staat op de kaart.

Een **pagina**: `{"soort": "verhaal", "tekst": "..."}`. Soorten: `verhaal` (de verteller),
`gedachte` (je karakter denkt), `missie` (een opdracht), `gesprek` (iemand anders, met
`"spreker": "NAAM"`).

In teksten kun je invullen: `{naam}` (je karakter), `{achtergrond}` (zijn verhaal),
`{voortgang}` (in de tekst van een stap: hoe ver je bent, bv. `€ 1,20` of `2/4`), `{geldregel}`
(een regel uit `"geldregel": {"leeg": ..., "wel": ...}`: of je karakter geld heeft).

## Gebieden (de shroud) — `gebieden.json`

Waar je mag komen. Wat niet open is, staat niet op de kaart en het kaartje, en je kunt er
niet in lopen (aan de rand denkt je karakter "Daar heb ik nu niks te zoeken."). Binnenruimtes
tellen niet mee.

- `start`: een cirkel om een plek (`midden`, een plek van de kaart) met een `straal` in meters:
  wat open is als het spel begint. Een stap met `groeit` laat hem groter worden.
- `marge`: meters om een plek waar de cirkel naartoe groeit, zodat je er echt kunt komen.
- `gebieden`: gebieden met een naam die een missie opent (`opent`, `opent_na_afloop`), elk uit
  `cirkels` (zoals de start), `wijken` (namen van `metadata/wijken`, zoals `"Centrum"`) en/of
  `rechthoeken` (`[x0, z0, x1, z1]` in cellen van 4 m).

## Missies testen

Start het spel meteen bij een missie (of een stap ervan), zonder intro, menu en eerdere missies:

```
Godot --path . res://scenes/snel_starten.tscn -- --snel --missie 2
Godot --path . res://scenes/snel_starten.tscn -- --snel --missie 2 --stap verkopers
```

`--missie` is het nummer uit het `label` ("MISSIE 2") of het `id`; `--stap` het `id` van een
stap. Je staat dan vlak bij het personage waar de stap om draait (Ome Wim op het Plein), of
met `--plek <plek>` op een plek van de kaart (`--plek plein`).

Een goede startplek voor het testen zet je in het missiebestand: `"debug_start": "plein"` bij de
missie (voor `--missie`), en/of bij een stap (voor `--stap`). Het is een plek van de kaart (de
`places` van de stad, zoals bij `route`). `--plek` gaat voor, daarna die van de stap, dan die van
de missie, en anders sta je bij het personage van de stap. In het spel zelf doet het niets. De missies ervoor worden afgerond en hun pagina's weggeklikt; wat de missie of de stap
zelf laat zien, zie je gewoon (`scripts/debug/mission_jump.gd`).

Tijdens het spelen kan het ook (alleen in een debug-build, dus vanuit de editor): **F8** opent
de missiekiezer met alle missies en hun stappen (✓ klaar, ▶ bezig, · nog niet). Kies met W/S
of de pijltjes (Page Up/Down springt per missie) en druk Enter: de stad laadt opnieuw en je
gaat naar het begin van die missie, of naar die stap, net als met `--missie`/`--stap`. Zo kun
je ook terug naar een eerdere missie. Escape of F8 sluit hem (`scripts/debug/mission_picker.gd`).
Geld nodig om iets te testen: **F7** geeft je €10, Shift+F7 €100 (telt niet als verdiend).
Ervaring: **F9** geeft 100 XP, Shift+F9 precies genoeg voor het volgende level (het
level-up-scherm). Gezondheid: **F5** vol, Shift+F5 20 eraf (echte schade). Honger: **F6** vol,
Shift+F6 20 eraf. Uithoudingsvermogen: **F2** vol, Shift+F2 20 eraf. Overprikkeldheid: **F4**
rustig (0), Shift+F4 20 erbij. Allemaal in `scripts/debug/debug_keys.gd`.
**F1** laat de tijd 20× sneller gaan, of weer normaal. Op de kaart in het spelmenu (Tab, KAART)
zet **T** je bij de gekozen plek en **Shift+klik** op elk punt van de kaart (op de dichtstbijzijnde
stoep of straat).

## Personages — `gesprekken/personages.json`

Na missie 2 komen er overdag af en toe groepjes op je af (`scripts/story/street_pitches.gd`): de
telefoonverkopers, de wervers van de Stichting Rotonde in Nood (`werver_rotonde`) en twee Jehova's
getuigen (`getuige`), vooral rond de stations, de pleinen en de winkelstraten. Hun gesprek klampt
vast; alleen het goede antwoord (een verborgen `check`: `verkopers_af`, `rotonde_af`,
`getuigen_af`) laat je gaan. Bij de supermarkten scharrelt soms een Straatnieuws-verkoper rond
(`straatnieuws_ans`, `straatnieuws_henk`, `scripts/story/street_paper_sellers.gd`) die er net zo goed
weer kan zijn verdwenen.

De vaste mensen van het verhaal (Ome Wim, de goededoelenwerver, Blikken Bertus). Elk staat op een `plek`, ziet
er altijd hetzelfde uit (`uiterlijk`: kleuren als `#RRGGBB`, `hair_style` `kort`, `lang`,
`kaal`, `pet` of `hoed`), loopt in zijn eigen `tempo` en heeft `gesprekken` (elk zoals een
persoon in `voorbijgangers.json`: `begroetingen`, `onderwerp` met `verder`, ...). Welk gesprek
het nu heeft, zet een stap (`gesprekken`), anders `standaard`. Wat in alle gesprekken hetzelfde
is (`spreker`, `stemmingen`, `dag`, `kleingeld_nee`, `gulheid`, `nog_iets`), staat bij het personage zelf.

Een vraag met een **vaardigheidscheck** (zie Ome Wim):

```json
{
  "vraag": "Kom op, Wim. Wat weet je nog meer?",
  "check": {
    "id": "overtuigen_wim",
    "label": "OVERTUIGEN",
    "kans": 50,
    "gelukt": "Goed dan...",
    "mislukt": "Ik weet niks."
  }
}
```

Je ziet hem als `[OVERTUIGEN 50%] Kom op, Wim...`. Gelukt: het `gelukt`-antwoord (met zijn
`verder`), en de check is voorgoed gehaald (een stap met doel `check` is klaar). Mislukt:
het `mislukt`-antwoord, en in een volgend gesprek kun je het opnieuw proberen.

Een vraag met **`koopt_blikjes`** (euro per blikje, zie Blikken Bertus): het personage koopt al
je blikjes voor dat bedrag (het geld zoals bij een statiegeldautomaat: een stap met doel
`statiegeld` is klaar); daarna zegt het `gekocht` (met `{aantal}` en `{bedrag}`), of
`geen_blikjes` als je er geen hebt.

Een personage dat **rondzwerft** (Blikken Bertus): `zwerft` = `{"punten": [[x, z], ...]` (meters
vanaf zijn `plek`, een rondje), `"tempo"` (m/s), `"rookpauze": [van, tot]` (seconden stil bij
een punt), `"karretje": true` (een winkelkarretje vol blikjes dat hij duwt), `"rookt": true` (een
sjekkie met rookwolkjes, af en toe een trekje en een wolk uitblazen)}. Het verschijnt zodra een
stap het laat komen (`storing` `persoon`) en blijft daarna rondlopen; komt de speler dichtbij,
dan blijft het staan en kijkt hem aan. `mompelt`: losse zinnetjes die het af en toe in een
tekstballon zegt (om de 8 tot 25 seconden, alleen met de speler in de buurt, nooit twee keer
dezelfde achter elkaar). `stem`: een eigen stem voor het gebrabbel (`rasperig`: laag en schor,
`brabbel_rasperig_*` uit `tools/megadrive/stemmen.py`). In `uiterlijk` geeft `"model": "bertus"`
hem een eigen figuur (lange jas met lappen, sjaal, baard, gebreide muts met pompon, sjekkie;
kleuren `patch`, `scarf`, `pompom`: `TownsfolkFigure._bertus`).

Een gesprek dat je **niet kunt afbreken** (de telefoonverkopers van Lebaarmoeder): zet in het
gesprek `"klampt_vast": true`. Dan is er geen "dag" en geen kleingeld; loopt een tak dood, dan
zeggen ze een regel uit `opnieuw` en beginnen ze weer bij de eerste keuzes van het `onderwerp`.
Elk antwoord maakt je `prikkels` overprikkelder. Alleen een vraag met een `check` laat je
gaan: met `"kans": 100` en `"verborgen": true` (geen `[LABEL 100%]` ervoor, geen melding) is
het gewoon het goede antwoord; zijn `gelukt` is hun laatste woord.

Een stap kan iemand **achter je aan sturen**: `"achtervolgen": {"persoon": "telefoonverkoper",
"groep": ["telefoonverkoper_kevin", ...]}`. Een paar seconden later verschijnen ze een meter of
tien achter je (met `verborgen_tot_open` staat de stap pas in de takenlijst als ze binnen zes meter
zijn), lopen op je af, blijven je volgen en de `persoon` begint zelf het gesprek (na afloop opnieuw);
`eerst_paginas` (zoals `klaar_paginas`) komen één keer vlak daarvoor, bv. de verteller die je waarschuwt. Is de
stap klaar (doel `check` met het id van die verborgen check), dan lopen ze weg.

Opdruk op de kleren in `uiterlijk`: `"opdruk": "L"` (een grote letter op de buik, kleur
`opdruk_kleur`) en `"rugopdruk": "telefoon"` (een logo op de rug, `rugopdruk_kleur`); de
patronen staan in `TownsfolkFigure.CHEST_PRINTS` en `BACK_PRINTS`.

## De proloog — `verhaal/proloog.json`

De pagina's na het wakker worden, met de banner linksboven (`banner_soort`, `banner`).
De startpagina's van missies met `"start": "na_proloog"` komen er direct achteraan.

## Gesprekken met voorbijgangers — `gesprekken/voorbijgangers.json`

- `vragen`: wat je kunt vragen (`kleingeld`) en waarmee je afsluit (`dag`). Om kleingeld vragen
  kan pas als het verhaal `bedelen` heeft ontgrendeld (missie 1, na het inleveren van de blikjes).
- `nog_iets`: wat ze erachter zeggen ("Nog iets?").
- `stemmingen`: de stemming per soort regel (`begroeting`, `onderwerp`, `doorvraag`,
  `kleingeld_ja`, `kleingeld_nee`, `dag`). Stemmingen: `neutraal`, `blij`,
  `opgewonden`, `boos`, `verdrietig`. Ze bepalen het gebrabbel en hoe het poppetje beweegt.
- `personen`: de soorten mensen. **De eerste waarvan `herkennen` klopt** wordt gekozen,
  dus zet de algemeenste (bv. de forens, `"herkennen": {}`) als laatste.

Een **persoon**:

```json
{
  "id": "student",
  "herkennen": { "haar": "lang", "rok": false },
  "spreker": "STUDENT",
  "begroetingen": ["Hé! Wat is er?"],
  "onderwerp": {
    "vraag": "Wat studeer je?",
    "antwoord": "...",
    "doorvraag": "...",
    "doorantwoord": "..."
  },
  "kleingeld_ja": "Hier, een paar centen.",
  "kleingeld_nee": "Sorry!",
  "dag": "Doei!",
  "gulheid": { "kans": 30, "bedrag": 0.1 },
  "stemmingen": { "begroeting": "opgewonden" }
}
```

**Meer gesprekken per soort mens — `varianten`.** Zodat twee forenzen niet hetzelfde zeggen,
kan elke persoon (ook in `personeel.json`) een lijst `varianten` hebben: andere gesprekken voor
dezelfde soort. Een variant bevat alleen wat anders is (meestal een eigen `onderwerp`, soms ook
eigen `begroetingen`, `kleingeld_ja`, `kleingeld_nee`, `dag` of `stemmingen`); de rest komt van
de persoon zelf. Wie je aanspreekt krijgt de eerste keer willekeurig de persoon zelf of één van
de varianten, en houdt dat gesprek (praat je nog eens met dezelfde, dan zegt die hetzelfde soort
dingen). Wie zich voordoet als dezelfde soort (`ambtenaar` en `kantoormens`, `toerist` en
`toerist_op_straat`, `forens` en `forens_op_straat`) heeft dezelfde varianten.

```json
"varianten": [
	{"onderwerp": {"vraag": "Op welke tram wacht u?", "antwoord": "Lijn 17...", "doorvraag": "...", "doorantwoord": "..."}},
	{"begroetingen": ["Sorry, ik ben een beetje laat."], "onderwerp": {...}, "dag": "..."}
]
```

**Een kleine beloning — `beloning`.** Elke vraag in het boompje (het `onderwerp` zelf of een
vraag onder `verder`) kan een `beloning` hebben: `{"item": "koffie", "kans": 35, "tekst": "Hier,
neem die tweede beker maar."}`. Krijg je dat antwoord, dan geeft die persoon je met `kans` op 100
dat item, met wat XP (`xp`, anders 25), en zegt er `tekst` achteraan. Als het gesprek klaar is,
komt het item in het beloningsscherm (groot en draaiend, met zijn deuntje).
Laat de beloning passen bij wat er net gezegd wordt (de man van de markt geeft een appel, de
forens die zijn trein haalt zijn koffie). Eén kans per persoon; geen ruimte in je zakken, dan
krijg je niets. `"item": "pinpas"` is een gevonden pinpas met een eigen saldo en pincode (houd de
kans daarvan klein, 5 tot 10).

**Langere gesprekken — het onderwerp als boompje.** Na het `antwoord` van een `onderwerp` kun je
de `doorvraag` stellen (antwoord: `doorantwoord`) en/of een van de vragen onder `verder`. Elke
vraag onder `verder` is `{"vraag", "antwoord", "stemming" (optioneel, de stemming van precies
dat antwoord), "verder" (optioneel, weer zulke vragen)}`, zo diep als je wilt. Meerdere vragen
onder één `verder` zijn keuzes: je kiest er één, de andere vervallen. Heeft een antwoord geen
vervolg meer, dan zegt de ander er "Nog iets?" (`nog_iets`) achter en kun je weer om kleingeld
vragen of gedag zeggen. Houd elk antwoord kort (onder de ~180 tekens), het moet in het venster passen.

```json
"onderwerp": {
	"vraag": "Waar werkt u?", "antwoord": "In Rotterdam...",
	"verder": [
		{"vraag": "Vindt ze dat erg?", "antwoord": "...", "verder": [
			{"vraag": "Noem er eens een.", "antwoord": "Truus...", "stemming": "verdrietig"}
		]},
		{"vraag": "Wat doet u in de trein?", "antwoord": "..."}
	]
}
```

**Willekeurige regels.** `begroetingen` is altijd een lijst; ook `kleingeld_ja`, `kleingeld_nee`,
`dag`, `betrapt` en een `antwoord` mogen een lijst zijn: dan wordt er elke keer één gekozen.

`herkennen` kan hebben: `soort` (de soort mens uit `drukte.json`, bv. `"oudere"`: zo praat
iedereen op straat als wat hij is), `vervoer` (`"rolstoel"`, `"scootmobiel"`), `haar` (`"kort"`,
`"lang"`, `"kaal"`, `"pet"`, `"hoed"`), `rok` en `vrouw` en `grijs` (`true`/`false`), `draagt`
(`"rugzak"`, `"rolkoffer"`, `"aktetas"`, `"handtas"`, `"schoudertas"`), `jas` (een lijst
kleuren, bv. `["#22242A"]`). `gulheid`: de kans in 100 dat ze wat kleingeld geven, en hoeveel euro.

**Wat ze zijn.** Boven het gesprek staat niet "voorbijganger" maar wat je ziet: "OUDE DAME",
"MAN MET HOED", "ZAKENVROUW MET ROLKOFFER". Dat komt uit `namen`: een lijst van
`{"als": {...}, "naam": "..."}` (dezelfde voorwaarden als `herkennen`), eerst die van de persoon
zelf, dan de algemene `namen` bovenin het bestand; de eerste die klopt. Zet de precieze
(met meer voorwaarden) bovenaan en eindig met een `{"als": {}, ...}`. `vrouw` is lang haar of
een rok, `grijs` grijs of wit haar.

## Personeel: conducteurs, handhavers en agenten — `gesprekken/personeel.json`

In Den Haag Centraal lopen conducteurs van de NS (blauw uniform met pet) en handhavers
(blauw uniform); op straat lopen handhavers en agenten van de politie (donkerblauw, embleem
`POLITIE`) mee in de drukte (de soorten `handhaver` en `agent` in `drukte.json`). Spreek je ze aan, dan praten ze niet als een voorbijganger maar als
iemand in dienst: over treinen, vertraging, inchecken en zwartrijden (conducteur), over
regels, rondhangen, boetes en "even uw legitimatie" (handhaver). Om kleingeld vragen heeft
geen zin: ze weigeren, in stijl. Het gespreksvak laat zien dat het personeel is: hun titel
op een naamkaartje in hun eigen kleuren, het embleem (`NS`, `BOA`) op het portret, de rand
en de cursor in hun kleur en een lagere stem.

Onder `personen` staat per rol (`conducteur`, `handhaver`) een persoon met dezelfde velden
als in `voorbijgangers.json` (`spreker`, `begroetingen`, `onderwerp`, `kleingeld_nee`,
`dag`, `stemmingen`; `gulheid` niet: ze geven nooit), plus:

| veld                        | wat                                                                                                                                                                                                     |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `spreker`                   | de titel op het naamkaartje (`"CONDUCTEUR NS"`, `"HANDHAVING"`)                                                                                                                                         |
| `embleem`                   | het korte embleem linksboven op het portret                                                                                                                                                             |
| `kleur`                     | de kleur van het uniform: rand van het portret, rand van het naamkaartje, cursor                                                                                                                        |
| `naamkaartje`, `tekstkleur` | achtergrond en tekst van het naamkaartje en het embleem                                                                                                                                                 |
| `stemhoogte`                | hoe hoog ze brabbelen (1,0 = gewoon, lager = zwaarder)                                                                                                                                                  |
| `nog_iets`                  | eigen zinnen na een antwoord (anders die van de voorbijgangers)                                                                                                                                         |
| `betrapt`                   | alleen de conducteur: wat hij zegt als je met hem praat terwijl hij je achternazit omdat je zwartreed; je krijgt dan de boete (`{boete}`: het bedrag)                                                   |
| `betrapt_uitchecken`        | alleen de conducteur: hetzelfde als hij je achternazit omdat je zonder uit te checken over de poortjes naar buiten ging (hij checkt je uit en je krijgt de boete); zonder deze regel zegt hij `betrapt` |

Controle: `tests/run_integration_tests.sh staff_talk`.

## De snackbarhouder — `gesprekken/snackbarhouder.json`

Wie je aanspreekt achter de toonbank van een snackbar krijgt het **winkelscherm**
(`scripts/ui/shop_screen.gd`): de naam van de zaak, de verkoper, een getypte begroeting,
de goederen met prijs, je geld en je zakken. Kiezen met de pijltjes of W/S, kopen met
Enter (of 1–9 meteen), weggaan met Esc; de muis werkt ook. Bij te weinig geld knippert
TE WEINIG GELD en noemt de verkoper de prijs; bij volle zakken ZAKKEN VOL. Wat je koopt
gaat in je zakken (zoals de kroket van missie 1).

`spreker` (het naamkaartje), `soort` (bovenin het scherm, bv. `"SNACKBAR"`),
`begroetingen` (met `{snackbar}` of `{zaak}`: de naam van de zaak), `menu` (de goederen:
`item` uit `scripts/player/items.gd`, `vraag`, `prijs` in euro, `naam` zoals de verkoper
het noemt; `"slot": "snackkaart"`: pas te koop als het verhaal dat ontgrendelt, zie **Missies** `ontgrendelt`), `gekocht` (met `{wat}`), `geen_geld` (met `{prijs}`), `zakken_vol`,
`tip_vraag` en `tip` (een rij "iets vragen"; weg als er geen `tip` is; `tip` mag een lijst
zijn, dan zegt de verkoper elke keer een andere), `dag` (bij weggaan, ook een tekst of een
lijst), `nog_iets` (achter wat ze zeggen na een aankoop, een tekst of een lijst), `stemmingen` (per soort zin:
`begroeting`, `gekocht`, `geen_geld`, `zakken_vol`, `tip`, `dag`).

## De winkels van Den Haag Centraal — `gesprekken/winkels.json`

Elke zaak heeft `kleding`: wat de verkoper draagt, passend bij de zaak (`jas`, `rand` voor
kraag of schort, `broek`, en eventueel `pet` voor een muts of pet), bv. de barista in zwart met een
bruin schort, de bloemist in groen, de broodjesmaker in het wit.

Op het station is alles duurder dan in de stad: wat de snackbar in de stad ook verkoopt, kost
hier minstens 1,3 keer zoveel (`STATION_MARKUP` in `scripts/story/conversations.gd`; staat er in
winkels.json minder, dan houdt het spel die ondergrens aan).

In het station staat achter elke winkel en kiosk een verkoper; je spreekt ze aan vóór de
toonbank (`[E] Winkelen`; bij een snackbar `[E] Bestellen`) en dan opent hetzelfde winkelscherm. Onder `winkels` staat per
**soort zaak** (de `kind` van de markers `Verkoper_<n>` in `scenes/binnen/centraal.tscn`,
gemaakt door `tools/build/build_interiors.gd`, `SHOPS`) wat die verkoper zegt en verkoopt,
met **dezelfde velden** als `snackbarhouder.json`. Wat een zaak weglaat komt uit
`snackbarhouder.json` (Smikkels heeft daardoor dezelfde `gekocht`-zinnen als een snackbar).

| soort          | zaken                                  | assortiment                                                                           |
| -------------- | -------------------------------------- | ------------------------------------------------------------------------------------- |
| `koffie`       | Duwus Bertus                           | koffie € 2,80, cappuccino € 3,40, gevulde koek € 2,25                                 |
| `broodjes`     | Broodje Seinstoring                    | broodje kaas € 3,95, broodje kroket € 4,50, krentenbol € 1,25                         |
| `kiosk`        | Kiosk Centraal, Kiosk Perron 12        | koffie € 2,60, flesje water € 2,20, energiedrank € 2,50, krant € 3,50, kauwgom € 1,80 |
| `bloemen`      | Bloemen van de Hofvijver, Tulp & Tak   | bos tulpen € 4,99, losse roos € 2,50                                                  |
| `boeken`       | Boek & Spoor                           | puzzelboekje € 4,50, kaart van Den Haag € 6,95, pocketboek € 12,99                    |
| `stroopwafels` | Stroopwafel Express                    | verse stroopwafel € 2,50, pak stroopwafels € 4,95                                     |
| `snoep`        | De Zoete Inval                         | zak drop € 2,49, zak winegums € 2,49, chocoladereep € 1,99                            |
| `smikkels`     | Smikkels (een snackbar in het station) | kroket € 2,75, frikandel € 2,75, patatje met € 3,95                                   |

Een nieuw product: zet het item in `scripts/player/items.gd` (naam, soort, tekst, effect;
een eigen icoon in `GameMenu.ITEM_ICONS`) en een regel in het `menu` van de zaak.
Controle: `tests/run_integration_tests.sh shop`.

## De supermarkten — `gesprekken/supermarkten.json`

DERREK en ALFRED STEYHN (`scripts/world/interiors/supermarket.gd`). Je pakt bij de ingang een karretje of
een mandje, uit elk schap één product, en rekent af bij de kassa. Per keten (`ketens`):

| veld                          | wat                                                                                                                                                                                                                                                                                                    |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `naam`, `kleur`, `tekstkleur` | de naam en de huisstijl: de borden boven de gangpaden, de kassanummers, het naamkaartje van de caissière                                                                                                                                                                                               |
| `karretje`, `mandje`          | hoeveel dingen erin passen                                                                                                                                                                                                                                                                             |
| `kleding`                     | wat het personeel draagt (`jas`, `rand`, `broek`, eventueel `pet`)                                                                                                                                                                                                                                     |
| `producten`                   | per soort schap (`droog`, `ontbijt`, `snoep`, `drank`, `verzorging`, `conserven`, `zuivel`, `diepvries`, `brood`, `bakkerij`, `groente`, `bloemen`, `actie`) het `item` (uit `scripts/player/items.gd`), de `prijs` en de `naam` op het schap; een soort die een keten niet heeft, verkoopt daar niets |
| `bonus`                       | (ALFRED STEYHN) `aantal` soorten schappen per filiaal met `korting` (0,25 = een kwart eraf), met het bordje `tekst`                                                                                                                                                                                    |
| `kassa`                       | wat de caissière zegt: `begroetingen`, `totaal` ({prijs}, {aantal}), `betaald`, `terugleggen` en `zakken_vol` ({wat}), `niets` (geen geld voor ook maar één ding: telt als `geen_geld`), `leeg`, `laat_maar`, `stemmingen`                                                                             |
| `zelfscan`                    | (ALFRED STEYHN) hetzelfde voor de zelfscankassa                                                                                                                                                                                                                                                        |

De medewerkers in de winkel (`medewerker_derrek`, `medewerker_alfred_steyhn`) praten uit
`personeel.json`, net als de mensen in het stadhuis (`receptioniste`, `beveiliger`,
`ambtenaar`, `raadslid`, `burgemeester`).

## Omroepen in de supermarkt — `gesprekken/omroep_supermarkt.json`

Net als op het station (`scripts/world/station/station.gd`) wordt er in de supermarkten af en toe iets
omgeroepen (`scripts/world/interiors/supermarket_announcer.gd`): de muzak gaat zachter, de jingle van de
keten klinkt (`assets/audio/muziek/jingle_derrek.ogg`, `jingle_alfred_steyhn.ogg`, gemaakt door
`tools/muziek/`), dan praat de omroepstem door de luidsprekers en verschijnt de tekst onderin beeld.

| veld                          | wat                                                                                                              |
| ----------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `eerste`                      | na hoeveel seconden binnen (van, tot) het eerste bericht komt                                                    |
| `tussen`                      | hoeveel seconden (van, tot) het na een bericht stil blijft                                                       |
| `aanbieding_kans`             | hoe vaak het een aanbieding is (0..1); anders een mededeling                                                     |
| `mededelingen`                | voor beide ketens; `{kassa}` een kassanummer van dit filiaal, `{gang}` een gangpad (1-6)                         |
| `ketens.<keten>.stem`         | de brabbel van de omroeper: `vrouw`, `man` of `oude_man`                                                         |
| `ketens.<keten>.aanbieding`   | een product uit een schap van dít filiaal: `{naam}` (zoals op het schap) en `{prijs}` (de prijs van dit filiaal) |
| `ketens.<keten>.bonus`        | (ALFRED STEYHN) als dat product in dit filiaal in de BONUS is                                                    |
| `ketens.<keten>.mededelingen` | mededelingen van de keten zelf                                                                                   |

## Eruit gegooid worden — `gesprekken/uitzetten.json`

Wie in een binnenruimte iets doet wat niet mag, wordt eerst gewaarschuwd door iemand van de
plek (`waarschuwing`); wie het te vaak doet (`na`), is er niet meer welkom. Alleen iemand
van de plek kan je eruit zetten: de `uitzetter` (`wie`) roept wat er mis is (`roep`) en komt
op je af, net als de conducteur bij zwartrijden; onderweg roept die af en toe een van de
`kreten`. Pas als die bij je is, word je eruit gezet: de swipe, en de speler vliegt de deur
uit en tuimelt de straat op; als hij weer staat, vertelt de verteller wat er gebeurde, en een
tijdje (`terug_na` seconden) mag hij er niet in. Ga je zelf eerder de deur uit, dan ben je
weg, maar mag je er die tijd ook niet in. Herbruikbaar voor elke plek
(`scripts/world/interiors/interiors.gd`: `Interiors.note_offence(tree, overtreding)`; het achter je aan
komen is gedeeld: `scripts/world/interiors/eviction.gd`, met de regels van de achtervolging van
`scripts/world/interiors/pursuit.gd`, ook die van de conducteur).

| veld                      | wat                                                                                                                                                                                                  |
| ------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `plekken`                 | per soort binnenruimte (`snackbar`, `centraal`, `derrek`, `alfred_steyhn`, `stadhuis`) zijn `overtredingen`                                                                                          |
| `na`                      | hoeveel keer in één bezoek genoeg is (1: meteen)                                                                                                                                                     |
| `waarschuwing`            | de waarschuwingen vóór `na`: de eerste keer de eerste regel, de tweede keer de tweede (de laatste is de laatste waarschuwing); iemand van de plek roept hem en boven je staat "Waarschuwing 1 van 2" |
| `roep`                    | wat de uitzetter roept als die op je af komt (één van de regels; leeg: een van de `kreten`)                                                                                                          |
| `uitzetter`               | per plek: `wie` (de rol: wie er komt) en `kreten` (wat die onderweg en bij het pakken roept)                                                                                                         |
| `tekst`                   | de bladzijden van de verteller, na elkaar                                                                                                                                                            |
| `terug_na`, `niet_binnen` | seconden dat je er niet in mag, en wat er dan boven je zweeft                                                                                                                                        |

Overtredingen nu: `bedelen` (om kleingeld vragen), `geen_geld` (iets kopen zonder genoeg geld),
`boete_onbetaald` (betrapt op zwartrijden en de boete niet kunnen betalen: de conducteur
staat al bij je, dus meteen eruit; wie wel kan betalen, betaalt alleen), `winkeldiefstal` (met
onbetaalde spullen in je karretje of mandje een supermarkt uit lopen: de poortjes blijven
dicht en een kassamedewerker komt je halen). Een nieuwe: meld hem met `Interiors.note_offence`
waar hij gebeurt en zet hem per plek in dit bestand.

## Drukte op straat — `drukte.json`

Hoe druk het is rond de speler en wie er rondloopt en -rijdt. Alles werkt met **gewichten**:
een groter getal komt vaker voor, `0` nooit; een soort die niet genoemd wordt telt als `1`
(bij `gebieden`) of als `0` (bij `uren`). Controle: `tests/run_unit_tests.gd -- crowd`.

| deel             | wat                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| ---------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `uren`           | momenten van de dag, op volgorde van `uur` (0 tot 24). Elk: `voetgangers` en `verkeer` (hoe druk: 1,0 = normaal, 0,1 = bijna niemand; het verkeer gaat in de spits tot 1,7; de spits zijn twee momenten met dezelfde waarden, zodat hij een tijd aanhoudt), `station` (hoeveel mensen er bij Den Haag Centraal uit de deuren komen en erin verdwijnen: 1,0 = de spits, 0 = niemand), `mensen` (welke soorten mensen er dan zijn) en `voertuigen` (welke voertuigsoorten). Tussen twee momenten loopt het geleidelijk over. |
| `gebieden`       | per wijk (de namen die de HUD linksonder toont, bv. `"Centraal Station"`, `"Binckhorst"`, `"A12"`): `voetgangers` en `verkeer` keer zoveel als het uur zegt, en `mensen` en `voertuigen` als extra gewichten. Een wijk die er niet in staat telt als 1. Met `avond` (`van`, `tot` in uren, mag over middernacht; `voetgangers`, `mensen`) wordt het er 's avonds nog drukker met ander volk: het Plein en de Grote Markt vol uitgaanspubliek en nachtbrakers.                                                              |
| `voertuig_basis` | hoe vaak elke voertuigsoort voorkomt voor uur en wijk erbij komen.                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| `mensen`         | de soorten mensen (zie hieronder).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |

Voertuigsoorten: `auto`, `fiets` (fietser, fatbike), `brommer` (brommer, scooter, motor),
`vracht` (busje, vrachtwagen, auto met aanhanger), `bus`, `landbouw` (trekker) en `klein`
(brommobiel).

Een **soort mens** (bv. `"forens"`):

| veld                                           | wat                                                                                      |
| ---------------------------------------------- | ---------------------------------------------------------------------------------------- |
| `jassen`, `broeken`, `schoenen`, `haarkleuren` | kleuren (`"#22242A"`) waaruit gekozen wordt; weggelaten = elke kleur                     |
| `kapsels`                                      | gewichten van `kort`, `lang`, `kaal`, `pet`, `hoed`                                      |
| `uniform`                                      | vaste kleding (`coat`, `trim`, `trousers`, `cap`, `shoes`: kleuren), bv. van de politie  |
| `rok`                                          | kans op een rok (alleen bij lang haar), 0 tot 1                                          |
| `tempo`                                        | hoe snel ze lopen, 1,0 = gewoon                                                          |
| `rolstoel`, `scootmobiel`                      | welk deel in een rolstoel of op een scootmobiel zit, 0 tot 1                             |
| `dragen`                                       | gewichten van `aktetas`, `handtas`, `schoudertas`, `rugzak`, `rolkoffer` en `""` (niets) |
| `pak`                                          | `true`: in pak (donker colbert en broek)                                                 |

Een nieuwe soort mens: voeg hem toe onder `mensen` en geef hem een gewicht bij de `uren`
waarop hij buiten is (en eventueel bij een paar `gebieden`), en een persoon in
`gesprekken/voorbijgangers.json` met `"herkennen": {"soort": "<naam>"}` en zijn `namen`, zodat hij
praat als wat hij is. Iemand in dienst (`agent`, `handhaver`) praat uit `personeel.json`.

## Automaten, blikjes en pinpassen (geen JSON)

De teksten en bedragen van de automaten staan niet in een JSON-bestand maar in de code (zie
ook "Automaten, blikjes en pinpassen" in `INSTRUCTIONS.md`):

| wat                                                                                                                                                                                                                                       | waar                                                                                                                                 |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| de spullen `blikje`, `pinpas`, `los_kaartje` (naam, tekst)                                                                                                                                                                                | `scripts/player/items.gd`                                                                                                            |
| statiegeld per blikje (€ 0,40) of fles (€ 0,15) bij de automaat (Blikken Bertus geeft € 0,25 per blikje: `koopt_blikjes` in personages.json)                                                                                              | `DEPOSIT` in `scripts/world/things/deposit_return.gd`                                                                                |
| prijs OV-chipkaart, startsaldo, ritprijs, los kaartje, opwaardeerbedragen, instaptarief (niet uitgecheckt, € 4); kopen en opladen alleen bij de automaten in de hal van Centraal, bij de tramhaltes staan OV-paaltjes (in- en uitchecken) | `scripts/world/station/ov_card.gd`; de paaltjes bij tramhaltes: `tools/build/city/finishing.gd` (`MOST_OV_POSTS`, `OV_POST_SPACING`) |
| kans dat een conducteur zwartrijden of niet uitchecken over de poortjes ziet, de kaartcontrole op het perron (afstand, kans), de boete (€ 50)                                                                                             | `FARE_CHECK_CHANCE`, `INSPECTION_REACH`, `INSPECTION_CHANCE`, `FINE_EUROS` in `scripts/world/station/station.gd`                     |
| saldo van een gevonden pinpas (€ 8 - € 60), de raadsels bij de pincode, de namen op de pas                                                                                                                                                | `scripts/player/bank_cards.gd` (`BALANCE_RANGE`, `DIGIT_RIDDLES`, `OWNERS`)                                                          |
| bedragen bij de geldautomaat (€ 5, 10, 20, 50), pogingen voor de pas wordt ingeslikt (3)                                                                                                                                                  | `AMOUNTS` in `scripts/ui/machines/cash_machine_screen.gd`, `MOST_TRIES` in `bank_cards.gd`                                           |
| hoeveel prullenbakken een blikje hebben, hoe vaak er een bijkomt                                                                                                                                                                          | `can_share`, `most_cans`, `refill_seconds` in `scripts/world/things/litter_bins.gd`                                                  |
| hoeveel pinpassen er op straat liggen (pas als het verhaal `pinpassen` ontgrendelt; dan 1)                                                                                                                                                | `count`, `near_count`, `near`, `reach` in `scripts/world/things/lost_bank_cards.gd`                                                  |
| hoeveel kleingeld er op straat ligt (pas als het verhaal `kleingeld` ontgrendelt; dan 1 munt, niet bij de start)                                                                                                                          | `count`, `near_count`, `near`, `reach`, `VALUES` in `scripts/world/things/loose_change.gd`                                           |

Een raadsel bij de cijfers (`DIGIT_RIDDLES`) moet echt dat cijfer opleveren: rij 0 is het
cijfer 0, rij 8 het cijfer 8 ("de poten van een spin"). Controleer na een wijziging met
`tools/godot.sh --headless --script tests/run_unit_tests.gd -- bank_cards` (die rekent elk raadsel na).
In een gesprek een pinpas geven: `speler.give_found_bank_card()`; een blikje: het item `blikje`.
