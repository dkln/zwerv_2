# Geluiden: effecten en stemmen van ZWERVR

De geluidseffecten en stemmen van het spel, in Mega Drive-klank: gemaakt met de geluidschip
van `tools/megadrive/megadrive.py` (FM en PSG), door de "DAC" (22 kHz, 8 bits). Renderen met
`tools/megadrive/render.sh geluiden` of `tools/megadrive/render.sh stemmen`. De muziek staat hier
niet in: de muziekgeneratoren en de muzikale huisstijl zijn weggehaald (nov. 2026, opnieuw beginnen).

## Geluidseffecten van het verkeer en de hulpdiensten

Ook de verkeersgeluiden volgen de Mega Drive-klank: FM voor motoren (een draaggolf gebogen door
een modulator op de halve ontstekingsfrequentie, hard aangestuurd), metaal, klokken en de hoorn;
PSG-blokgolven voor de tweetaktrasp, de invertertoon van tram en trein, glasgerinkel en
remgepiep; ruis voor banden, lucht en kreukelend blik; en alles door de "DAC" (22 kHz, 8 bit).
Generator: `tools/megadrive/geluiden.py`; renderen met `tools/megadrive/render.sh geluiden`
(of enkele: `render.sh geluiden tram_bel bus_voorbij`). Uitvoer: `assets/audio/geluiden/`,
**mono** (zodat een `AudioStreamPlayer3D` ze in de wereld kan plaatsen), Ogg Vorbis 44,1 kHz.

| Bestand | Wat | Lengte |
|---|---|---|
| `auto_voorbij.ogg`, `brommer_voorbij.ogg`, `bus_voorbij.ogg`, `tram_voorbij.ogg`, `trein_voorbij.ogg` | het voertuig rijdt langs: aanzwellen, Doppler-daling (bewust overdreven, `DOPPLER_BOOST`), wegsterven; tram en trein met het klak-klak van de wielstellen over de railnaden, de tram met piepende flens | 3 / 3 / 4,5 / 6 / 7 s |
| `auto_motor_loop.ogg`, `brommer_motor_loop.ogg`, `bus_motor_loop.ogg`, `tram_motor_loop.ogg`, `trein_motor_loop.ogg` | naadloze lus van de motor op kruissnelheid, voor een `AudioStreamPlayer3D` op het voertuig (loop aan; `pitch_scale` kan de snelheid volgen; Godot doet afstand, panning en Doppler) | 2 s (trein 2,5 s) |
| `auto_botsing_hard.ogg` | zware botsing: klap, kreukelend blik, metalen FM-klanken, glasgerinkel, rondvallend puin | 1,8 s |
| `auto_botsing_licht.ogg` | lichte aanrijding: doffe klap, één metaalklank | 0,9 s |
| `tram_bel.ogg` | de trambel zoals van de GVB-trams in Amsterdam: de koepelgong, twee snelle slagen ("ding-ding") die naklinken; niet-harmonische boventonen van een geslagen koepel | 1,7 s |
| `trein_hoorn.ogg` | de hoorn van een NS Koploper (ICM): de twee tyfoons (660 en 370 Hz, de Europese treintonen), een korte hoge en een lange lage stoot; een zoemend membraan door de trompet, met het aanzwellen van de luchtdruk | 1,75 s |
| `bus_remmen.ogg` | stoppen: kort remgepiep, dan het sissen van de luchtrem | 1,6 s |
| `auto_toeter.ogg` | een auto waarschuwt een voetganger: twee korte stoten ("toet-toet") van een paar elektrische schijftoeters, een grote terts uit elkaar (410 en 512 Hz) | 0,75 s |
| `bus_toeter.ogg` | bus of vrachtwagen: één lange, lage stoot (277 en 349 Hz) | 1 s |
| `brommer_toeter.ogg` | het dunne toetertje van een brommer: twee korte PSG-piepjes ("piep-piep"), net iets vals | 0,55 s |
| `scootmobiel_toeter.ogg` | de zoemer van een scootmobiel: drie snelle hoge elektronische piepjes (2350 Hz) | 0,6 s |
| `kassa_piep.ogg` | de scanner van een supermarktkassa: één korte, hoge, droge piep (2637 Hz), hoger dan de OV-lezer | 0,22 s |
| `winkel_alarm.ogg` | de beveiligingspoortjes van een supermarkt die afgaan: zes paar snelle hoog-laag-piepen | 2 s |
| `lift_ding.ogg` | de lift van het stadhuis komt aan: "ding-dong", twee zachte belletonen een grote terts omlaag | 1,6 s |
| `lift_rijden_loop.ogg` | de lift die rijdt: het lage zoemen van de motor (55 Hz en boventonen), lucht in de schacht, zacht geratel van de kabels; naadloze lus | 2 s |
| `fiets_bel.ogg` | de duimbel van een fiets: twee koepeltjes (2650 en 2790 Hz), snel aangeslagen door de draaiende klepel, twee keer ("tring-tring") | 1,1 s |
| `politie_sirene_loop.ogg` | sirene van politie (ook de ME-bus): Nederlandse twee-toon 600/450 Hz, 0,55 s per toon, heldere PSG-blokgolven; naadloze lus, naast de motorlus op het voertuig | 2,2 s |
| `ambulance_sirene_loop.ogg` | sirene van de ambulance: twee-toon 660/495 Hz, 0,75 s per toon, rondere FM-hoorn; lus | 3 s |
| `brandweer_sirene_loop.ogg` | sirene van de brandweer: twee-toon 392/294 Hz, 0,8 s per toon, diep en grommend FM; lus | 3,2 s |
| `sirene_yelp_loop.ogg` | de snelle "yelp" voor kruispunten (elke hulpdienst); lus | 1 s |
| `politie_voorbij.ogg`, `ambulance_voorbij.ogg`, `brandweer_voorbij.ogg` | met sirene en brullende motor voorbijrazen, met Doppler-daling | 5 s |
| `brandweer_hoorn.ogg` | de luchthoorn van de brandweerauto, twee stoten | 1,6 s |
| `helikopter_loop.ogg` | de politiehelikopter die stilhangt: rotorslagen (13 per seconde), turbine, staartrotor; lus | 2 s |
| `helikopter_voorbij.ogg` | de helikopter die overvliegt, met Doppler | 8 s |

Niveaus: alles op -16 LUFS (zie hieronder), pieken onder -1 dB; het niveau in het spel zet je
met `volume_db`. De tram geldt ook voor de RandstadRail. De hulpdiensten hebben elk een eigen
toonhoogte, ritme en klankkleur, zodat je ze uit elkaar hoort; een nieuwe sirene volgt dat.

## Stemmen: pijnkreten

Op de Mega Drive waren de stemmen in beat-'em-ups opgenomen samples door de DAC: lage
samplefrequentie (8 tot 13 kHz), 8 bit, hard opgenomen en geclipt; korrelig, luid en wat nasaal.
Onze kreten zijn geen opnames (en geen kopieën van bestaande spellen) maar zo gemaakt als een
stem werkt: een stembandpuls op een dalende toonhoogte door vier formanten (de klinker: "ugh",
"ah"), met adem, een grom (periodeverdubbeling) voor de inspanning, hard aangestuurd, dan door
de "DAC" (sample-and-hold op 11 kHz, 8 bit, zonder anti-aliasfilter) en het uitgangsfilter van
de console (6 kHz). Generator: `tools/megadrive/stemmen.py`; renderen met
`tools/megadrive/render.sh stemmen` (of enkele: `render.sh stemmen pijn_vrouw_hard`).

| Bestand | Wat | Lengte |
|---|---|---|
| `pijn_<stem>_1.ogg` .. `pijn_<stem>_3.ogg` | korte kreten: "ugh!", "hngh!", "uah!" | 0,26 - 0,4 s |
| `pijn_<stem>_hard.ogg` | een lange kreet bij een zware klap: "aaargh" | 0,85 - 0,95 s |
| `pijn_<stem>_dood.ogg` | de dramatische kreet als de speler neergaat (zoals een KO in een vechtspel): hoog beginnend, lang wegzakkend van "aaaa" via "oh" naar "uh", een brede vibrato en een grote echo (`DEATH_ECHOES`); `PlayerController._die`, niet onder water | 2,2 - 2,4 s |
| `lichaam_klap.ogg` | de doffe klap van een lichaam dat geraakt wordt | 0,22 s |

Stemmen: `man` (Jos, Martin), `oude_man` (lager, rauwer, meer adem: Ufo Piloot, Willem, Gerrit),
`vrouw` (Sjaan), `rasperig` (alleen Blikken Bertus, `"stem"` in `data/gesprekken/personages.json`: laag en
schor, extra adem per lettergreep (`rasp`) en een kraak in de keel (`crackle`); `Babble.OWN_VOICES`,
nooit voor iemand anders); de stem van een speler staat als `"voice"` bij het personage in
`scripts/player/player_character.gd`. In het spel: `PlayerController.cry_out()` (bij
aangereden worden) speelt de klap en een kreet via `RuimtelijkGeluid.play_at()`, met de
echo van de straat.

Elk personage heeft ook een eigen **kreet** voor het karakterkeuzescherm, op dezelfde manier
gemaakt (`say()` in `stemmen.py`: stukjes klinker, toonhoogte, stem en adem; elk personage een
eigen spreker in `SPEAKERS`), in `assets/audio/kreten/kreet_<id>.ogg`:

| Personage | Kreet |
|---|---|
| Jos | "5 euro?", bedelend, vragend omhoog |
| Martin | "Al zijn ze paars!", de oud-topsporter, snel, oplopend naar "PAARS" |
| Ufo Piloot | "Derde Dal Universum", dromerig, golvend als een theremin (vibrato), de klemtoon hoog op "VER" |
| Willem | een hees lachje, "heh-heh-heh" |
| Sjaan | een vrolijk "Ff poetsen", de oude toiletjuffrouw, de klemtoon op "POE" |
| Gerrit | een diep, plagend "Scholluhkop!", Scheveens, de klemtoon op "SCHOL" |

`scripts/ui/character_creation.gd` speelt die als je een personage kiest (en de eerste kort
na het openen); een nieuwe kreet breekt de vorige af.

### In het spel: ruimtelijk geluid

`scripts/audio/spatial_audio.gd` (autoload `RuimtelijkGeluid`) speelt deze geluiden in 3D: bij
de dichtstbijzijnde voertuigen de motorlus (en de sirene), in 3D geplaatst met een
Dopplerverschuiving. Bewust eenvoudig: geen raycasts, geen demping achter gebouwen, geen echo
of galm; op de bus `Verkeer` alleen een compressor en een limiter tegen uitschieters. Een nieuw voertuiggeluid: zet het in `MOTOR_SOUNDS` (op de
`vehicle_kind`) of maak er een gebeurtenis bij in `_signals`; de muziek gaat niet door die bus.



## Eén luidheid voor alle audio

Elk audiobestand van het spel (muziek, deuntjes, effecten, lussen, pijnkreten, kreten) staat op
dezelfde luidheid, gemeten zoals het oor hoort (K-weging van ITU-R BS.1770 / EBU R128, LUFS;
`tools/megadrive/loudness.py`, gebruikt door `geluiden.py` en `stemmen.py`):

- muziek, deuntjes en lussen (motoren, sirenes, helikopter): **geïntegreerd -16 LUFS**;
- eenmalige geluiden (effecten, pijnkreten, kreten): hun **luidste moment** (momentane luidheid,
  400 ms) op **-16 LUFS**; een korte klap is op zijn hardst zo luid als een lus gemiddeld;
- pieken zacht onder -1 dB (muziek -1,5 dB), alleen de pieken die erboven zouden komen.

Een getal in het spel is dus de echte verhouding: twee spelers op `volume_db` 0 klinken even hard.
Controleren: `ffmpeg -i bestand.ogg -af ebur128 -f null -` (I: voor lussen en muziek, de hoogste
M: voor eenmalige geluiden).

Hoe hard iets in het spel klinkt, bepaalt alleen het spel.

### Eén mix (13 nov. 2026)

Alle niveaus staan op één schaal: hoe luid je het **hoort** (LUFS, op de Master-bus; eenmalige
geluiden op hun luidste moment). Gemeten in Godot zelf (een AudioEffectCapture op Master, headless),
want twee dingen wijken af van de bestanden:

- **mono op twee speakers is +3 dB.** Alle effecten, kreten en stemmen zijn mono, de muziek en de
  omgeving stereo. Een mono-geluid zonder plek (`AudioStreamPlayer`: menu, gebrabbel in gesprekken,
  deur) klinkt 3 dB harder dan het bestand meet; in 3D recht voor je klopt het wel.
- **de bus `Verkeer` heeft een compressor** (drempel -16 dB, 3:1; de oude -24 dB, 6:1 drukte een
  motor 15 dB weg, zodat motoren en sirenes verdronken onder toeters en klappen). De bus
  `Voorvallen` heeft alleen een limiter; beide staan op -3 dB.

| laag | gehoord | waar |
|---|---|---|
| intro-muziek | -18 | `intro.gd` MUSIC_VOLUME_DB -2 |
| menumuziek | -20 | `main_menu.gd` -4 |
| laden, karakterkeuze | -22 | `loading_screen.gd`, `character_creation.gd` -6 |
| muziek in de stad | -30 (pauze -32) | `hud.gd` CITY_MUSIC_VOLUME_DB -11, CITY_LOOP_SOFTER_DB 3 (rustiger arrangement: `derive.py` CITY_*) |
| muziek van een gebouw (handelaar) / muzak | -23 / -29 | `hud.gd` |
| deuntjes | -19 tot -21 (muziek 6 dB omlaag eronder) | `hud.gd` *_JINGLE_VOLUME_DB |
| klap, botsing, kreet, plons | -18 | `spatial_audio.gd` EVENT_DB +1 |
| gebrabbel in gesprek, kreet in karakterkeuze | -20, -19 | `babble.gd` UI_DB -7, SHOUT_VOLUME_DB -6 |
| toeter, bel, hoorn, geroep op straat | -20 | SIGNAL_DB -1 |
| sirene dichtbij | -22 | SIREN_VOLUME_DB -6 |
| voorbijrijden (luidste moment), remmen | -21 | BACKGROUND_DB -1,5 |
| menu- en automaatgeluiden | -22 | `ui_sounds.gd`, `machine_sounds.gd` VOLUME_DB -9 + LEVEL_TRIM_DB |
| deur | -21 | `interiors.gd` DOOR_SOUND_DB -8 |
| brand op een wrak | -22 | `vehicle_fire.gd` FIRE_SOUND_DB -3 |
| auto naast je (tram, trein iets meer) | -27 | MOTOR_VOLUME_DB |
| omgeving straat / winkel / station | -32 / -31 / -29 | `ambience.gd` |

Dus: wat jou overkomt boven alles, dan stemmen en signalen, dan de muziek van de stad op de hoogte
van het verkeer naast je, de omgeving eronder. De menu- en automaatgeluiden worden in code gemaakt
en staan niet op -16 LUFS; `LEVEL_TRIM_DB` trekt ze recht (eenmalig gemeten). Verander je een
golfvorm, meet dan opnieuw.

Een diepe stem en een heldere met veel s-klanken klinken zo even hard. Het "Sega-filter" van de stemmen
(`megadrive_voice`) snijdt de stem steil af onder de helft van de samplerate (11025 Hz) voor de
8-bit DAC, en filtert erna de spiegelbeelden van de trapjes weg (`RECONSTRUCTION_HZ`, 5 kHz):
die gaven elke s en elke medeklinker een metalig gefluit. De korrel van de 8 bits blijft. De
sis van de medeklinkers staat zachter dan de stem (`BREATH_GAIN`).

## Achtergrondgeluid van de plekken

Zacht onder alles klinkt het geroezemoes van waar je bent: buiten de straat, in Den Haag Centraal
de stationshal, in een winkel (de snackbar) een winkel. Het zijn opnames uit een vrije bron
(Wikimedia Commons, publiek domein of CC BY; zie `assets/audio/omgeving/BRONNEN.md`),
bewerkt tot naadloze lussen: een stuk eruit, het eind 3 s in het begin overgevloeid, op
-16 LUFS. Maken: `uv run --with numpy --with soundfile python3 tools/megadrive/omgeving.py`
(downloadt de opnames één keer; decoderen via ffmpeg). In het spel: `scripts/audio/ambience.gd`
(per plek een lus en een niveau, `PLACES`; bij een wissel 2 s overvloeien), aangestuurd door
`scripts/world/interiors/interiors.gd` (`AMBIENCE_OF`). Een plek erbij: een opname in `RECORDINGS` van
omgeving.py, een regel in `PLACES` en in `AMBIENCE_OF`.

Toonhoogte: elk geluidseffect klinkt elke keer een fractie anders (`scripts/audio/sound_variation.gd`:
tot 6% hoger of lager, de menugeluiden 3%, motoren en lussen krijgen bij het starten een eigen
toonhoogte binnen 5%). Muziek, de achtergrondgeluiden van een plek en het gebrabbel niet.
