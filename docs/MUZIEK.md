# Muziek: de huisstijl van ZWERVR

Alle muziek van het spel komt uit **één compositie**. Een componist (nu: Gemini) schrijft een
nummer maat voor maat uit; dat nummer wordt letterlijk de **intro**, en elk ander stuk (menu,
karakterkeuze, handelaar, de stad, de deuntjes) wordt daaruit **afgeleid**: dezelfde akkoorden,
melodieën, klanken en drums, anders gearrangeerd. Zo klinkt het hele spel als één soundtrack. Af
en toe komt er een nieuwe compositie; dan wordt alle muziek opnieuw gemaakt.

Alles klinkt als een **Sega Mega Drive**-cartridge: YM2612-FM, SN76489-PSG en PCM-drums door de
8-bit DAC (de geluidschip `tools/megadrive/megadrive.py`, dezelfde als die van de
geluidseffecten, `docs/GELUIDEN.md`). Noemt een compositie moderne instrumenten (een zaagtand-pad,
een distortion-gitaar), dan worden dat FM-klanken die op de chip passen.

## Een nieuwe compositie aanleveren

1. Zet de tekst van de componist in **`tools/muziek/composition.md`** (de vorige eruit) en vraag
   om er de muziek van te maken; de skill **`/muziek-compositie`** doet de stappen hieronder.
2. De tekst wordt ook bewaard als `tools/muziek/composities/<naam>.txt` (het origineel, niets
   veranderd, zodat het blijft als `composition.md` later een andere is) en overgezet in `tools/muziek/composities/<naam>.py` (de notatie hieronder).
3. `tools/muziek/composities/actief.py`: `ACTIEF = "<naam>"`.
4. `tools/muziek/render.sh` maakt alles in `assets/audio/muziek/` en schrijft
   `scripts/ui/intro_timing.gd`; `tools/muziek/render.sh --controle` kijkt alles na.

Een compositie kan ook als **VGM-bestand** komen (het registerlog van de Mega Drive-geluidschips):
zie "Een VGM als compositie" hieronder.

Oude composities blijven staan; terug naar een eerdere is `ACTIEF` terugzetten en opnieuw
renderen. Eerst luisteren zonder iets te vervangen: `tools/muziek/render.sh --uit <map>`, of
`ZWERVR_COMPOSITIE=<naam> tools/muziek/render.sh --uit <map>` voor een andere compositie.

## Een VGM als compositie

Een **VGM** (`.vgm`, of gezipt `.vgz`) is geen tekst maar het logboek van wat een nummer naar de
geluidschips van de Mega Drive schrijft (YM2612-FM en SN76489-PSG), met de tijd in samples van
1/44100 s. Zo'n nummer wordt **exact** de muziek van het spel:

- **De intro is het VGM zelf.** `tools/muziek/chip.py` bootst de twee chips na uit het
  registerlog; `zwervr_intro.ogg` is die weergave, met alleen de afwerking die elk stuk krijgt
  (uitklinken, het filter van de Model 1, -16 LUFS). Geen andere instrumenten, geen noten
  afgerond, geen octaaf verschoven, niets erbij.
- **De afgeleide stukken klinken met de stemmen van het VGM**: de patches van zijn FM-kanalen
  (door dezelfde nabootsing gespeeld) en een drumstel van zijn PSG-ruis.

```
tools/muziek/render.sh --vgm <bestand> [naam] --toon        # alleen laten zien wat erin zit
tools/muziek/render.sh --vgm <bestand> [naam]               # composities/<naam>.py schrijven
tools/muziek/render.sh --vgm <bestand> [naam] --vergelijk   # composities/<naam>.py tegen het VGM
tools/muziek/render.sh --vgm <bestand> [naam] --meet        # de nabootsing en de intro nameten
```

(`naam`: standaard de bestandsnaam; `--overschrijf` vervangt een bestaand compositiebestand,
`--tempo 92` en `--titel "..."` als het bestand ze niet geeft.) Het VGM zelf wordt als
`tools/muziek/composities/<naam>.vgm` bewaard: daar speelt de intro uit, het moet blijven staan.

### De nabootsing van de chips (`chip.py`)

Uit het registerlog, op de eigen samplefrequentie van de chip (klok / 144, 53267 Hz), daarna
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
tremolo), SSG-EG en de CSM-modus; gebruikt een VGM ze, dan meldt `--meet` dat.

`--meet` meet de weergave na tegen het registerlog: per FM-kanaal, alleen gespeeld, de periode
van elke noot tegen de frequentie die de registers geven (in cent); het niveau van elke
ruis-slag tegen zijn volumeregister; en van het intro-bestand de lengte, de gelijkenis met de
kale nabootsing (correlatie) en het niveau per achtste deel. Er is geen tweede emulator om mee
te vergelijken (geen vgmplay, geen libgme in ffmpeg).

### Het compositiebestand uit een VGM (`vgm.py`)

Voor de afgeleide stukken (en voor de lengte en de `MOMENTEN` van de intro) schrijft `vgm.py` de
noten ook uit als compositiebestand, in dezelfde vorm als een overgeschreven tekst:

- **FM-kanalen** (`fm1`..`fm6`): elke key-on (register 0x28) is een noot, met de toonhoogte uit
  F-number en blok (0xA0-0xA6) naar de dichtstbijzijnde noot, tot de key-off; verandert de
  frequentie onder een aangehouden toets naar een andere halve toon, dan is dat een nieuwe noot.
- **PSG-tonen** (`psg1`..`psg3`): de periode geeft de toonhoogte, het volume aan/uit en de
  aanslagsterkte; een toon die na het wegsterven weer harder wordt, is een nieuwe noot.
- **Drums**: het ruiskanaal van de PSG (witte ruis: hard een snare, zacht een hi-hat als het
  bestand beide niveaus heeft, 4 dB of meer uit elkaar; lang een open hi-hat of een crash;
  periodieke ruis een lage tom) en de **DAC** (kanaal 6, register 0x2A/0x2B, ook de datablokken
  en stream-commando's): elke stoot samples is een slag, benoemd naar hoe de sample eruitziet
  (een lage dreun een kick, een toon een tom, ruis een snare).
- **Tempo en maat**: het raster is de kleinste afstand tussen noten die vaak terugkomt, op alle
  noten gepast; het tempo is de telverdeling daarvan (zestienden, achtsten, triolen) die tussen
  80 en 180 BPM uitkomt. Een getal aan het eind van de bestandsnaam (`_92`) wordt als tempo
  geprobeerd en geldt alleen als het op het raster past; het bestand zegt erbij of het klopte.
  De maat is drie of vier tellen, wat de muziek het best laat herhalen. De eerste noot is tel 1
  van maat 1.
- **Partijen**: het laagste kanaal is de `bas`; kanalen die samen aanslaan worden akkoorden
  (`pad` bij lange noten, `brass` bij korte; speelt een kanaal hetzelfde als een ander, dan valt
  de verdubbeling weg); een kanaal dat het raster bijna vult is de `arp`; wat overblijft is de
  `lead` (en `lead2`, ...).
- **Toonsoort, akkoorden, secties, momenten** staan niet in een VGM en worden afgeleid: de
  toonsoort uit hoe lang elke toon klinkt (de melodie telt dubbel), het akkoord van elke maat
  (of van haar helften) uit haar noten, de secties uit frasen van vier maten met dezelfde
  baslijn en dezelfde bezetting (de eerste zonder melodie is de `intro`, de eerste met melodie
  het `thema`, de drukste met ander materiaal het `refrein`, de dunste de `breakdown`, de
  laatste de `finale`), en de `MOMENTEN` uit die secties.

Wat een VGM-compositie meer heeft dan een gewone:

```python
VGM = "nitro_overdrive_92.vgm"          # de intro wordt uit dit bestand gespeeld (chip.py)
KLANKEN = {"bas": "vgm:nitro_overdrive_92.vgm:fm1=fm_housebas", ...}
AFGELEID_OCTAAF = {"lead": 2}           # alleen in de afgeleide stukken, niet in de intro
AFGELEIDE_KLANKEN = {"fm_piano": "vgm:nitro_overdrive_92.vgm:fm2=fm_piano", ..., "standaard": "vgm:nitro_overdrive_92.vgm"}
```

- **`vgm:<bestand>:<kanaal>`** is een klank: de patch van dat FM-kanaal, gespeeld door de
  nabootsing (elke toonhoogte op het F-number en blok dat een sounddriver zou kiezen). Met
  **`=<klank>`** staat hij op de plek van die klank in de mix: dezelfde pan en breedte en even
  hard (gemeten), zodat de balans van de afgeleide stukken blijft; zonder echo, de chip heeft
  er geen. De omzetter kiest die plek bij de patch (veel feedback een rauwe bas of lead, enz.).
- **`AFGELEIDE_KLANKEN`** vervangt in elk afgeleid stuk elke klank die `derive.py` gebruikt door
  een stem van het VGM: de bas-klanken door het kanaal van de bas, de leads door dat van de
  melodie, de akkoordklanken (pad, koper, piano, strijkers, gitaar) en de zachte klanken (klok,
  fluit, vibrafoon, arpeggio) door een patch die het VGM wel zet maar niet speelt als die er is
  (anders die van de akkoorden of de melodie). Welke, staat als commentaar in het bestand.
- **Het drumstel `vgm:<bestand>`** vervangt `standaard` en `dmx`. Uit het VGM zelf: de snare en
  de hi-hat (stoten witte PSG-ruis op de twee volumes en de lengte van zijn eigen slagen).
  **Afgeleid**, omdat de afgeleide stukken ze nodig hebben: de open hi-hat (de hi-hat twee keer zo
  lang), de crash (de ruis die in de 2 dB-stappen van de chip wegvalt), de clap (drie korte
  stoten), en de kick en de toms (de patch van het laagste FM-kanaal met een vallende
  toonhoogte). Elk even hard als dezelfde drum van het standaardstel.
- **`AFGELEID_OCTAAF`**: de maten staan in het octaaf van het VGM. Ligt een partij ver van waar
  de afgeleide stukken haar verwachten (de melodie rond octaaf 5, de bas rond octaaf 2), dan
  ligt ze alleen dáár zoveel octaven anders. De intro raakt het niet.

Beperkingen van de omzetting naar noten (de intro heeft ze niet, die speelt het log zelf):
alleen YM2612 en SN76489 (commando's van andere chips worden overgeslagen en gemeld);
toonhoogtebuigingen binnen een halve toon vallen weg; een opmaat wordt niet herkend (de eerste
noot is altijd tel 1); het luspunt wordt gemeld maar het bestand wordt één keer gelezen. Heeft
een noot het **hoogste F-number (2047)**, dan heeft de schrijver van het VGM de toonhoogte
waarschijnlijk afgekapt: in de intro klinkt hij zoals de chip hem speelt (de exacte frequentie),
in de maten staat de dichtstbijzijnde noot, hij telt niet mee voor de toonsoort en licht voor de
akkoorden, en het bestand meldt het. Wat de omzetter afleidt (akkoorden, secties, momenten, de
keuze van de stemmen, octaven) mag je daarna met de hand verbeteren in het compositiebestand;
opnieuw omzetten overschrijft dat (`--overschrijf`).

Nu actief: "Nitro Overdrive" (`nitro_overdrive_92.vgm`): 132 BPM (de 92 in de naam is niet het
tempo), E majeur, 32 maten; twee FM-kanalen (`fm1` de bas, `fm3` de lead) en de PSG-ruis als
snare en hi-hat. De afgeleide stukken: bas op de patch van `fm1`, melodie op die van `fm3`,
akkoorden op `fm2` en zachte klanken op `fm4` (twee patches die het VGM zet maar niet speelt),
de melodie twee octaven boven het VGM.

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

Een **VGM-compositie** heeft daarnaast haar eigen klanken, `vgm:<bestand>:<kanaal>=<klank>`, en
haar eigen drumstel, `vgm:<bestand>` (zie "Een VGM als compositie"). Bij zo'n compositie laat
`--balans` de kanalen van het VGM zelf zien: die balans is van het VGM en wordt niet bijgesteld.

**Balans** (`render.sh --controle --balans`: elke partij alleen, gemeten waar ze speelt, in dB
onder de luidste): drums en lead bovenaan (0 tot -1), gitaar, solo en bas -2 tot -3, koper en
subbas rond -4, pad en arpeggio als achtergrond -8 tot -10.

## Afgeleide stukken

Uit `tools/muziek/derive.py`; alle bestanden in `assets/audio/muziek/`:

| bestand | waar | gemaakt van |
| --- | --- | --- |
| `zwervr_intro.ogg` | de intro (`scripts/ui/intro.gd`) | de hele compositie, letterlijk, met uitklinken; een VGM-compositie: het VGM zelf, door de nabootsing van de chips gespeeld |
| `nachtstad_menu_loop.ogg` | hoofdmenu (lus) | de breakdown en het thema rustig: pad, arp, subbas, de melodie op klokken, zachte half-time drums |
| `karakterkeuze_loop.ogg` | karakterkeuze (lus) | het thema twee keer: eerst alleen de groove, dan de melodie op de PSG |
| `handelaar_loop.ogg` | bij een handelaar, in de snackbar (lus) | de akkoorden van de opbouw (en de opening van het thema) op elektrische piano, wandelende bas, clap op 2 en 4 |
| `laden_loop.ogg` | het laadscherm (lus) | de intro-sectie van de compositie (het opstarten) twee keer: eerst alleen de puls (pad, bas, arp, lichte beat), dan zoals geschreven met melodie en fill, die terugloopt naar het begin |
| `spel_loop.ogg` | de stad (lus, `scripts/ui/hud.gd`, zacht: `CITY_LOOP_SOFTER_DB`) | **rustig en op de achtergrond**: de klank van de handelaar (elektrische piano, bas, clap) in **half-time** (kick op 1, clap op 3, de piano houdt zijn akkoorden aan, de bas loopt in halve noten), afwisselend zoals de handelaarslus: het thema als akkoorden; het thema met zijn melodie om en om per maat (vraag en antwoord); de opbouw met de stoten van de handelaar; het refrein met de melodie op klokken om de maat; de breakdown met alleen piano en bas, terug naar het begin. Recht, geen shuffle, geen doorlopende arpeggio |
| `deuntje_kaart_start.ogg` | de kaart opent bij het begin van het spel (`MAP_JINGLE` in `hud.gd`, hooguit 6 s) | de eerste twee maten van de intro-sectie (het opstarten van het nummer), landend op het grondakkoord met een crash; één maat als twee te lang duren |
| `deuntje_nieuwe_missie.ogg` | nieuwe missie | het motief (eerste maat van het thema) met groove, landend op de grondtoon |
| `deuntje_taak_klaar.ogg` | een taak gehaald | een zestiendenloop over de dominant, landend op de grondtoon |
| `deuntje_gewonnen.ogg` | een missie gehaald | de laatste twee maten van de compositie (haar finish); heeft de compositie geen slot (geen aangehouden slotnoot of crash in de laatste maat: een VGM van een nummer dat doorloopt), dan haar laatste maat als aanloop, landend op het grondakkoord met een crash |
| `deuntje_level_omhoog.ogg` | level omhoog | een loop over het grondakkoord naar de hoge grondtoon, met gitaar en crash |
| `deuntje_beloning.ogg` | een beloning of item gekregen (het beloningsscherm) | het grondakkoord als een sprankel op en neer in de arp, de hoge grondtoon erboven met pad en een zachte crash |
| `deuntje_dood.ogg` | dood | het motief op halve snelheid een octaaf lager, vallend naar de lage grondtoon, tapestop |
| `supermarkt_muzak_1.ogg` | in een supermarkt (lus, zacht op de achtergrond: `MUZAK_SOFTER_DB` in `hud.gd`; elk filiaal één van de drie, `SUPERMARKET_MUZAK` in `interiors.gd`) | **bossa nova** (100 BPM): de akkoorden van het thema alleen (vier maten), het thema op de fluit, het thema op de vibrafoon, het refrein op de fluit; bossabas, vibrafoon-stoten, strijkers, zachte bossa-drums |
| `supermarkt_muzak_2.ogg` | idem | **trage ballade** (76 BPM): de akkoorden van de breakdown (strijkers, gebroken piano), het refrein op de vibrafoon, het thema op de fluit; lange bas, heel zacht ritme |
| `supermarkt_muzak_3.ogg` | idem | **lichte swing** (112 BPM, swing 0,6): het thema op de piano, het refrein op klokken, het thema op de vibrafoon, het refrein op de piano; wandelende bas, vibrafoon op 2 en 4 |
| `jingle_derrek.ogg` | de omroep van DERREK (`scripts/world/interiors/supermarket_announcer.gd`, voor een aanbieding of mededeling) | de eerste helft van het motief fel op de PSG, landend op tel 3 op de hoge grondtoon boven het grondakkoord in majeur (maj7) op koper; kick, hi-hat, crash |
| `jingle_alfred_steyhn.ogg` | de omroep van ALFRED STEYHN | de eerste helft van de opening van het refrein op klokken, landend op de hoge grondtoon boven strijkers (maj7), alleen een zachte crash |

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
blijven onder 6 s, de muzak zoet powerchords, elke noot valt binnen zijn maat; en de VGM-lezer op
een klein VGM dat de test zelf maakt (FM-noten met toonhoogte, begin en lengte, PSG-tonen en
ruis-drums, DAC-samples als drums, het tempo tegen de bestandsnaam, gzip, afgekapte F-numbers,
partijen/akkoorden/secties, het compositiebestand dat eruit komt), elke compositie met een
`.vgm` ernaast komt nog overeen met dat VGM, haar intro is dat VGM en haar afgeleide stukken
gebruiken alleen stemmen en het drumstel van dat VGM; en de nabootsing van de chips (de
frequentie van F-number en blok tot op een halve cent, de envelope, FM en feedback, de
PSG-blokgolven, -volumes en -ruis, een heel VGM met panning).

De bestanden staan in `tools/muziek/`:

- `notation.py`: de notatie van de compositiebestanden;
- `score.py`: een compositie ingelezen als maten met partijen;
- `instruments.py`: de klanken en het drumstel;
- `mixer.py`: maten naar stereo (lus of eenmalig), mastering en luidheid;
- `derive.py`: de afgeleide stukken;
- `build.py`: alles maken (via `render.sh`), en `intro_timing.gd`;
- `check.py`: de controle (via `render.sh --controle`);
- `vgm.py`: een VGM-bestand lezen en als compositiebestand schrijven (via `render.sh --vgm`);
- `chip.py`: de nabootsing van de YM2612 en de SN76489 uit hun registers (de intro van een
  VGM-compositie, de `vgm:`-klanken en het `vgm:`-drumstel);
- `composition.md`: de tekst van de componist die nu aan de beurt is (hier lever je aan);
- `composities/`: de composities (`<naam>.txt` of `<naam>.vgm` het origineel, `<naam>.py` de
  notatie) en `actief.py`.
