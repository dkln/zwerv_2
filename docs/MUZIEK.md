# Muziek: de huisstijl van ZWERVR

Alle muziek van het spel is één huisstijl. Elk nieuw stuk volgt de regels hieronder, zodat
alles klinkt als dezelfde game. De code staat in `tools/megadrive/`:

- `megadrive.py`: de "geluidschip" (FM, PSG, PCM-drums, mix en export)
- `style.py`: de huisstijl in code: instrumenten, drumstel, grooves, het motief, de mix
- `stad_plan.py`: het gedeelde plan van de vijf stadsloops
- één bestand per stuk (`stad_centrum.py`, `nachtstad_menu.py`, `gevecht.py`, ...);
  de vijf deuntjes staan samen in `deuntjes.py`

## Renderen

```sh
tools/megadrive/render.sh                    # alles (ongeveer 20 s)
tools/megadrive/render.sh gevecht handelaar  # alleen deze stukken
tools/megadrive/render.sh deuntjes dood      # één deuntje: kaart_start, gewonnen, level_omhoog, verloren, dood
```

Draait Python via `uv` met numpy en soundfile; geen Godot nodig. De uitvoer gaat naar
`assets/audio/muziek/` als Ogg Vorbis, 44,1 kHz stereo. Een nieuw stuk: kopieer een bestaand
bestand, geef het een eigen bestandsnaam in `Song(...)` en zet de naam in de lijst `all` van
`render.sh`.

## Originaliteit

De klank is geïnspireerd op 16-bit Sega Mega Drive / Genesis-muziek in de stijl van
beat-'em-up-soundtracks uit het begin van de jaren negentig (zoals Streets of Rage 2). Alleen
de klankkleur en het genre zijn inspiratie. **Geen melodieën, baslijnen of akkoordschema's
uit bestaande nummers (uit games of daarbuiten) namaken.** Alles is eigen compositie.

## Klankpalet: de Mega Drive

Drie soorten geluidsbron, zoals op het apparaat:

**YM2612 FM**: vier operatoren per stem, een van de 8 algoritmes, feedback op operator 1,
uitvoer afgerond op 9-bit DAC-stappen. De patches in `style.py`:

| Patch | Waarvoor |
|---|---|
| `LEAD` | **de signatuurstem**: elke uitspraak van het motief, en de melodieën. Vibrato na een korte wachttijd |
| `SLAP_BASS` | funky slapbas (stad, handelaar, karakterkeuze) |
| `SYNTH_BASS` | strakke, drijvende bas (menu, gevecht, intro, torens, industrie) |
| `ELECTRIC_PIANO` | FM-e-piano: akkoordstoten, rustige akkoorden |
| `BRASS` | koperpads (lange akkoorden) |
| `BRASS_STAB` | korte koperstoten, ook in het ritme van het motief |
| `STRINGS` | FM-strijkers: pads, breaks, intro en outro |
| `BELL` | FM-klokjes: glans (torens, groen, level omhoog) |

Een stuk mag een eigen patch toevoegen voor één kleur (bijvoorbeeld `METAL` in
`stad_industrie.py`), maar het motief speelt altijd op `LEAD`.

**SN76489 PSG**: blokgolven met de toonhoogte op de 10-bit deler (iets vals, zoals echt) en
het volume in stappen van 2 dB, 60 keer per seconde bijgewerkt. Twee kanalen:
`psg_one` voor arpeggio's en ostinato's, `psg_two` voor de echo (dezelfde lijn drie zestienden
later), de tegenstem en de terts eronder. PSG-ruis (16-bit LFSR) voor hi-hats, open hats en
bekkens.

**PCM-drums** via de DAC: kick (dik, 909-achtig), snare met ruis, clap, drie toms; ~17,5 kHz,
8 bit, voor die korrelige rand.

**Panning en mix** (vast in `Song`, voor elk stuk gelijk): bas, lead en drums in het midden;
piano links (-0,55), koper rechts (0,5), strijkers licht links, PSG 1 en 2 licht rechts en
links, ruis licht rechts. Zachter dan de harde L/R van het apparaat, voor koptelefoons. Lichte
"Model 1"-kleur: low-pass rond 11 kHz, high-pass op 25 Hz.

## Toonsoort en harmonie

- Alles in **F mineur**.
- Het hart is **i – bII – iv: Fm – Gb – Bbm**. De bII (Gb) geeft de donkere, stoere kleur.
- Kleurakkoorden: **Ab** en **Cm**, en **C7** als weg terug naar Fm. Verder mag Eb, Db/Gb maj7,
  Bbm9, Csus, Gm7b5 als doorgang.
- Energiek, niet triomfantelijk. Majeur alleen als uitzondering: winnen, level omhoog, de
  fanfare van de kaart (die eindigt op F majeur).

## Het motief

Vier korte, harde noten in twee tellen:

- ritme: **achtste, zestiende, zestiende, kwart**
- noten: **grondtoon, terts, de secunde boven de grondtoon, dan de kwint omlaag**
- over Fm: **F5 Ab5 G5 C5**; over Gb: Gb5 Bb5 Ab5 Db5; over Bbm: Bb5 Db6 C6 F5
- het past zich aan elk akkoord aan: de terts is groot of klein volgens het akkoord, de kwint
  omlaag is de kwint van het akkoord (bij m7b5 de verminderde kwint, en daar is de secunde een
  halve toon); grondtonen tussen D5 en C#6
- variant "stoer" (`M!`): eindigt op de kleine septiem eronder in plaats van de kwint (alleen
  op mineur)
- **speelt altijd op de signatuurstem `LEAD`** (de PSG mag het echoën of beantwoorden)
- **moet in elk stuk duidelijk en herkenbaar terugkomen**: liefst aan het begin van frases,
  in loops meerdere keren, in deuntjes als kern

In de melodietekst van een stuk is `M` het motief op het akkoord van die maat (8 zestienden),
`M!` de stoere variant, `M+`/`M-` een octaaf hoger/lager. Zie de docstring van `style.py`
voor de hele notatie (`F5:4`, `-:2`, `R:2`, `3:2`, `5:2`, ...).

## Tempo's

| Soort stuk | Tempo |
|---|---|
| intro, menu, handelaar, deuntjes | 128 BPM (maat = 1,875 s) |
| de stadsloops (achtergrondmuziek) | 104 BPM (maat = 2,31 s) |
| gevecht | 150 BPM |
| karakterkeuze (zacht) | 96 BPM |

Alle stadsloops hebben **hetzelfde tempo, dezelfde lengte en dezelfde akkoorden per maat**
(`stad_plan.py`), zodat het overvloeien bij een wijkwissel op dezelfde maat en hetzelfde
akkoord uitkomt.

## Groove en drums

- House: four-on-the-floor-kick, snare en/of clap op 2 en 4, hi-hats in zestienden met
  accent op de achterslag, open hats op de achterslagen voor de hoogtepunten.
- New jack swing: gebroken kick (1, de "en" van 2, 3), harde backbeat, swing 0,2-0,25.
- Lichte swing (0,1-0,15) voor de funky stukken, recht (0) voor menu, gevecht, torens en industrie.
- Ghost notes op de snare, extra kick op de laatste achtste van de maat voor duw.
- Vullingen aan het eind van elke sectie: snare (laatste tel), toms (terug naar het begin van
  een loop), roll (16en die aanzwellen uit een break), drop (stilte op de laatste tel).
- Breaks zonder kick; rustige stukken (groen, karakterkeuze) met minder drums.

## Vorm en lengtes

- Loops: **een geheel aantal maten**, 30-90 s, **naadloos**: wat over het einde klinkt komt op
  het begin; geen klik op het lusmoment. Geen intro: meteen de groove. Afwisseling met
  secties (A, A', B, break, C, tag) en vullingen; een tomfill in de laatste maat leidt terug
  naar maat 1.
- Deuntjes: geen lus, **4 s** (kaartdeuntje **6 s**), eindigen met een korte uitfade.
- De intro: precies op de tijden van `scripts/ui/intro.gd` (zie hieronder).

## Mixniveaus

- gemiddeld (RMS) **-14 dB**; zachte stukken -15,5 tot -16 dB (groen, karakterkeuze),
  droevige deuntjes -15 dB
- piek rond **-1 dB** (de master begrenst op -1,5 dB vóór Vorbis), nooit clippend
- per spoor de vaste niveaus in `Song`; de master stelt het gemiddelde in en begrenst zacht

## Alle stukken en waar ze spelen

| Bestand (`assets/audio/muziek/`) | Waar | Stuk |
|---|---|---|
| `zwervr_intro.ogg` | intro (`scripts/ui/intro.gd`) | 128 BPM, 64 maten, 120 s, geen lus |
| `nachtstad_menu_loop.ogg` | hoofdmenu (`main_menu.gd`) | energiek en recht, 48 maten, 90 s |
| `karakterkeuze_loop.ogg` | karakterscherm (`character_creation.gd`) | zacht, 96 BPM, 16 maten, 40 s |
| `deuntje_kaart_start.ogg` | start van de kaart, voor de stadsmuziek (`hud.gd`, `MAP_JINGLE`) | het motief als fanfare op Db en Eb naar F majeur, 6 s |
| `stad_centrum_loop.ogg` | de stad: oude binnenstad | funky, levendig, 92 s |
| `stad_torens_loop.ogg` | de stad: kantoortorens | koel, glanzend, 92 s |
| `stad_groen_loop.ogg` | de stad: parken | rustig, ruimtelijk, 92 s |
| `stad_woonwijk_loop.ogg` | de stad: woonwijken | rauw, straat, new jack swing, 92 s |
| `stad_industrie_loop.ogg` | de stad: industrie en snelweg | hard, mechanisch, techno, 92 s |
| `stad_hofstad_loop.ogg` | de stad: hofkwartier | statig, strijkers en klavecimbel, 92 s |
| `stad_markt_loop.ogg` | de stad: markten | handtrommels, getokkelde lijn, 92 s |
| `stad_bos_loop.ogg` | de stad: bos | het rustigst, geen drums, vogels, 92 s |
| `stad_dorp_loop.ogg` | de stad: dorp | folky, getokkeld, zachte brushes, 92 s |
| `gevecht_loop.ogg` | zolang je in een gevecht bent (nog te koppelen) | 150 BPM, 32 maten, 51,2 s: de stoere variant van het motief op lead en koper, galopperende kick |
| `laden_loop.ogg` | wachtmuziek onder het laadscherm (`scripts/ui/loading_screen.gd`), in en uit fadend | licht en huppelend: e-piano op de tegentijd, een tikkende PSG-klok, zachte gebroken beat, een vrolijk wijsje op het motief; 112 BPM, F mineur, 16 maten, 34 s |
| `handelaar_loop.ogg` | zolang je in een winkel bent, bij een handelaar (nog te koppelen) | relaxte new jack swing, 128 BPM in F mineur, 16 maten, 30 s (de stadsloops zijn nu 104 BPM: zet hem bij het koppelen op hun tempo, dan vloeit hij soepel over) |
| `deuntje_gewonnen.ogg` | gewonnen | het motief snel omhoog, F majeur, 4 s |
| `deuntje_level_omhoog.ogg` | genoeg XP voor een level | PSG-loopje omhoog, het motief in majeur met klokjes, 4 s |
| `deuntje_verloren.ogg` | verloren | het motief begint en zakt weg naar een lage F, 4 s |
| `deuntje_dood.ogg` | dood (`hud.gd`, `DEATH_JINGLE`) | lage klap, PSG-duik, het motief vertraagd een octaaf lager, 4 s |

### De stad per wijk

De HUD kiest de loop bij de wijk waar je bent (`CITY_MUSIC_BY_AREA` in `scripts/ui/hud.gd`;
de wijknamen uit de "wijken"-metadata) en vloeit over bij een wijkwissel, op dezelfde plek in
de maat en met gelijk vermogen (geen gat halverwege), pas na 1,5 s in de nieuwe wijk. Andere wijken spelen `stad_centrum_loop.ogg`.

| Loop | Wijken | Karakter |
|---|---|---|
| `stad_centrum_loop` | Centrum | funky house met lichte shuffle, slapbas, e-piano, koper, PSG-echo |
| `stad_torens_loop` | Centraal Station, De Resident, Beatrixkwartier, Prins Clauslaan | rechte deep house, bas op de achterslag, piano-offbeats, klokjes, glinsterende arpeggio's, lange koele lead |
| `stad_groen_loop` | Malieveld | half-time gevoel, strijkers, klokjes, lange bas, nauwelijks drums, het motief zacht met ruimte |
| `stad_woonwijk_loop` | Bezuidenhout, Bezuidenhout-Oost, Laak | zware new-jack-swing-shuffle, gebroken kick, slapbas, korte riffs op het stoere motief |
| `stad_industrie_loop` | Binckhorst, A12 | techno: kick op elke tel, bas in zestienden, PSG-ostinato, metalen FM-klanken, het motief gehamerd |
| `stad_hofstad_loop` | Paleis Noordeinde, Lange Voorhout | statig zonder beat: strijkers, een klavecimbelachtige PSG-arpeggio op en neer, klokjes op de één, pauken bij de wendingen, een nobele lead; koperpad in C |
| `stad_markt_loop` | Grote Markt, Schilderswijk (de Haagse Markt) | handtrommels in een darbuka-patroon ("dum" op de toms, "tek" op zachte claps), een getokkelde PSG-lijn op het motief, lyrische bas, versierde lead met glijders; de C7 geeft de E van F harmonisch mineur |
| `stad_bos_loop` | Koekamp (het hertenkamp bij het Haagse Bos) | het rustigst: geen drums, zachte strijkers, lange bas, klokjes ver uit elkaar, PSG-vogeltjes af en toe, de lead alleen in A' en C |
| `stad_dorp_loop` | Voorburg | folky: de PSG tokkelt de akkoorden als een gitaar, spaarzame e-piano, zachte brushes vanaf B, een eenvoudig wijsje op het motief |

Het zijn achtergrondmuziekjes om bij rond te lopen: rustig (104 BPM) en naar achteren gemengd
(`stad_plan.finish`: drums, lead, hats en koper zachter dan in de andere stukken, de top wat
afgerond, iets zachter in totaal), en in het spel op -22 dB.

Het gedeelde plan (40 maten = 92 s, 104 BPM): A (Fm7 Gbmaj7 Bbm7 Fm7 Fm7 Gbmaj7 Ab6 C7),
A' (idem), B (Bbm9 Bbm9 Gbmaj7 Gbmaj7 Abmaj7 Eb6 Csus C7), break (Gbmaj7 Gbmaj7 Bbm7 C7),
C (Gbmaj7 Ab6 Fm7 Fm7 Gbmaj7 Ab6 Gm7b5 C7), tag (Fm7 Gbmaj7 Bbm7 C7). Een nieuwe wijkloop
gebruikt dit plan en verandert alleen de bezetting, groove en melodieën.

### De intro

`scripts/ui/intro.gd` loopt op de muziek; de ankerpunten liggen vast (maat = 1,875 s):
zwelling vanaf 0 (het logo fadet in van 5 tot 6,5 s, het motief zacht op maat 5 = 7,5 s), de
jacht op maat 9 (15,0 s, `CRAWL_AT`), de klim op maat 25 (45,0 s), het refrein op maat 33
(60,0 s) en de tweede helft op maat 41 (75,0 s), het duel op maat 49 (90,0 s), de systeemcrash
op maat 57 (105,0 s: één harde klap, PSG-duik, daarna geen drums) en het uitsterven tot 120,0 s
(`END_AT`). Verander je die tijden, pas dan `intro.gd` mee aan (`CRAWL_AT`, `CRAWL_CUES`, `END_AT`).

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
| `politie_sirene_loop.ogg` | sirene van politie (ook de ME-bus): Nederlandse twee-toon 600/450 Hz, 0,55 s per toon, heldere PSG-blokgolven; naadloze lus, naast de motorlus op het voertuig | 2,2 s |
| `ambulance_sirene_loop.ogg` | sirene van de ambulance: twee-toon 660/495 Hz, 0,75 s per toon, rondere FM-hoorn; lus | 3 s |
| `brandweer_sirene_loop.ogg` | sirene van de brandweer: twee-toon 392/294 Hz, 0,8 s per toon, diep en grommend FM; lus | 3,2 s |
| `sirene_yelp_loop.ogg` | de snelle "yelp" voor kruispunten (elke hulpdienst); lus | 1 s |
| `politie_voorbij.ogg`, `ambulance_voorbij.ogg`, `brandweer_voorbij.ogg` | met sirene en brullende motor voorbijrazen, met Doppler-daling | 5 s |
| `brandweer_hoorn.ogg` | de luchthoorn van de brandweerauto, twee stoten | 1,6 s |
| `helikopter_loop.ogg` | de politiehelikopter die stilhangt: rotorslagen (13 per seconde), turbine, staartrotor; lus | 2 s |
| `helikopter_voorbij.ogg` | de helikopter die overvliegt, met Doppler | 8 s |

Niveaus: losse geluiden piek -1 dB, motorlussen gemiddeld -16 dB; het niveau in het spel zet je
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
| `pijn_<stem>_hard.ogg` | een lange kreet bij een zware klap of de dood: "aaargh" | 0,85 - 0,95 s |
| `lichaam_klap.ogg` | de doffe klap van een lichaam dat geraakt wordt | 0,22 s |

Stemmen: `man` (Jos, Martin), `oude_man` (lager, rauwer, meer adem: Ufo Piloot, Willem, Gerrit),
`vrouw` (Sjaan); de stem staat als `"voice"` bij het personage in
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

