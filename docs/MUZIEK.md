# Muziek: de huisstijl van ZWERVR

Alle muziek van het spel komt uit de **basissoundtracks**: composities die een componist (nu:
Gemini) maat voor maat uitschrijft. Elke basis staat op een eigen plek in
`tools/muziek/composities/actief.py`:

| plek | in `actief.py` | wordt letterlijk | wordt ervan afgeleid |
| --- | --- | --- | --- |
| **primair** (intro) | `ACTIEF` | de **intro** (`zwervr_intro.ogg`) | de andere deuntjes en liedjes: handelaar, de kaart, missie- en taakdeuntjes, gewonnen, dood, de supermarkten en hun jingles |
| **secundair** (menu) | `MENU` | het **hoofdmenu** (`nachtstad_menu_loop.ogg`, als lus) | de karakterkeuze, het laadscherm, de stad (`spel_loop`), de beloning en level omhoog (`derive.SECONDARY_PIECES`) |
| **tertiair** (vechtscène) | `GEVECHT` | de **vechtscène** (`gevecht.ogg`: het hele nummer, één bestand) | niets |

Een basis die letterlijk klinkt is de partituur zoals geschreven, in de eigen synth van de bron (een
tracker of haar eigen FM-patches). Een afgeleid stuk gebruikt dezelfde akkoorden, melodieën, klanken en drums,
anders gearrangeerd. Alle deuntjes en liedjes zijn dus op de primaire of de secundaire gebaseerd.
Zo klinkt het spel als één soundtrack met een eigen kleur voor de menu's. Komt er een nieuwe
compositie, dan zeg je voor welke plek; die plek wordt vervangen en alle muziek opnieuw gemaakt.
Zonder `MENU` komt ook het menu uit de primaire (`menu_loop`: afgeleid).

Alles klinkt als een **Sega Mega Drive**-cartridge: YM2612-FM, SN76489-PSG en PCM-drums door de
8-bit DAC (de geluidschip `tools/megadrive/megadrive.py`, dezelfde als die van de
geluidseffecten, `docs/GELUIDEN.md`). Noemt een compositie moderne instrumenten (een zaagtand-pad,
een distortion-gitaar), dan worden dat FM-klanken die op de chip passen.

Een nieuwe compositie aanleveren: het liefst als JSON, zie `docs/MUZIEK_JSON.md`
(`tools/muziek/render.sh --json`); de intro is dan de partituur gespeeld door de nagebouwde synth van
de tracker van de componist (`tools/muziek/tracker.py`, `json_bron.py`), de afgeleide stukken gebruiken
die stemmen.

## Een nieuwe compositie aanleveren

1. Zet de tekst van de componist in **`tools/muziek/composition.md`** (de vorige eruit) en vraag
   om er de muziek van te maken; de skill **`/muziek-compositie`** doet de stappen hieronder.
2. De tekst wordt ook bewaard als `tools/muziek/composities/<naam>.txt` (het origineel, niets
   veranderd, zodat het blijft als `composition.md` later een andere is) en overgezet in `tools/muziek/composities/<naam>.py` (de notatie hieronder).
3. `tools/muziek/composities/actief.py`: op de plek waar hij voor is: `ACTIEF = "<naam>"`
   (primair, de intro), `MENU = "<naam>"` (secundair, het menu) of `GEVECHT = "<naam>"`
   (tertiair, de vechtscène).
4. `tools/muziek/render.sh` maakt alles in `assets/audio/muziek/` en schrijft
   `scripts/ui/intro_timing.gd`; `tools/muziek/render.sh --controle` kijkt alles na.


Oude composities blijven staan; terug naar een eerdere is de plek in `actief.py` terugzetten en
opnieuw renderen. Eerst luisteren zonder iets te vervangen: `tools/muziek/render.sh --uit <map>`, of
met een andere compositie op een plek: `ZWERVR_COMPOSITIE=<naam>` (primair),
`ZWERVR_MENU_COMPOSITIE=<naam>` (secundair), `ZWERVR_GEVECHT_COMPOSITIE=<naam>` (tertiair) voor
`tools/muziek/render.sh --uit <map>`.

## De nabootsing van de chips (`chip.py`)

De FM-patches die een compositie zelf meegeeft (de tijdlijn-vorm, `docs/MUZIEK_JSON.md`: de
klanken `patch:<bestand>:<kanaal>`) klinken door een nabootsing van de YM2612, uit de waarden van
hun registers,

op de eigen samplefrequentie van de chip (klok / 144, 53267 Hz), daarna
naar 44100 Hz:

- **YM2612**: zes kanalen van vier operatoren in de acht algoritmen; de feedback van operator 1
  (sample voor sample); per operator de verhouding (MUL), de detune (DT), het niveau (TL) en de
  envelope (attack, decay tot het sustain-niveau, sustain-rate, release, met key scaling);
  key-on en key-off per operator (key-on zet de fase op nul); de **frequentie exact** uit
  F-number en blok (F-number 2047 in blok 1 is 103,98 Hz, geen G#); de speciale modus van kanaal 3
  (een frequentie per operator); de panning links/rechts; de DAC op kanaal 6; per kanaal de
  begrenzing en de 9 bits van de uitgang.
- **SN76489**: drie blokgolven (periode naar frequentie), de ruis (wit of periodiek, het
  schuifregister van Sega, op de drie vaste snelheden of die van toon 3; schrijven naar het
  ruisregister zet het terug), zestien volumes van 2 dB.

**Benaderd, niet cyclus-exact**: de envelopes zijn als krommen uitgerekend (dezelfde tijden en
niveaus als de tellers van de chip, zonder hun trapjes); de sinus en de niveaus komen niet uit
de 10-bit-tabellen van de chip; de verhouding PSG tegen FM is de gebruikelijke emulatorinstelling
(`PSG_LEVEL`: een PSG-kanaal op vol volume half zo hard als een FM-kanaal), niet aan een console
gemeten; het "ladder-effect" van de DAC ontbreekt. **Niet nagebootst**: de LFO (vibrato en
tremolo), SSG-EG en de CSM-modus; vraagt een bestand erom (vibrato), dan meldt de lezer dat.

## De regels

- **Letterlijk.** De intro is de compositie zoals ze geschreven is: elke noot, elk akkoord,
  elke tel, het tempo en de maatsoort. Geen eigen variaties, geen noten "verbeterd", de
  chromatiek van de componist blijft (de controle meldt ze, ter controle, als buiten de toonsoort).
- **Bijstellen mag, apart.** Wil de gebruiker de muziek anders (blijer, sneller, ...), dan
  blijven de overgezette maten letterlijk en komt de wens in `BIJSTELLING` in het
  compositiebestand: een laag die er bij het maken overheen gaat (zie hieronder), met de reden
  erbij. Terugdraaien is die regel weghalen.
- **Gaten vullen uit de tekst zelf.** Schrijft de tekst een partij niet uit waar ze wel speelt
  (bijvoorbeeld: "de arpeggiator speelt onafgebroken" maar het refrein noemt geen arp), dan komt
  het figuur uit de beschrijving van dat instrument of die sectie in dezelfde tekst, en staat in
  het compositiebestand bij die maat waarom ("afgeleid: ..."). Niets uit een vorige compositie.
- **Afgeleid, niet nieuw.** De andere stukken gebruiken alleen materiaal van de compositie: haar
  maten, melodieën, akkoorden en klanken. Wat er bij mag: een pad of een baslijn gespeld uit haar
  akkoorden, een andere klank voor haar melodie, een ander drumpatroon met haar drums.
- **De spel-lus is achtergrond.** Hij speelt lang onder het spelen door, dus hij voelt rustig
  (half-time: kick op 1, clap op 3, aangehouden akkoorden, een trage bas), in de klank van de
  handelaar (elektrische piano), met afwisseling tussen de secties en hun invulling zoals de
  handelaarslus, zonder gitaar, felle lead, crashes, doorlopende arpeggio of shuffle; de melodie
  af en toe. In het spel staat hij zachter dan de andere muziek (`CITY_LOOP_SOFTER_DB` in
  `hud.gd`, 3 dB), zodat hij de geluiden van de stad niet overstemt. De energie zit in de intro,
  het menu en de deuntjes.
- **Mega Drive-grenzen.** FM-klanken (4 operatoren, de 8 algoritmen, feedback), PSG-blokgolven
  met de stappen van de chip, drums als 8-bit samples. Het aantal stemmen tegelijk is niet
  beperkt.
- **Eén luidheid.** Elk stuk staat op -16 LUFS geïntegreerd, pieken onder -1,5 dB
  (`tools/megadrive/loudness.py`; hoe hard het in het spel klinkt, bepaalt het spel).
- **Lussen zonder naad.** Een lus is precies een geheel aantal maten lang; wat over het einde
  doorklinkt, komt aan het begin terug, zodat de lus naadloos doorloopt.

## Het compositiebestand

`tools/muziek/composities/<naam>.py` (Nederlandse namen, de helpers uit `tools/muziek/notation.py`):

```python
from notation import cycle, drum_run, drums, notes, run

TITEL = "Blast Processing Overdrive"
TEMPO = 136                      # BPM (zoals geschreven; BIJSTELLING kan het veranderen)
TELLEN_PER_MAAT = 4
TOONSOORT = ("D", "mineur")
KLANKEN = {"bas": "fm_slapbas", "lead": "fm_lead_helder", "arp": "psg_arp", ...}
MOMENTEN = {"logo": 5, "verhaal": 9, "hoogtepunt": 17, "duel": 25, "crash": 29}
SECTIES = [{"naam": "Thema A", "soort": "thema", "maten": (5, 12), "standaard": {"drums": ...}}, ...]
MATEN = {
    5: {"akkoord": "Dm",
        "bas": cycle("D2 D2 D3 D2", 0.25),                       # per tel in zestienden
        "lead": notes("1.0 D5 0.75, 1.75 F5 0.75, 2.5 A5 1.0"),  # tel, noot, lengte in tellen
        "drums": drums(kick="1 2.5 3", snare="2 4", hihat="16-off", open="off", crash="1")},
}
```

- **Tellen** vanaf 1.0 zoals de tekst ("tel 2.5" is de "en" van tel 2), **lengtes** in tellen,
  **noten** met octaafgetal (C4 de centrale C), een akkoord met `+` ("D3+A3+D4").
- `notes()` een regel noten; `cycle()` een figuur herhaald door (een deel van) de maat;
  `run()` een figuur één keer; `drums()` slagen per drum; `drum_run()` een fill.
- **Partijen** hebben vrije namen; elke partij staat in `KLANKEN` met haar klank. `drums` is
  altijd het drumstel (kick, snare, hihat, open, crash, clap, tom_hoog, tom_mid, tom_laag).
- **Akkoord** per maat (twee akkoorden in een maat: de helften, "Bb A7"); de afgeleide stukken
  spellen er pads en baslijnen uit.
- **SECTIES** met een `soort`: intro, thema, opbouw, refrein, breakdown, finale. De afgeleide
  stukken zoeken die op; `standaard` geeft de partijen die elke maat van de sectie heeft (een
  maat die zelf iets zegt, wint; `[]` is stilte).
- **MOMENTEN**: de maat waarop de beelden van de intro wisselen (scripts/ui/intro.gd): het logo
  (`logo`, de eerste grote inzet), het verhaal begint te rollen (`verhaal`), drie alinea's
  vallen op `hoogtepunt`, `duel` en `crash` (welke alinea's: `CRAWL_CUES` in intro.gd, zo gekozen
  dat het verhaal gelijkmatig rolt), en de laatste zin komt tot rust op `rust`, een (maat, tel):
  de eindklap. Daarna klinkt de muziek nog een seconde uit (`RING_OUT` in build.py), dan het menu.

### BIJSTELLING

```python
BIJSTELLING = {
    "tempo": 144,                                   # BPM in plaats van TEMPO
    "klank": {"lead": "psg_lead_fel"},              # een partij in een andere klank (dezelfde noten)
    "verdubbel": {"lead": "overdrive_gitaar_solo"}, # dezelfde noten ook in een tweede klank ("lead_dubbel")
    "drumstel": "dmx",                              # een ander drumstel (instruments.DRUM_KITS)
    "octaaf": {"arp": 1},                           # een partij octaven hoger (+) of lager (-)
    "kick_op_elke_tel": ("thema", "refrein", "finale"),   # four on the floor
    "open_hihat": ("intro", "thema", "opbouw", "refrein", "finale"),  # op de off-beats
    "handklap": ("thema", "refrein", "finale"),     # een clap bij de snare op 2 en 4
    "stoten": {"secties": ("thema", "refrein"), "klank": "fm_piano"},  # akkoordstoten op de off-beats
    "majeur_slot": True,                            # slotakkoord en landingen van de deuntjes in majeur
}
```

De drum-bijstellingen gelden alleen in maten met een groove (kick en snare) en laten fills,
breaks (kick en snare samen op dezelfde plekken: een unisono-figuur) en de slotmaat (de
eindklappen) met rust; de stoten zijn uit de akkoorden gespeld; `majeur_slot`
geeft het slotakkoord de grote terts (en de landing van nieuwe missie, taak klaar en level
omhoog); het deuntje van de dood blijft mineur. Nu ingesteld voor "Mega-Volt Overdrive: Turbo
Edition": de melodie op `fm_housebas_lead` (de klank van de bas in de eerste maat van de menulus,
die de gebruiker goed vond; daarvoor `psg_lead_arp`; daarvoor `fm_lead_zuur`, "niet chemisch genoeg, mag rauwer"; daarvoor `fm_lead_snerpend`, en eerst `psg_lead_fel`: "meer chiptune-achtig"; daarna "het
geluid van de lead in Streets of Rage 2, Go Straight": alleen die klankkleur), verdubbeld op
`overdrive_gitaar_solo` ("zwaarder, meer gitaar-achtig"). Eerder, voor "Blast Processing Overdrive":
"ietsje blijer, meer upbeat", in de geest van de stage 1-muziek van Streets of Rage 2 (een
house-groove: kick op elke tel, open hi-hats op de off-beats, handklappen, pianostoten, rond
140 BPM); alleen die kenmerken, geen noten van dat nummer.

## De klanken

In `tools/muziek/instruments.py` (`SOUNDS`), elk met plek in het stereobeeld, niveau, breedte
(twee iets ontstemde kopieën links en rechts) en echo (een delay in tellen):

| klank | wat | waarvoor |
| --- | --- | --- |
| `fm_slapbas` | metalige 4-op FM-bas, snelle percussieve modulator | de pompende octaafbas |
| `fm_subbas` | diepe, zachte FM-bas | lange subnoten, de rustige stukken |
| `fm_housebas` | "gritty" house/techno-FM-bas: feedback-paar met snelle grom, sub-octaaf | een clubbas |
| `fm_housebas_lead` | de FM-stem van `fm_housebas` als melodie: de grom op elke noot, de sub een octaaf eronder, echo | een rauwe, "chemische" melodie |
| `fm_stoot_metaal` | metalige, percussieve FM-stoten (modulators op 3,5x en 7x, korte decay) | akkoordstoten |
| `synthwave_pad` | FM-zaagtand (feedback), traag, breed | akkoordvlakken |
| `synth_brass` | FM-koper, breed | akkoordstoten |
| `fm_lead_helder` | heldere FM-lead, vibrato 6 Hz, gepuncteerde-achtste echo | de hoofdmelodie |
| `fm_lead_snerpend` | snerpende, nasale FM-lead (feedback-paar plus modulator op 3x), felle aanslag, vibrato na de inzet, echo | een melodie in de geest van de vroege-jaren-90 arcade-leads |
| `psg_lead_arp` | de blokgolf van `psg_arp` (snelle aanslag, valt meteen terug) als melodie, met echo | een rauwe chiptune-melodie |
| `fm_lead_zuur` | rauwe acid-achtige FM-lead: feedback bijna maximaal, per noot snel wegvallende modulator (het knijpen), schurende tweede drager, nauwelijks vibrato | een "chemische" techno-melodie |
| `psg_arp` | PSG-blokgolf, kort | arpeggio's in zestienden |
| `psg_lead` | PSG-blokgolf met vibrato en echo | de melodie in rustiger stukken |
| `psg_lead_fel` | PSG-blokgolf, fel en vol aangehouden, snelle vibrato, echo | een melodie als chiptune |
| `overdrive_gitaar` | FM-snaren samen overstuurd, donkere kast | powerchords |
| `overdrive_gitaar_solo` | idem, harder gedreven, echo | riffs en solo's |
| `clean_gitaar` | FM-snaren zonder oversturing, korte plectrum-aanslag, warme body | cleane powerchords en chugs |
| `clean_gitaar_solo` | idem, met echo | cleane gitaarloopjes en solo's |
| `fm_klok` | FM-klok, lange echo | de melodie in het menu |
| `fm_piano` | FM-elektrische piano | de handelaar |
| `fm_vibrafoon` | FM-vibrafoon: een korte hamertik (modulator op 4x) op een ronde, langzaam wegstervende toon, licht zwevend | de muzak van de supermarkten |
| `fm_fluit` | FM-fluit: bijna zuivere toon, een beetje adem een octaaf hoger, zachte inzet, vibrato na de inzet | de melodie van de muzak |
| `fm_strijkers` | zachte FM-strijkers: twee ontstemde paren, weinig feedback, trage aanzwelling, breed | akkoordvlakken in de muzak, de jingle van ALFRED STEYHN |

**Drumstellen** (`DRUM_KITS` in `instruments.py`, gekozen met `BIJSTELLING["drumstel"]`):
`standaard` (dikke 909-achtige kick, gated-reverb-snare) en `dmx` (de rauwe Mega Drive-kick en een
droge snare, beide door de DAC op een lage samplefrequentie; hi-hats, clap, crash en toms als standaard).

**Een nieuwe klank**: noemt een compositie een instrument dat hier niet bij past, dan komt er
een `FmPatch` (of PSG-instelling) bij in `instruments.py`, met een naam die zegt wat hij is, en
een regel in deze tabel. Bestaande klanken niet ombouwen voor één compositie: een nieuwe ernaast.

Een compositie uit de tijdlijn-vorm heeft daarnaast haar eigen FM-klanken,
`patch:<bestand>:<kanaal>` (de patches uit het bestand, op hun eigen niveau: zie "De nabootsing van de
chips").

**Balans** (`render.sh --controle --balans`: elke partij alleen, gemeten waar ze speelt, in dB
onder de luidste): drums en lead bovenaan (0 tot -1), gitaar, solo en bas -2 tot -3, koper en
subbas rond -4, pad en arpeggio als achtergrond -8 tot -10.

Nu op de plekken: primair "Nitro Overdrive '92" (`nitro_overdrive_92.json`, 132 BPM, 32 maten),
secundair "Street Viper '92" (`street_viper_92.json`, platte vorm: 128 BPM, E mixolydisch, 16
maten: intro, main groove = thema, bridge = opbouw, climax = finale; geen refrein of breakdown, de
afleidingen vallen terug op het dichtstbijzijnde), tertiair "Neon Knuckle" (`neon_knuckle.json`, de tijdlijn-vorm: 126 BPM, G dorisch, 64 maten = 122 s; de FM-kanalen in hun eigen patches uit het bestand, niet nagespeeld: de "GO!"-stem, vibrato, slides).

## Afgeleide stukken

Uit `tools/muziek/derive.py`; alle bestanden in `assets/audio/muziek/`. Uit de **secundaire** basis
(het menu): het hoofdmenu (letterlijk), de karakterkeuze, het laadscherm, de stad, de beloning en level omhoog; uit de **tertiaire**
(de vechtscène, alleen als `GEVECHT` gezet is): `gevecht.ogg`, letterlijk het hele nummer; al het andere uit de
**primaire**. De muzak duurt ten minste 48 s (`MUZAK_SHORTEST`: een compositie met weinig rustige
maten speelt haar muzak nog een ronde). De stukken uit de secundaire houden de **eigen groove** van
dat nummer (`derive.GROOVE_VARIANTS`): de bas en de drums zoals de componist ze schreef, niet de
bewerkingen die voor de primaire gemaakt zijn (half-time, wandelende bas, eigen drumpatronen).

| bestand | waar | gemaakt van |
| --- | --- | --- |
| `zwervr_intro.ogg` | de intro (`scripts/ui/intro.gd`) | de hele compositie, letterlijk, met uitklinken |
| `nachtstad_menu_loop.ogg` | hoofdmenu (lus) | de **secundaire** compositie zelf, letterlijk, als lus in de synth van haar bron (`derive.as_written`; de uitklank loopt door naar het begin, zonder naad); zonder secundaire: de breakdown en het thema van de primaire rustig: pad, arp, subbas, de melodie op klokken, zachte half-time drums (`menu_loop`) |
| `karakterkeuze_loop.ogg` | karakterkeuze (lus) | (secundair, in de eigen groove: bas en drums zoals geschreven) het thema twee keer: eerst zonder, dan met zijn melodie |
| `handelaar_loop.ogg` | bij een handelaar, in de snackbar (lus) | de akkoorden van de opbouw (en de opening van het thema) op elektrische piano, wandelende bas, clap op 2 en 4 |
| `laden_loop.ogg` | het laadscherm (lus) | (secundair, in de eigen groove) de intro-sectie van de compositie (het opstarten) twee keer: eerst zonder melodie (bas, drums, stoten, arp), dan zoals geschreven met melodie |
| `spel_loop.ogg` | de stad (lus, `scripts/ui/hud.gd`, zacht: `CITY_LOOP_SOFTER_DB`) | (secundair, in de eigen groove: bas en drums zoals geschreven, stoten en arp zachter) de intro als groove, het thema als groove en dan met melodie, de opbouw met melodie, het thema weer als groove; de finale blijft eruit (te luid om rond te lopen). Zonder secundaire: uit de primaire in half-time (de klank van de handelaar: elektrische piano, bas in halve noten, kick op 1, clap op 3) |
| `deuntje_kaart_start.ogg` | de kaart opent bij het begin van het spel (`MAP_JINGLE` in `hud.gd`, hooguit 6 s) | de eerste twee maten van de intro-sectie (het opstarten van het nummer), landend op het grondakkoord met een crash; één maat als twee te lang duren |
| `deuntje_nieuwe_missie.ogg` | nieuwe missie | het motief (eerste maat van het thema) met groove, landend op de grondtoon |
| `deuntje_taak_klaar.ogg` | een taak gehaald | een zestiendenloop over de dominant, landend op de grondtoon |
| `deuntje_gewonnen.ogg` | een missie gehaald | de laatste twee maten van de compositie (haar finish); heeft de compositie geen slot (geen aangehouden slotnoot of crash in de laatste maat: een export van een nummer dat doorloopt), dan haar laatste maat als aanloop, landend op het grondakkoord met een crash |
| `deuntje_level_omhoog.ogg` | level omhoog | (secundair: de loop over de eigen drums van het thema) een loop over het grondakkoord naar de hoge grondtoon, met gitaar en crash |
| `deuntje_beloning.ogg` | een beloning of item gekregen (het beloningsscherm) | (secundair: over de eigen drums van het thema) het grondakkoord als een sprankel op en neer in de arp, de hoge grondtoon erboven met pad en een zachte crash |
| `deuntje_dood.ogg` | dood | het motief op halve snelheid een octaaf lager, vallend naar de lage grondtoon, tapestop |
| `supermarkt_muzak_1.ogg` | in een supermarkt (lus, zacht op de achtergrond: `MUZAK_SOFTER_DB` in `hud.gd`; elk filiaal één van de drie, `SUPERMARKET_MUZAK` in `interiors.gd`) | **bossa nova** (100 BPM): de akkoorden van het thema alleen (vier maten), het thema op de fluit, het thema op de vibrafoon, het refrein op de fluit; bossabas, vibrafoon-stoten, strijkers, zachte bossa-drums |
| `supermarkt_muzak_2.ogg` | idem | **trage ballade** (76 BPM): de akkoorden van de breakdown (strijkers, gebroken piano), het refrein op de vibrafoon, het thema op de fluit; lange bas, heel zacht ritme |
| `supermarkt_muzak_3.ogg` | idem | **lichte swing** (112 BPM, swing 0,6): het thema op de piano, het refrein op klokken, het thema op de vibrafoon, het refrein op de piano; wandelende bas, vibrafoon op 2 en 4 |
| `jingle_derrek.ogg` | de omroep van DERREK (`scripts/world/interiors/supermarket_announcer.gd`, voor een aanbieding of mededeling) | de eerste helft van het motief fel op de PSG, landend op tel 3 op de hoge grondtoon boven het grondakkoord in majeur (maj7) op koper; kick, hi-hat, crash |
| `jingle_alfred_steyhn.ogg` | de omroep van ALFRED STEYHN | de eerste helft van de opening van het refrein op klokken, landend op de hoge grondtoon boven strijkers (maj7), alleen een zachte crash |
| `gevecht.ogg` | de vechtscène (nog niet in het spel) | alleen als `GEVECHT` gezet is: de **tertiaire** compositie zelf, het hele nummer zoals aangeleverd, één bestand (`derive.fight_loop`) |

**De muzak** (de supermarkten) is easy listening uit het materiaal van de compositie: de
akkoorden **gezoet** (een powerchord of drieklank krijgt de terts van de toonsoort en een septiem:
in mineur I m7, bII maj7, II m7b5, III maj7, IV m7, V 7, VI maj7, VII 6; in majeur I maj7, II m7,
III m7, IV maj7, V 7, VI m7, VII m7b5), de melodie **gladgestreken** (alleen de noten op het
achtste-raster, elk aangehouden tot de volgende, een octaaf lager), in een eigen tempo
(`MUZAK_TEMPOS`), in zachte klanken (fluit, vibrafoon, strijkers, elektrische piano, klokken) en
het standaard drumstel heel zacht. Maten met meer dan twee akkoorden (de chromatische
klimmen) blijven eruit. Elke lus duurt ongeveer een minuut (40 tot 150 s, de test). **De
jingles** van de ketens zijn hooguit 6 s, een opening uit de compositie die in majeur landt.

De afleidingen zoeken de secties op hun `soort`; een compositie zonder breakdown of opbouw valt
terug op de dichtstbijzijnde sectie. Een compositie met een heel andere vorm kan in
`derive.py` een eigen keuze nodig hebben; dan daar, niet in het compositiebestand.

Elke compositie levert **alle** stukken in deze tabel, ook het kaartdeuntje, de drie muzaklussen en de twee jingles: een nieuw stuk dat
het spel gaat gebruiken, komt hier en in `derive.py` (`ALL`) bij, nooit als los bestand naast de
compositie.

## Controleren

`tools/muziek/render.sh --controle`: elk stuk bestaat, is zo lang als de partituur zegt, staat op
-16 LUFS met pieken onder -1,5 dB, een lus springt niet bij de naad en valt nergens stil; de
energie per sectie van de intro; de noten buiten de toonsoort (de chromatiek van de componist,
ter controle). Met `--balans` ook de balans van de partijen.

`tools/muziek/render.sh --test`: de unit tests van de muziektools (`test_muziek.py`): de notatie,
de bijstellingen (andere klank, verdubbelen, drumstel, four on the floor laat breaks en fills
met rust), en voor elke compositie: al haar klanken bestaan, alle stukken worden gemaakt, het
kaartdeuntje blijft onder 6 s, de muzak loopt (40-150 s, zonder chromatische maten) en de jingles
blijven onder 6 s, de muzak zoet powerchords, elke noot valt binnen zijn maat; de lezers van het JSON van de
componist (de gewone vorm, de platte vorm, de tijdlijn met haar eigen patches); de basisplekken
(het menu en de vechtscène letterlijk); en de nabootsing van de chips (de frequentie van F-number
en blok tot op een halve cent, de envelope, FM en feedback, de PSG-blokgolven, -volumes en -ruis).

De bestanden staan in `tools/muziek/`:

- `notation.py`: de notatie van de compositiebestanden;
- `score.py`: een compositie ingelezen als maten met partijen;
- `instruments.py`: de klanken en het drumstel;
- `mixer.py`: maten naar stereo (lus of eenmalig), mastering en luidheid;
- `derive.py`: de afgeleide stukken;
- `build.py`: alles maken (via `render.sh`), en `intro_timing.gd`;
- `check.py`: de controle (via `render.sh --controle`);
- `json_bron.py`, `tijdlijn.py`, `tracker.py`: het JSON (of de tracker-pagina) van de componist
  lezen en als compositiebestand schrijven (via `render.sh --json`);
- `fm.py`: wat de tools delen over de YM2612 (de patch `FmVoice`, de klok) en de klanksoorten;
- `chip.py`: de nabootsing van de YM2612 en de SN76489 uit hun registers (de `patch:`-klanken);
- `composition.md`: de tekst van de componist die nu aan de beurt is (hier lever je aan);
- `composities/`: de composities (`<naam>.txt` of `<naam>.json` het origineel, `<naam>.py` de
  notatie) en `actief.py` (de drie plekken: `ACTIEF`, `MENU`, `GEVECHT`).
