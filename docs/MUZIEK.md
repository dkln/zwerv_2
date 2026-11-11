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

Oude composities blijven staan; terug naar een eerdere is `ACTIEF` terugzetten en opnieuw
renderen. Eerst luisteren zonder iets te vervangen: `tools/muziek/render.sh --uit <map>`, of
`ZWERVR_COMPOSITIE=<naam> tools/muziek/render.sh --uit <map>` voor een andere compositie.

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
    "octaaf": {"arp": 1},                           # een partij octaven hoger (+) of lager (-)
    "kick_op_elke_tel": ("thema", "refrein", "finale"),   # four on the floor
    "open_hihat": ("intro", "thema", "opbouw", "refrein", "finale"),  # op de off-beats
    "handklap": ("thema", "refrein", "finale"),     # een clap bij de snare op 2 en 4
    "stoten": {"secties": ("thema", "refrein"), "klank": "fm_piano"},  # akkoordstoten op de off-beats
    "majeur_slot": True,                            # slotakkoord en landingen van de deuntjes in majeur
}
```

De drum-bijstellingen gelden alleen in maten met een groove (kick en snare) en laten fills en
de slotmaat (de eindklappen) met rust; de stoten zijn uit de akkoorden gespeld; `majeur_slot`
geeft het slotakkoord de grote terts (en de landing van nieuwe missie, taak klaar en level
omhoog); het deuntje van de dood blijft mineur. Nu ingesteld voor "Blast Processing Overdrive":
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
| `synthwave_pad` | FM-zaagtand (feedback), traag, breed | akkoordvlakken |
| `synth_brass` | FM-koper, breed | akkoordstoten |
| `fm_lead_helder` | heldere FM-lead, vibrato 6 Hz, gepuncteerde-achtste echo | de hoofdmelodie |
| `psg_arp` | PSG-blokgolf, kort | arpeggio's in zestienden |
| `psg_lead` | PSG-blokgolf met vibrato en echo | de melodie in rustiger stukken |
| `overdrive_gitaar` | FM-snaren samen overstuurd, donkere kast | powerchords |
| `overdrive_gitaar_solo` | idem, harder gedreven, echo | riffs en solo's |
| `fm_klok` | FM-klok, lange echo | de melodie in het menu |
| `fm_piano` | FM-elektrische piano | de handelaar |

**Een nieuwe klank**: noemt een compositie een instrument dat hier niet bij past, dan komt er
een `FmPatch` (of PSG-instelling) bij in `instruments.py`, met een naam die zegt wat hij is, en
een regel in deze tabel. Bestaande klanken niet ombouwen voor één compositie: een nieuwe ernaast.

**Balans** (`render.sh --controle --balans`: elke partij alleen, gemeten waar ze speelt, in dB
onder de luidste): drums en lead bovenaan (0 tot -1), gitaar, solo en bas -2 tot -3, koper en
subbas rond -4, pad en arpeggio als achtergrond -8 tot -10.

## Afgeleide stukken

Uit `tools/muziek/derive.py`; alle bestanden in `assets/audio/muziek/`:

| bestand | waar | gemaakt van |
| --- | --- | --- |
| `zwervr_intro.ogg` | de intro (`scripts/ui/intro.gd`) | de hele compositie, letterlijk, met uitklinken |
| `nachtstad_menu_loop.ogg` | hoofdmenu (lus) | de breakdown en het thema rustig: pad, arp, subbas, de melodie op klokken, zachte half-time drums |
| `karakterkeuze_loop.ogg` | karakterkeuze (lus) | het thema twee keer: eerst alleen de groove, dan de melodie op de PSG |
| `handelaar_loop.ogg` | bij een handelaar, in de snackbar (lus) | de akkoorden van de opbouw (en de opening van het thema) op elektrische piano, wandelende bas, clap op 2 en 4 |
| `laden_loop.ogg` | het laadscherm (lus) | de intro-sectie van de compositie (het opstarten) twee keer: eerst alleen de puls (pad, bas, arp, lichte beat), dan zoals geschreven met melodie en fill, die terugloopt naar het begin |
| `spel_loop.ogg` | de stad (lus, `scripts/ui/hud.gd`, zacht: `CITY_LOOP_SOFTER_DB`) | **rustig en op de achtergrond**: de klank van de handelaar (elektrische piano, bas, clap) in **half-time** (kick op 1, clap op 3, de piano houdt zijn akkoorden aan, de bas loopt in halve noten), afwisselend zoals de handelaarslus: het thema als akkoorden; het thema met zijn melodie om en om per maat (vraag en antwoord); de opbouw met de stoten van de handelaar; het refrein met de melodie op klokken om de maat; de breakdown met alleen piano en bas, terug naar het begin. Recht, geen shuffle, geen doorlopende arpeggio |
| `deuntje_nieuwe_missie.ogg` | nieuwe missie | het motief (eerste maat van het thema) met groove, landend op de grondtoon |
| `deuntje_taak_klaar.ogg` | een taak gehaald | een zestiendenloop over de dominant, landend op de grondtoon |
| `deuntje_gewonnen.ogg` | een missie gehaald | de laatste twee maten van de compositie (haar finish) |
| `deuntje_level_omhoog.ogg` | level omhoog | een loop over het grondakkoord naar de hoge grondtoon, met gitaar en crash |
| `deuntje_dood.ogg` | dood | het motief op halve snelheid een octaaf lager, vallend naar de lage grondtoon, tapestop |

De afleidingen zoeken de secties op hun `soort`; een compositie zonder breakdown of opbouw valt
terug op de dichtstbijzijnde sectie. Een compositie met een heel andere vorm kan in
`derive.py` een eigen keuze nodig hebben; dan daar, niet in het compositiebestand.

Nog uit de vorige muziek (niet afgeleid): `deuntje_kaart_start.ogg` (de kaart opent).

## Controleren

`tools/muziek/render.sh --controle`: elk stuk bestaat, is zo lang als de partituur zegt, staat op
-16 LUFS met pieken onder -1,5 dB, een lus springt niet bij de naad en valt nergens stil; de
energie per sectie van de intro; de noten buiten de toonsoort (de chromatiek van de componist,
ter controle). Met `--balans` ook de balans van de partijen.

De bestanden staan in `tools/muziek/`:

- `notation.py`: de notatie van de compositiebestanden;
- `score.py`: een compositie ingelezen als maten met partijen;
- `instruments.py`: de klanken en het drumstel;
- `mixer.py`: maten naar stereo (lus of eenmalig), mastering en luidheid;
- `derive.py`: de afgeleide stukken;
- `build.py`: alles maken (via `render.sh`), en `intro_timing.gd`;
- `check.py`: de controle (via `render.sh --controle`);
- `composition.md`: de tekst van de componist die nu aan de beurt is (hier lever je aan);
- `composities/`: de composities (`<naam>.txt` het origineel, `<naam>.py` de notatie) en
  `actief.py`.
