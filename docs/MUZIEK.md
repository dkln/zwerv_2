# Muziek: de huisstijl van ZWERVR

Alle muziek van het spel is één huisstijl in de klank van de **Sega Mega Drive / Genesis**.
Elk stuk volgt de regels hieronder, zodat alles klinkt als dezelfde game. De huidige stijl is
**16-bit synthwave action-RPG** (profiel `synthwave_rpg`): heroïsch, opgewekt, triomfantelijk,
120 BPM, D mineur. De code staat in `tools/megadrive/`:

- `megadrive.py`: de "geluidschip" (FM, PSG, DAC-drums, overdrive, tape stop, mix en export)
- `stijlen/<naam>.py`: **het stijlprofiel**: tempo's, toonsoort en modus, akkoordschema's per
  sectie (als trapnamen: `i`, `VI`, `III`, `VII`, `V7`, ...), het motief, de instrumentpatches,
  het drumstel en per nummer zijn variaties (`PIECES`)
- `style.py`: de componeerhulpmiddelen op het actieve profiel (`ACTIVE_STYLE`, of de
  omgevingsvariabele `ZWERVR_MUZIEK_STIJL`)
- `stad_plan.py`: het gedeelde plan en de gedeelde thema's van de negen stadsloops
- één bestand per stuk (`stad_centrum.py`, `nachtstad_menu.py`, `gevecht.py`, ...); de
  deuntjes staan samen in `deuntjes.py`
- `check_music.py`: controle van wat er gerenderd is (lengte, luidheid, piek, lusnaad,
  niveau per 8 maten, gelijke lengte van de stadsloops)

## Renderen en controleren

```sh
tools/megadrive/render.sh                    # alles (ongeveer een halve minuut)
tools/megadrive/render.sh gevecht handelaar  # alleen deze stukken
tools/megadrive/render.sh deuntjes dood      # één deuntje: kaart_start, gewonnen, level_omhoog, nieuwe_missie, taak_klaar, verloren, dood
uv run --with numpy --with soundfile python3 tools/megadrive/check_music.py   # alles nakijken
ZWERVR_MUZIEK_SPOREN=1 tools/megadrive/render.sh gevecht   # ook de balans per spoor tonen
ZWERVR_MUZIEK_STIJL=<naam> tools/megadrive/render.sh       # met een ander profiel renderen
```

Draait Python via `uv` met numpy en soundfile; geen Godot nodig. De uitvoer gaat naar
`assets/audio/muziek/` als Ogg Vorbis, 44,1 kHz stereo. Een nieuw stuk: kopieer een bestaand
bestand, geef het een eigen bestandsnaam in `Song(...)` en zet de naam in de lijst `all` van
`render.sh`.

## Stijlprofielen: een andere muziekstijl proberen

Een stijl is een profiel in `tools/megadrive/stijlen/`. Een nieuwe stijl (bijvoorbeeld uit een
geplakte Suno/Udio/Gemini-beschrijving: de skill `/muziek-prompt` doet dit stap voor stap):

1. kopieer `stijlen/synthwave_rpg.py` naar `stijlen/<naam>.py` en pas aan: `TEMPOS`, `KEY`,
   `MODE`, de akkoordschema's (`CITY_SECTIONS`, `BATTLE_SECTIONS`, `MENU_SECTIONS`,
   `INTRO_SECTIONS`, `MERCHANT_CHORDS`, `LOADING_CHORDS`, `CHARACTER_CHORDS`), het motief
   (`MOTIF_RHYTHM`, `MOTIF_VARIANTS`), de patches (`PATCHES`), het drumstel (`DRUMS`) en
   `PIECES` (swing, energie, bas, gitaar per nummer);
2. zet `ACTIVE_STYLE` in `style.py` op de nieuwe naam;
3. pas waar nodig de nummers aan (de arrangementen en melodieën staan per nummer; ze zijn in
   trappen van de toonladder en akkoordtrappen geschreven, dus een andere toonsoort volgt vanzelf);
4. render, controleer, werk dit document bij.

De melodieën en arrangementen van de vorige huisstijl ("klassiek": funky house en new jack
swing, 104-150 BPM, F mineur rond Fm – Gb – Bbm, het motief F Ab G C) staan niet als profiel
terug: ze zaten in andere componeercode. Ze staan in de git-geschiedenis (`tools/megadrive/`
en `assets/audio/muziek/` in commit `e4c986db` en eerder).

## Originaliteit

De klank is geïnspireerd op 16-bit Mega Drive-muziek: action-RPG's en beat-'em-ups uit het begin
van de jaren negentig. Alleen de klankkleur en het genre zijn inspiratie. **Geen melodieën,
baslijnen of akkoordschema's uit bestaande nummers (uit games of daarbuiten) namaken.** Alles is
eigen compositie. Een akkoordreeks als i – VI – III – VII is gemeengoed; de melodieën niet.

## Klankpalet: de Mega Drive, en waar de grenzen zitten

Wat de chip kon, en hoe de stijl daarbinnen blijft:

- **YM2612 FM, zes kanalen**, waarvan het zesde de **DAC** is voor de drums: dus **vijf FM-stemmen**
  tegelijk. Vier operatoren per stem, een van de 8 algoritmes, feedback op operator 1, uitvoer
  afgerond op 9-bit DAC-stappen. Een akkoord is twee FM-stemmen (een tweeklank, `Chord.dyad`),
  of één stem met de operatoren op grondtoon, kwint en octaaf (de **powerchord**). Pad en koper
  wisselen elkaar af; de "muur van geluid" is een kwestie van afwisselen, niet van alles tegelijk.
- **SN76489 PSG**: drie blokgolven (alleen 50%: een "25%-pulse" bestaat op deze chip niet; de
  dunne chiptune-lead komt van een snel **driver-vibrato** dat per frame in de deler wordt
  geschreven), toonhoogte op de 10-bit deler (iets vals, zoals echt), volume in stappen van 2 dB,
  60 keer per seconde bijgewerkt; en de 16-bit LFSR-ruis voor hi-hats, open hats en bekkens.
- **DAC-drums**: korte samples, ~13-17,5 kHz, 8 bit: de strakke elektronische kick (`tight`),
  de vette kick (`FAT_KICK`, voor grote klappen), de **80s gated snare** (een felle klap met een
  dichte kamerstaart die het gate na 0,17 s hard afknipt), een gewone snare (ghost notes, rolls),
  clap, drie toms. Een metalen **FM-snare** ligt er licht overheen (op een FM-kanaal).

De patches in het profiel (`PATCHES`):

| Patch | Waarvoor |
|---|---|
| `lead` (`SYNTH_LEAD`) | **de signatuurstem**: het motief en de zingende thema's, vibrato na een korte wachttijd |
| `guitar` | de **elektrische gitaar**: FM met hoge feedback, door de overdrive (`drive`), bends (`~`), vibrato; met `twin=True` de tweede gitaar een terts lager |
| `power` | powerchords op één kanaal, hard aangezet (`anthem`, `push`, `hits`, `chug`, `held`) |
| `solid_bass` | de punchy, metalige FM-bas in zestienden met octaafsprongen (`solid`, `drive`, `syncopated`, ...) |
| `slap_bass` | de slapbas voor de lossere stukken (`slap`, `lyrical`, `walking`) |
| `brass_stab`, `brass` | FM-koperstoten op 2 en 4, koperpads |
| `pad` | het warme "analoge" pad (twee ontstemde dragers, trage aanzet) |
| `bell`, `chime` | FM-klokjes en de nostalgische lead-chime van de outro's |
| `pluck` | getokkeld (klavecimbel, folkgitaar, de luit van de markt) |
| `fm_snare`, `metal` | de metalen snare-laag, metaalklanken (industrie) |

**Panning en mix** (vast in `Song`, voor elk stuk gelijk): bas, lead en drums in het midden;
gitaar links (-0,4), de tweede gitaar en het echo-delay rechts (0,4), koper rechts (0,5), pad
links (-0,45), PSG 1/2/3 licht rechts, links, rechts, ruis licht rechts. Zachter dan de harde L/R
van het apparaat, voor koptelefoons. Lichte "Model 1"-kleur: low-pass rond 11 kHz, high-pass
op 25 Hz.

De rollen van de PSG: `psg_one` de chiptune-lead of de arpeggio, `psg_two` de echo (dezelfde
lijn drie zestienden later) en de tegenstem, `psg_three` het fonkelende tegen-arpeggio.

## Toonsoort en harmonie

- Alles in **D mineur** (`KEY`, `MODE` in het profiel).
- Het hart: **i – VI – III – VII: Dm – Bb – F – C**, het heroïsche, voortstuwende action-RPG-gevoel.
- Kleur: **iv (Gm)**, **V en V7 (A, A7)** met de C# van harmonisch mineur als weg terug,
  **VImaj7**, **VIIsus**, **Vsus**.
- Majeur voor winnen, level omhoog, de fanfare van de kaart (die landt op **D majeur**, `I`).

## Het motief

Vier noten in twee tellen, op het akkoord van zijn maat:

- ritme: **achtste, zestiende, zestiende, kwart**
- noten: **grondtoon, de kwint erboven, het octaaf, dan de toonladdertoon onder dat octaaf**:
  een sprong omhoog en een wending. Over Dm: **D5 A5 D6 C6**; over Bb: Bb4 F5 Bb5 A5; over F:
  F5 C6 F6 E6; over C: C5 G5 C6 Bb5; over A: A4 E5 A5 G5
- variant `M^` (stijgend): eindigt op de none boven het octaaf (D5 A5 D6 E6); variant `M!`
  (stoer): grondtoon, terts, kwint, grondtoon een octaaf lager
- speelt op de signatuurstem `lead` (of de gitaar, de klokjes, de PSG die hem echoot), en **komt in
  elk stuk duidelijk terug**: aan het begin van frases, in loops meerdere keren, in deuntjes als kern

In de melodietekst van een stuk: `M` het motief (8 zestienden), `M^`/`M!` de varianten,
`M+`/`M-` een octaaf hoger/lager; `R:2` `3:2` `5:2` `7:2` `8:2` `9:2` akkoordtrappen; `^1:4` ..
`^7:4` trappen van de toonladder (`'` octaaf hoger, `,` lager); `~` ervoor: een bend omhoog;
`-:4` een rust. Zie de docstring van `style.py`.

## Tempo's (`TEMPOS`)

| Soort stuk | Tempo |
|---|---|
| intro, menu, gevecht, stadsloops, handelaar, deuntjes | **120 BPM** (maat = 2,0 s) |
| laden | 100 BPM |
| karakterkeuze (zacht) | 96 BPM |

Alle stadsloops hebben **hetzelfde tempo, dezelfde lengte en dezelfde akkoorden per maat**
(`CITY_SECTIONS`, `stad_plan.py`), zodat het overvloeien bij een wijkwissel op dezelfde maat en
hetzelfde akkoord uitkomt. De handelaar heeft hetzelfde tempo, zodat hij soepel overvloeit.

## Groove en drums

- Four-on-the-floor met de gated snare op 2 en 4 (en claps in de hoogtepunten), hi-hats in
  zestienden, open hats op de achterslagen, **double-time hats** (een rammel van 32sten aan het
  eind van elke tel) voor de bouw en het duel.
- Gebroken (1, de "en" van 2, 3) en rock-kicks (1, 3, de "en" van 3) voor de rauwere stukken,
  half-time (1 en de "en" van 3) voor de rustige.
- Lichte swing (0,06-0,16) voor handelaar, laden, woonwijk, markt, centrum, dorp; recht voor de rest.
- Vullingen aan het eind van elke sectie: snare, toms (terug naar het begin van een loop), roll,
  drop; een bekken op elke sectieovergang.

## Vorm en lengtes

- Loops: **een geheel aantal maten**, **naadloos** (wat over het einde klinkt komt op het begin).
  Geen intro: meteen de groove. Secties met vullingen; de laatste maat leidt terug naar maat 1.
- Het gevecht volgt de vorm van de stijl: **A (verkenning) – B (gevechtshoogtepunt) – solo/duel –
  climax**; de intro: **intro – A – B – duel – systeemcrash (tape stop) – outro**.
- Deuntjes: geen lus, **4 s** (kaartdeuntje **6 s**, nieuwe missie **2,2 s**, taak klaar **2,8 s**),
  met een korte uitfade.
- De intro: precies op de tijden van `scripts/ui/intro.gd` (zie hieronder).

## Mixniveaus

- elk bestand eindigt op **-16 LUFS** (geïntegreerd, zie
  [Eén luidheid voor alle audio](#één-luidheid-voor-alle-audio)), pieken onder -1,5 dB
- `target_rms_db` van `render()` bepaalt alleen hoe hard de mix de begrenzer in gaat (de
  dichtheid), niet hoe luid het bestand is
- per spoor de vaste niveaus in `Song`; de stadsloops naar achteren gemengd
  (`CITY_BACKGROUND_GAINS`, `CITY_LOW_PASS_HZ` in het profiel)

## Alle stukken en waar ze spelen

| Bestand (`assets/audio/muziek/`) | Waar | Stuk |
|---|---|---|
| `zwervr_intro.ogg` | intro (`scripts/ui/intro.gd`) | 120 BPM, 60 maten, 120 s, geen lus: intro, verkenning, gevecht, duel, tape stop, outro |
| `nachtstad_menu_loop.ogg` | hoofdmenu (`main_menu.gd`) | het titelscherm: de motief-fanfare, powerchords, het grote thema met de twee gitaren, pads en klokjes; de kick gaat door; 32 maten, 64 s |
| `karakterkeuze_loop.ogg` | karakterscherm (`character_creation.gd`) | zacht: pad, klokjes op het motief, traag arpeggio, later een zachte chiptune-melodie; 96 BPM, 16 maten, 40 s |
| `laden_loop.ogg` | onder het laadscherm (`loading_screen.gd`) | rustig, half-time: zacht pulserende bas, pad, de chime op het motief, getokkelde akkoorden, later een melodie op de lead; 100 BPM, 16 maten, 38,4 s |
| `handelaar_loop.ogg` | in een winkel (de snackbars, `interiors.gd`) | ontspannen: slapbas, getokkelde akkoorden op de achterslagen, zacht koper, gebroken beat met claps, een vriendelijk wijsje op de chiptune-lead, de tweede keer op de lead met PSG-echo; 120 BPM, 16 maten, 32 s |
| `gevecht_loop.ogg` | in een gevecht | het volle battle theme: chiptune-verkenning, powerchords en zwevende lead, gitaar- en chiptune-duel, de twee gitaren in tertsen; 32 maten, 64 s |
| `stad_*_loop.ogg` | de stad, per wijk (hieronder) | 120 BPM, 48 maten, 96 s |
| `deuntje_kaart_start.ogg` | start van de kaart (`hud.gd`, `MAP_JINGLE`) | het motief als fanfare op Bb en C naar D majeur, met powerchords, 6 s |
| `deuntje_gewonnen.ogg` | een missie klaar | het motief snel omhoog, D majeur, korte groove met de twee gitaren, 4 s |
| `deuntje_level_omhoog.ogg` | genoeg XP voor een level | PSG-loopje omhoog, het motief in majeur met klokjes, 4 s |
| `deuntje_nieuwe_missie.ogg` | een nieuwe missie (`GameHud.show_mission`) | het motief op klokjes, koper en powerchord op Bb en C, een open D, 2,2 s |
| `deuntje_taak_klaar.ogg` | een stap van een missie klaar | snareroll, fanfare door D, G en A, een grote D majeur, 2,8 s |
| `deuntje_verloren.ogg` | verloren | het motief begint en zakt weg naar een lage D, 4 s |
| `deuntje_dood.ogg` | dood (`hud.gd`, `DEATH_JINGLE`) | lage klap, PSG-duik, het motief vertraagd een octaaf lager, de band stopt, 4 s |

### De stad per wijk

De HUD kiest de loop bij de wijk waar je bent (`CITY_MUSIC_BY_AREA` in `scripts/ui/hud.gd`) en
vloeit over bij een wijkwissel, op dezelfde plek in de maat. Andere wijken spelen
`stad_centrum_loop.ogg`. Alle negen spelen dezelfde familie van thema's (`stad_plan.THEMES`),
elk op zijn eigen manier:

| Loop | Wijken | Karakter |
|---|---|---|
| `stad_centrum_loop` | Centrum | levendige synthwave: solid bass, arpeggio, koperstoten, het stadsthema op de lead met echo, powerchords in B, de twee gitaren in C, het lyrische thema op de gitaar in D |
| `stad_torens_loop` | Centraal Station, De Resident, Beatrixkwartier, Prins Clauslaan | koel en glazig: bas op de achterslag, klokjes, fonkelende arpeggio's een octaaf hoger, de chiptune-lead, lange noten op de lead; geen gitaar |
| `stad_groen_loop` | Malieveld | rustig en ruim: half-time, lange bas, pad, klokjes op het motief, de chiptune zacht, de lead in B en C |
| `stad_woonwijk_loop` | Bezuidenhout, Bezuidenhout-Oost, Laak | rauw: gebroken kick, harde gated snare, slapbas, palm-muted chugs, riffs op het stoere motief, de gitaren in C en D |
| `stad_industrie_loop` | Binckhorst, A12 | hard en mechanisch: kick op elke tel, bas in zestienden, FM-metaal op de achterslagen, PSG-ostinato, het motief gehamerd, de twee gitaren in C |
| `stad_hofstad_loop` | Paleis Noordeinde, Lange Voorhout | statig, zonder beat: pad, een getokkeld klavecimbel-arpeggio, een klokje op de één, pauken bij de wendingen, de melodie op het koper |
| `stad_markt_loop` | Grote Markt, Schilderswijk | handtrommels in een darbuka-patroon ("dum" op de lage tom, "tek" op zachte claps), getokkelde akkoorden, lyrische bas, versierde lead met glijders |
| `stad_bos_loop` | Koekamp | het rustigst: geen drums, pad, lange bas, klokjes ver uit elkaar, PSG-vogeltjes, de lead alleen in A2 en C |
| `stad_dorp_loop` | Voorburg | folky: de akkoorden getokkeld als een gitaar, wandelende bas, zachte brushes vanaf B, een eenvoudig wijsje op de chiptune |

Het gedeelde plan (48 maten = 96 s): A (i VI III VII i VI III VII), A2 (i VI III VII iv VI
VIIsus VII), B (VI VII i i VI VII V V7), break (VImaj7 VImaj7 iv V), C (i VI III VII i VI VII V),
D (iv i VI III iv i V V7), tag (i VI VII V). Een nieuwe wijkloop gebruikt dit plan en verandert
alleen de bezetting, groove en melodieën.

### De intro

`scripts/ui/intro.gd` loopt op de muziek; de ankerpunten liggen vast (maat = 2,0 s): de intro
vanaf 0 (alleen het arpeggio, de bas na 4 s, het motief zacht op 6 s, het logo staat op 6,5 s),
de verkenning op maat 9 (**16,0 s**, `CRAWL_AT`), het gevechtshoogtepunt op maat 25 (**48,0 s**),
het duel op maat 41 (**80,0 s**), de systeemcrash op maat 53 (**104,0 s**: de band stopt over de
laatste tel, één harde klap, een PSG-duik) en de outro tot **120,0 s** (`END_AT`): kick en bas,
dan de bas alleen, de chime met zijn PSG-echo, een laatste akkoordstoot met bekken en de tape
stop. Verander je die tijden, pas dan `intro.gd` mee aan (`CRAWL_AT`, `CRAWL_CUES`, `END_AT`).

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



## Eén luidheid voor alle audio

Elk audiobestand van het spel (muziek, deuntjes, effecten, lussen, pijnkreten, kreten) staat op
dezelfde luidheid, gemeten zoals het oor hoort (K-weging van ITU-R BS.1770 / EBU R128, LUFS;
`tools/megadrive/loudness.py`, gebruikt door `style.py`, `geluiden.py` en `stemmen.py`):

- muziek, deuntjes en lussen (motoren, sirenes, helikopter): **geïntegreerd -16 LUFS**;
- eenmalige geluiden (effecten, pijnkreten, kreten): hun **luidste moment** (momentane luidheid,
  400 ms) op **-16 LUFS**; een korte klap is op zijn hardst zo luid als een lus gemiddeld;
- pieken zacht onder -1 dB (muziek -1,5 dB), alleen de pieken die erboven zouden komen.

Een getal in het spel is dus de echte verhouding: twee spelers op `volume_db` 0 klinken even hard.
Controleren: `ffmpeg -i bestand.ogg -af ebur128 -f null -` (I: voor lussen en muziek, de hoogste
M: voor eenmalige geluiden).

Hoe hard iets in het spel klinkt, bepaalt alleen het spel. In `scripts/audio/spatial_audio.gd`:
gebeurtenissen (aangereden worden, een botsing, een kreet, een plons) op `EVENT_DB` (+5,5 dB,
`play_event`), signalen van het verkeer (toeters, bellen, hoorns) op `SIGNAL_DB` (+2,5 dB,
`play_signal`), de achtergrond (voorbijrijden, remmen) op `BACKGROUND_DB` (-0,5 dB), de motoren
per voertuig in `MOTOR_VOLUME_DB`, de sirenes op `SIREN_VOLUME_DB`. De muziek: de `MUSIC_VOLUME_DB`
van intro, menu, laden en karakterkeuze, en in `hud.gd` de stad en de deuntjes.

Toen de bestanden gelijk werden getrokken (nov. 2026) zijn die getallen meeverschoven, zodat de
mix in het spel gelijk bleef aan hoe hij was afgesteld.

Een diepe stem en een heldere met veel s-klanken klinken zo even hard. Het "Sega-filter" van de stemmen
(`megadrive_voice`) snijdt de stem steil af onder de helft van de samplerate (11025 Hz) voor de
8-bit DAC, en filtert erna de spiegelbeelden van de trapjes weg (`RECONSTRUCTION_HZ`, 5 kHz):
die gaven elke s en elke medeklinker een metalig gefluit. De korrel van de 8 bits blijft. De
sis van de medeklinkers staat zachter dan de stem (`BREATH_GAIN`).
