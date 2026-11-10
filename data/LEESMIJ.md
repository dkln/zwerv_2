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
| `geld_verdiend` | `bedrag` | je zoveel geld gevonden of gekregen hebt |
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

- `vragen`: wat je kunt vragen (`kleingeld`, `snackbar`) en waarmee je afsluit (`dag`).
- `nog_iets`: wat ze erachter zeggen ("Nog iets?").
- `stemmingen`: de stemming per soort regel (`begroeting`, `onderwerp`, `doorvraag`,
  `kleingeld_ja`, `kleingeld_nee`, `snackbar`, `dag`). Stemmingen: `neutraal`, `blij`,
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
	"snackbar": "Op je kaart, kijk maar.",
	"dag": "Doei!",
	"gulheid": {"kans": 30, "bedrag": 0.1},
	"stemmingen": {"begroeting": "opgewonden"}
}
```

`herkennen` kan hebben: `vervoer` (`"rolstoel"`, `"scootmobiel"`), `haar` (`"kort"`,
`"lang"`, `"kaal"`, `"pet"`), `rok` (`true`/`false`), `jas` (een lijst kleuren, bv.
`["#22242A"]`). `gulheid`: de kans in 100 dat ze wat kleingeld geven, en hoeveel euro.

## De snackbarhouder — `gesprekken/snackbarhouder.json`

`begroetingen` (met `{snackbar}`: de naam van de zaak), `menu` (wat je kunt bestellen:
`item` uit `scripts/player/items.gd`, `vraag`, `prijs`, `naam`), `gekocht` (met `{wat}`),
`geen_geld` (met `{prijs}`), `zakken_vol`, `tip_vraag`, `tip`, `niets_vraag`, `dag`,
`nog_iets`, `stemmingen`.

## Drukte op straat — `drukte.json`

Hoe druk het is rond de speler en wie er rondloopt en -rijdt. Alles werkt met **gewichten**:
een groter getal komt vaker voor, `0` nooit; een soort die niet genoemd wordt telt als `1`
(bij `gebieden`) of als `0` (bij `uren`). Controle: `tests/run_unit_tests.gd -- crowd`.

| deel | wat |
|---|---|
| `uren` | momenten van de dag, op volgorde van `uur` (0 tot 24). Elk: `voetgangers` en `verkeer` (hoe druk: 1,0 = normaal, 0,1 = bijna niemand), `mensen` (welke soorten mensen er dan zijn) en `voertuigen` (welke voertuigsoorten). Tussen twee momenten loopt het geleidelijk over. |
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
| `kapsels` | gewichten van `kort`, `lang`, `kaal`, `pet` |
| `rok` | kans op een rok (alleen bij lang haar), 0 tot 1 |
| `tempo` | hoe snel ze lopen, 1,0 = gewoon |
| `rolstoel`, `scootmobiel` | welk deel in een rolstoel of op een scootmobiel zit, 0 tot 1 |
| `dragen` | gewichten van `aktetas`, `handtas`, `schoudertas`, `rugzak`, `rolkoffer` en `""` (niets) |
| `pak` | `true`: in pak (donker colbert en broek) |

Een nieuwe soort mens: voeg hem toe onder `mensen` en geef hem een gewicht bij de `uren`
waarop hij buiten is (en eventueel bij een paar `gebieden`). Let op: de gesprekken herkennen
een ambtenaar aan een jas `#22242A` of `#6A6E74` en een toerist aan `#C8B48A`.
