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
(`01_kroket.json`, `02_...json`). Een nieuwe missie: kopieer `01_kroket.json`, geef het
een nieuwe naam en een nieuwe `"id"`.

| veld | wat |
|---|---|
| `id` | unieke naam, bv. `"missie_2_slaapplek"` |
| `label`, `titel` | boven in beeld en in het questlog: `"MISSIE 2"`, `"Een dak boven je hoofd"` |
| `gever`, `beschrijving` | van wie de opdracht komt en wat het is (questlog) |
| `soort` | `"verhaal"` (standaard) of `"zij"` (een zijmissie) |
| `start` | `"na_proloog"`, of `"na:missie_1_kroket"` (als die klaar is) |
| `xp` | XP voor de hele missie |
| `beloningen` | teksten in het questlog, bv. `["KROKET", "+40 HONGER"]` |
| `start_paginas` | wat er verteld wordt als de missie begint |
| `stappen` | de stappen, na elkaar (de volgende is doorzichtig tot de vorige klaar is) |
| `einde_paginas` | wat er verteld wordt als alles klaar is |

Een **stap**:

```json
{
	"id": "kroket",
	"tekst": "Koop een kroket bij een snackbar",
	"xp": 100,
	"doel": {"soort": "kopen", "item": "kroket"},
	"plekken": {"soort": "snackbars", "aantal": 3},
	"klaar_paginas": [{"soort": "gedachte", "tekst": "Eindelijk een kroket."}]
}
```

Een stap met `"overslaan_als": {"startgeld_minstens": 2.0}` wordt overgeslagen (meteen
klaar, zonder XP) voor een karakter dat met minstens zoveel geld begint.

Soorten **doel**:

| soort | velden | klaar als |
|---|---|---|
| `geld_verdiend` | `bedrag` | je zoveel gevonden of gekregen geld nog op zak hebt (wat je uitgeeft telt weer af, je startgeld telt niet mee; hetzelfde bedrag als in je portemonnee) |
| `kopen` | `item` | je het gekocht hebt (een item uit `scripts/player/items.gd`) |
| `praten_met` | `persoon` | je met zo iemand praat (een `id` uit de gesprekken, of `"iemand"`) |
| `naar_plek` | `plek`, `straal` | je binnen `straal` meter van die plek bent |

**Plekken** op het kaartje en de kaart (optioneel): `{"soort": "snackbars", "aantal": 3}`
(de dichtstbijzijnde), `{"soort": "plek", "plek": "koekamp"}` of
`{"soort": "plekken", "plekken": ["koekamp", "centraal"]}`. De namen van plekken staan in
`scenes/stad.tscn` onder `metadata/places` (o.a. `centraal`, `koekamp`,
`snackbar_hertenkamp`, `malieveld`). Bij `naar_plek` wordt die plek vanzelf aangewezen.

Een **pagina**: `{"soort": "verhaal", "tekst": "..."}`. Soorten: `verhaal` (de verteller),
`gedachte` (je karakter denkt), `missie` (een opdracht), `gesprek` (iemand anders, met
`"spreker": "NAAM"`).

In teksten kun je invullen: `{naam}` (je karakter), `{achtergrond}` (zijn verhaal),
`{voortgang}` (in de tekst van een stap: hoe ver je bent, bv. `€ 1,20`), `{geldregel}`
(een regel uit `"geldregel": {"leeg": ..., "wel": ...}`: of je karakter geld heeft).

## De proloog — `verhaal/proloog.json`

De pagina's na het wakker worden, met de banner linksboven (`banner_soort`, `banner`).
De startpagina's van missies met `"start": "na_proloog"` komen er direct achteraan.

## Gesprekken met voorbijgangers — `gesprekken/voorbijgangers.json`

- `vragen`: wat je kunt vragen (`kleingeld`) en waarmee je afsluit (`dag`).
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
	"herkennen": {"haar": "lang", "rok": false},
	"spreker": "STUDENT",
	"begroetingen": ["Hé! Wat is er?"],
	"onderwerp": {"vraag": "Wat studeer je?", "antwoord": "...", "doorvraag": "...", "doorantwoord": "..."},
	"kleingeld_ja": "Hier, een paar centen.",
	"kleingeld_nee": "Sorry!",
	"dag": "Doei!",
	"gulheid": {"kans": 30, "bedrag": 0.1},
	"stemmingen": {"begroeting": "opgewonden"}
}
```

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

| veld | wat |
|---|---|
| `spreker` | de titel op het naamkaartje (`"CONDUCTEUR NS"`, `"HANDHAVING"`) |
| `embleem` | het korte embleem linksboven op het portret |
| `kleur` | de kleur van het uniform: rand van het portret, rand van het naamkaartje, cursor |
| `naamkaartje`, `tekstkleur` | achtergrond en tekst van het naamkaartje en het embleem |
| `stemhoogte` | hoe hoog ze brabbelen (1,0 = gewoon, lager = zwaarder) |
| `nog_iets` | eigen zinnen na een antwoord (anders die van de voorbijgangers) |
| `betrapt` | alleen de conducteur: wat hij zegt als je met hem praat terwijl hij je achternazit omdat je zwartreed; je krijgt dan de boete (`{boete}`: het bedrag) |

Controle: `tools/godot.sh --headless --script tools/check/staff_talk_test.gd`.

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
het noemt), `gekocht` (met `{wat}`), `geen_geld` (met `{prijs}`), `zakken_vol`,
`tip_vraag` en `tip` (een rij "iets vragen"; weg als er geen `tip` is), `dag` (bij
weggaan), `nog_iets` (achter wat ze zeggen na een aankoop), `stemmingen` (per soort zin:
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

| soort | zaken | assortiment |
|---|---|---|
| `koffie` | Duwus Bertus | koffie € 2,80, cappuccino € 3,40, gevulde koek € 2,25 |
| `broodjes` | Broodje Seinstoring | broodje kaas € 3,95, broodje kroket € 4,50, krentenbol € 1,25 |
| `kiosk` | Kiosk Centraal, Kiosk Perron 12 | koffie € 2,60, flesje water € 2,20, energiedrank € 2,50, krant € 3,50, kauwgom € 1,80 |
| `bloemen` | Bloemen van de Hofvijver, Tulp & Tak | bos tulpen € 4,99, losse roos € 2,50 |
| `boeken` | Boek & Spoor | puzzelboekje € 4,50, kaart van Den Haag € 6,95, pocketboek € 12,99 |
| `stroopwafels` | Stroopwafel Express | verse stroopwafel € 2,50, pak stroopwafels € 4,95 |
| `snoep` | De Zoete Inval | zak drop € 2,49, zak winegums € 2,49, chocoladereep € 1,99 |
| `smikkels` | Smikkels (een snackbar in het station) | kroket € 2,75, frikandel € 2,75, patatje met € 3,95 |

Een nieuw product: zet het item in `scripts/player/items.gd` (naam, soort, tekst, effect;
een eigen icoon in `GameMenu.ITEM_ICONS`) en een regel in het `menu` van de zaak.
Controle: `tools/godot.sh --headless --script tools/check/shop_test.gd`.

## Eruit gegooid worden — `gesprekken/uitzetten.json`

Wie in een binnenruimte te vaak iets doet wat niet mag, wordt eruit gegooid: de swipe, en de
speler vliegt de deur uit en tuimelt de straat op; als hij weer staat, vertelt de verteller
wat er gebeurde, en een tijdje (`terug_na` seconden) mag hij er niet in.
Herbruikbaar voor elke plek (`scripts/world/interiors.gd`: `Interiors.note_offence(tree, overtreding)`).

| veld | wat |
|---|---|
| `plekken` | per soort binnenruimte (`snackbar`, `centraal`) zijn `overtredingen` |
| `na` | hoeveel keer in één bezoek genoeg is (1: meteen) |
| `tekst` | de bladzijden van de verteller, na elkaar |
| `terug_na`, `niet_binnen` | seconden dat je er niet in mag, en wat er dan boven je zweeft |

Overtredingen nu: `bedelen` (om kleingeld vragen), `geen_geld` (iets kopen zonder genoeg geld),
`boete_onbetaald` (betrapt op zwartrijden en de boete niet kunnen betalen: meteen eruit; wie
wel kan betalen, betaalt alleen). Een nieuwe: meld hem met `Interiors.note_offence`
waar hij gebeurt en zet hem per plek in dit bestand.

## Drukte op straat — `drukte.json`

Hoe druk het is rond de speler en wie er rondloopt en -rijdt. Alles werkt met **gewichten**:
een groter getal komt vaker voor, `0` nooit; een soort die niet genoemd wordt telt als `1`
(bij `gebieden`) of als `0` (bij `uren`). Controle: `tests/run_unit_tests.gd -- crowd`.

| deel | wat |
|---|---|
| `uren` | momenten van de dag, op volgorde van `uur` (0 tot 24). Elk: `voetgangers` en `verkeer` (hoe druk: 1,0 = normaal, 0,1 = bijna niemand; het verkeer gaat in de spits tot 1,6), `station` (hoeveel mensen er bij Den Haag Centraal uit de deuren komen en erin verdwijnen: 1,0 = de spits, 0 = niemand), `mensen` (welke soorten mensen er dan zijn) en `voertuigen` (welke voertuigsoorten). Tussen twee momenten loopt het geleidelijk over. |
| `gebieden` | per wijk (de namen die de HUD linksonder toont, bv. `"Centraal Station"`, `"Binckhorst"`, `"A12"`): `voetgangers` en `verkeer` keer zoveel als het uur zegt, en `mensen` en `voertuigen` als extra gewichten. Een wijk die er niet in staat telt als 1. |
| `voertuig_basis` | hoe vaak elke voertuigsoort voorkomt voor uur en wijk erbij komen. |
| `mensen` | de soorten mensen (zie hieronder). |

Voertuigsoorten: `auto`, `fiets` (fietser, fatbike), `brommer` (brommer, scooter, motor),
`vracht` (busje, vrachtwagen, auto met aanhanger), `bus`, `landbouw` (trekker) en `klein`
(brommobiel).

Een **soort mens** (bv. `"forens"`):

| veld | wat |
|---|---|
| `jassen`, `broeken`, `schoenen`, `haarkleuren` | kleuren (`"#22242A"`) waaruit gekozen wordt; weggelaten = elke kleur |
| `kapsels` | gewichten van `kort`, `lang`, `kaal`, `pet`, `hoed` |
| `uniform` | vaste kleding (`coat`, `trim`, `trousers`, `cap`, `shoes`: kleuren), bv. van de politie |
| `rok` | kans op een rok (alleen bij lang haar), 0 tot 1 |
| `tempo` | hoe snel ze lopen, 1,0 = gewoon |
| `rolstoel`, `scootmobiel` | welk deel in een rolstoel of op een scootmobiel zit, 0 tot 1 |
| `dragen` | gewichten van `aktetas`, `handtas`, `schoudertas`, `rugzak`, `rolkoffer` en `""` (niets) |
| `pak` | `true`: in pak (donker colbert en broek) |

Een nieuwe soort mens: voeg hem toe onder `mensen` en geef hem een gewicht bij de `uren`
waarop hij buiten is (en eventueel bij een paar `gebieden`), en een persoon in
`gesprekken/voorbijgangers.json` met `"herkennen": {"soort": "<naam>"}` en zijn `namen`, zodat hij
praat als wat hij is. Iemand in dienst (`agent`, `handhaver`) praat uit `personeel.json`.
