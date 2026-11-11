===========
ZWERVR GAME
===========

Een tile-gebaseerde wereldbouwer in Godot 4.7 met voxel-tiles uit Goxel.
Je bouwt kaarten met vier GridMap-lagen (grond, gebouwen, details, props). Elke
tile is een los `.gox` bestand dat je in Goxel (open source) kunt openen en aanpassen.
Na opslaan importeert Godot hem automatisch opnieuw.

Er zijn ongeveer 2000 tiles. De kaart van het spel is `scenes/stad.tscn`. Niet elke tile
ligt daarin: `tools/check/coverage.gd` telt welke wel.

Daarnaast is er het centrum van Den Haag in één scène: `scenes/stad.tscn`, ingedikt op
een stratengrid en alleen met de bestaande tiles. De herkenbare gebouwen hebben een naam in de
scene-metadata `places` (bijvoorbeeld `hoftoren`, `de_resident`, `strijkijzer`, `tweede_kamer`,
`bijenkorf`, `snoeptrommel`, `stadhuis`, `castalia`, `muzentoren`, `provinciehuis`, `koekamp`, `bezuidenhoutseweg`,
`caballerofabriek`, `busmuseum`, `fokker_terminal`, `fokkerhaven`, `kasteel_binckhorst`). In de oude binnenstad (Noordeinde, Denneweg, Hoogstraat,
Grote Markt en de noordkant van de Grote Marktstraat) krijgen de winkelhuizen van de klassieke
stijlen en `herenhuis_1600` meestal een trap-, tuit-, klok- of halsgevel (`_shops` met `gables`,
`gevel_<soort>` met een zadeldak erachter). De Singelgracht loopt er rondom
(kades aan beide kanten). Binnen de singel liggen de buurten ongeveer op hun echte
plek: Paleis Noordeinde met de Paleistuin, het Lange Voorhout met Kloosterkerk en Hotel
Des Indes, de Denneweg met aan de zuidkant, op de hoek van het Korte Voorhout en de
Prinsessegracht, het Ministerie van Financien (vleugels in een glazen huid rond een atrium
met glazen dak, een wintertuin op de hoek); de Grote Kerk met Hoogstraat en Oude Raadhuis, de Hofvijver
(met eilandje) met Binnenhof, Ridderzaal, Torentje, Mauritshuis, Buitenhof en
Gevangenpoort, het Plein met standbeeld en terrassen; de Grote Markt, Chinatown
(Wagenstraat), de Grote Marktstraat met Bijenkorf en Passage, De Snoeptrommel (het
snoeppaleis, met The Sting) aan de Dagelijkse Groenmarkt tegenover het Oude Raadhuis, de Tweede Kamer
aan de zuidkant van het Plein, het Spuiplein met Nieuwe
Kerk, wit stadhuis en een rij cafés aan het Spui met een pleintje. De Grote Markt heeft cafés en terrassen aan drie kanten. Winkels
staan langs de Grote Marktstraat (ook aan de noordkant), de Lange Poten (x 48, langs het Plein)
en het Spui (x 48 ten zuiden van de Grote Marktstraat en de rij aan z 58 bij het Plein). Buiten de Prinsessegracht: het Haagse Bos met Paleis Huis
ten Bosch, het Malieveld (één groot grasveld vanaf de Koningskade) met op de noordwesthoek,
waar de A12 uitkomt op de Zuid-Hollandlaan (de straat z 29 oost van de Koningskade), het
Provinciehuis van Zuid-Holland (een strakke schijf uit de jaren zestig met betonbanden aan de
Zuid-Hollandlaan, een lagere vleugel aan de Koningskade en de Statenzaal achter glas aan het
Zuid-Hollandplein, met uitzicht over het veld) en ten oosten ervan de Koekamp (bos met paden, het
hertenkamp achter een hoog hek en een vijver bij de Bezuidenhoutseweg, de straat z 58 langs
het station), het
Bezuidenhout met daarachter de Theresiastraat (winkelstraat met portiekflats en een
kerk) en de Bezuidenhout-Oost (galerijflats, park met vijver, woontoren), Centraal
Station (een hoge glazen stationshal van 5 lagen over de hal en de perrons, en het
stationsplein met korte rijen fietsenrekken) met de torens erachter (de Hoftoren, 40 lagen met
een spits, de twee torens van de Ministeries van Justitie en Veiligheid en BZK met een
loopbrug, 34 lagen, en De Kroon) en daarachter De Resident: Castalia, het Ministerie van
VWS (twee lichte torens van 28 lagen, elk met twee grachtenpandgevels als top, met het
overdekte Parnassusplein als glazen atrium ertussen) en de donkere Muzentoren (25 lagen), aan
de overkant van het spoor Amare (theater, 5 lagen, x 89 tot 94) aan het Dirigentplein, het
Beatrixkwartier en de kantoren aan de Prins Clauslaan. De A12 (Utrechtsebaan) komt uit
de bocht oost van de stad als snelweg binnen, zakt in twee tunnelbakken en gaat overkapt verder van
de Laan van NOI tot de Juliana van Stolberglaan; op het dek erboven staan de
Malietoren, een rij winkels met Snackbar De Vrijheid en kantoren. Tussen Haagse Bos en
Malieveld komt hij weer boven bij een kruispunt met stoplichten aan de Koningskade,
naast het ministerie. Drie tramlijnen (Kneuterdijk - Korte Voorhout - Malieveld en
Grote Marktstraat - Spui - Centraal, verbonden met bogen via de Buitenhof) met haltes.
Vier bruggen gaan over de oostarm van de singel: Mauritskade, de twee tramstraten en
Zuidwal. Het RandstadRail-viaduct (rijen z 90-91) begint met een helling naast Centraal
Station en loopt naar het oosten, met haltes bij Centraal en het Beatrixkwartier, en verder
over de A12 en Station Voorburg tot de kaartrand. Twee sporen langs de westkant van het station (x 72-73) sluiten het aan op
de tramlijn in straat z 58. De trams van de Grote Marktstraat rijden door een tunnel (helling x 26 tot 31, dicht
van x 32 tot 49, ook onder de kruising met de Korte Vijverberg, helling op bij het Spui x 50 tot 55) met
twee ondergrondse haltes (Grote Markt en Spui) en ingangen op straat. Boven de tunnel is de
Grote Marktstraat voor voetgangers, fietsers en brommers (een strook elke kant op, langs de
westhelling over de stoep, gekozen per tile in `_grote_marktstraat_lanes`); auto's rijden er
niet. Oost van de helling rijden alleen trams. De twee sporen langs Centraal (x 72-73) lopen onder
een lage vleugel van het Ministerie van VWS (De Resident, x 71 tot 74, z 86 tot 89) door, op
kolommen aan beide kanten. Treinsporen lopen uit de stationshal
(x 83-84) naar het zuiden, onder het tramviaduct door, en een helling op naar een eigen viaduct
(z 93-94) tot de kaartrand. Station Laan van NOI (x 119 tot 129) ligt 6 m boven de straat x
128: trein en tram naast elkaar met drie perrons, elk met een trap. Daaronder de Schenkkade
(z 96) en een nieuwe strook stad (z 98 tot 106). Ook west van de Koningskade, ten zuiden van de singel, loopt de Schenkkade door, met galerijflats aan de kade, gesloten bouwblokken en een pleintje met kerk en grasveld, Daaronder het zuiden van de stad op drie straten (z 107, 130, 153): de Schilderswijk (west, bouwblokken, marktplein, school, kerk, park met vijver), Laak (midden, galerijflats, hogeschool, kantoren met Het Strijkijzer vrij op het plein, woontoren) en de Binckhorst (oost, naar wat er echt staat: de CaballeroFabriek, het Haags Busmuseum in
een hal met zaagtanddak naast bedrijfsunits, de Fokker Terminal met zijn hangar van 9 m en
een groot parkeerterrein, de Fokkerhaven met de oude verffabriek Paulussen en haar
schoorsteen, een distributieloods met een betoncentrale en Kasteel Binckhorst op een eiland
in zijn park; loodsen 9 m, bedrijfsunits 6 m hoog). Oost van de stad (x 176 tot 215) buigt de A12 in een haakse bocht (x 181 tot 189) naar het zuiden en loopt langs de Binckhorst en Voorburg, met de halve aansluitingen 3 (Bezuidenhout, aan de Schenkkade) en 4 (Voorburg, aan de straat z 130 de Binckhorst in), zoals in het echt: alleen een afrit voor het verkeer naar Den Haag en een toerit voor het verkeer weg van Den Haag. De straat van een aansluiting gaat met een viaduct over de A12 (6 m, met hellingen op betonnen landhoofden), de afrit en toerit lopen ernaast omhoog. Voorbij Voorburg zakt de A12 in een tunnelbak (vanaf z 148) tot de kaartrand. Het RandstadRail-viaduct en het spoorviaduct gaan over de A12 heen naar Station Voorburg (x 200 tot 210, boven de straat x 204). Voorburg heeft gesloten bouwblokken van drie lagen aan beide kanten van die straat en de Oude Kerk met toren. Het verkeer neemt de afritten en toeritten: de builder geeft de op- en afrittiles hun rijrichting (`_choose_lanes`) en zet uitvoegpunten van de rechterstrook naar de afrit en stapsgewijs langs het ontwerp (`_a12_ramp_lanes`); boven op het viaduct kan het links- en rechtsaf. Steile hellingen en brughellingen van wegtiles hebben rijstroken (`ramp_traffic` in `tools/voxgen/traffic.py`; flauwe hellingen niet, die beginnen een halve laag hoger). De kaart is zo 216 x 176 cellen (x 0..215, z 0..175, 864 x 704 m); `X_END` (175) is de rand van de stad, `MAP_END` (215) die van de kaart. Over het vlakke deel van de A12 (x 160) gaat een voetbrug met trappen van de
kantoren aan de Prins Clauslaan naar de straat z 29. Opnieuw bouwen:
`tools/godot.sh --headless --script tools/build/build_city.gd`.

In de stad loop je rond met het gekozen karakter (node `Speler`, zie "De speler" hieronder);
de camera volgt de speler (node `Volgcamera`) en is niet zelf te bewegen: geen vrije camera,
geen rondvlucht. Over het beeld ligt een vignet (node `Vignet`,
`scripts/effects/vignette.gd` + `vignette.gdshader`) dat alleen de randen wat afdonkert
(het begint op 75% van het midden, `inner`; het midden blijft schoon)
(`strength`, `inner`, `softness`, uit met `enabled`): een laag die over het beeld wordt
gemengd, zonder schermkopie of blur, dus vrijwel gratis. Er is geen tilt-shift en geen
scherptediepte (DOF) meer: het beeld is overal scherp.

De speler (node `Speler`, `scripts/player/player_controller.gd`)
------------------------------------------------------------------
- Het karakter van het karakterscherm (`PlayerCharacter.current_id()`), als voxelfiguur
  (`PlayerModel`). Iedereen begint op het Stationsplein bij Centraal (`START_PLACE`, op een
  pleintegel), slapend op zijn rug; als de stad geladen is en
  `sleep_seconds` (3 s) voorbij zijn, of bij een toets, wordt hij wakker en staat op
  (`wake_time`). Slapend loopt hij niet en lopen honger en uithoudingsvermogen niet terug
  (`start_asleep` uit = staand beginnen).
- Lopen: WASD of pijltjes, langs het iso-beeld (omhoog = het beeld in); Shift = rennen
  zolang er uithoudingsvermogen is (`walk_speed` 3 m/s, `run_speed` 6,5 m/s). Geen
  CharacterBody: elke physics-stap een straal omlaag naar de grond (opstapjes tot `max_step`
  0,6 m, niet van een rand van meer dan `max_drop` 1,3 m, niet het water in, niet steiler dan
  `max_slope`) en een cilinder zo breed als de figuur die nergens tegenaan mag (muren,
  lantaarnpalen); geblokkeerd glijdt hij langs de muur. Het gebruikt de collision die de
  tiles al hebben (Grond trimesh, Gebouwen blok, Props doos). De speler heeft zelf een
  botsvorm met de buitenmaten van de figuur (`Botsvorm`, een AnimatableBody3D), zodat
  wrakken ertegen botsen.
- Stats (de HUD toont ze): honger begint vol en loopt altijd langzaam leeg
  (`hunger_per_minute` 10, bij rennen 2×); leeg kost het elke `starvation_interval` 3 s
  `starvation_damage` 2 gezondheid. Rennen kost uithoudingsvermogen, dat na 0,8 s weer
  aanvult; leeggerend ben je uitgeput tot 25% terug is. Bij 0 gezondheid ga je dood: de
  figuur valt om, de HUD toont het doodsscherm ("JE BENT DOOD", het dood-deuntje; Enter =
  opnieuw met hetzelfde karakter, Escape = hoofdmenu). Dood door een aanrijding gaat in
  slow motion (`_slow_motion_death`): het spel loopt 2,2 s (echte tijd) op 15 % van zijn
  snelheid (`Engine.time_scale`; de physics stapt dan even vaak per echte seconde, dus de
  wegvliegende figuur blijft vloeiend; het geluid vertraagt mee tot 45 %), de Volgcamera
  zoomt in echte tijd in tot 6 m in beeld (`dramatic_close_up`), daarna komt de snelheid in
  0,5 s terug en het doodsscherm op. Controle: `tools/check/death_slowmo_test.gd`.
- Aangereden: overlapt de voetafdruk van een voertuig (`Vehicle.footprints`) die van de
  speler bij meer dan 1,2 m/s, dan verliest hij `damage_per_speed` × v +
  `damage_per_speed_squared` × v² gezondheid (50 km/h ≈ 55), vliegen er scherven en stof
  (`CrashBurst`), schudt het beeld en wordt de figuur een RigidBody3D (`Valpartij`, de doos
  van de figuur) die met de snelheid van het voertuig wegvliegt en tuimelt. Ligt hij stil,
  dan staat hij op de dichtstbijzijnde beloopbare plek op.
- Pijn (aanrijding, honger, slecht eten) laat de figuur knipperen zoals in oude games
  (`hurt_blink_time`); na het opstaan knippert hij en is hij even onkwetsbaar.
- Inventaris: `inventory` (item -> aantal, `scripts/player/items.gd` met `START_ITEMS` per
  karakter); `use_item` past het effect van een item toe op de stats.
- Test: `tools/check/player_test.gd`.

Verhaal, missies en kleingeld
-----------------------------
- Verhaalvak (`scripts/ui/story_box.gd`, in de HUD: `show_story(pagina's, klaar)`), naar het
  design "Dialoog — story missie": een modal onderin met links een thumbnail van jezelf
  (`PlayerPortrait`, de gekozen figuur in 3D) en rechts de tekst, die woord voor woord
  verschijnt zoals in oude avonturengames (`WORD_SECONDS`, rust na een zin of komma, een
  zacht tikje "woord"). Linksboven een banner (bijv. "PROLOOG · Wakker op Centraal",
  "MISSIE 1 · Twee euro voor een kroket"), rechtsboven "[SPATIE] VERDER". Soorten pagina:
  `verhaal` (amber, "VERTELLER"), `gedachte` (teal, tekst tussen aanhalingstekens) en
  `missie` (amber, "NIEUWE MISSIE"). Spatie/Enter/klik: de rest van de pagina meteen, of de
  volgende; het spel staat stil zolang het vak open is.
- Verhaal (node `Verhaal`, `scripts/story/story.gd`): na het wakker worden de proloog (waar je
  bent, je achtergrondverhaal uit het archetype, twee gedachten bij het wakker worden), dan
  missie 1: € 2 kleingeld bemachtigen voor een kroket bij Jan Blammage. Wat je bij de start
  al hebt telt niet mee (`money_earned`). Bij € 2 een gedachte en de stap is afgevinkt; de
  kroket kopen is de volgende stap: die staat op slot tot de € 2 er zijn (doorschijnend) en wijst
  dan naar de drie dichtstbijzijnde Jan Blammages (de snackbars met het bord `naam_snackbar_2`,
  "JAN BLAMMAGE", en een grote puntzak friet `props/terras/friet_puntzak` op de stoep) op het
  kaartje en de kaart. Elke missie en elke stap heeft eigen XP (`add_xp`, level omhoog met
  deuntje); in het questlog kies je met Enter welke missie je volgt.
- Praten (`scripts/story/conversations.gd`): bij iemand in de buurt "[E] Praten" linksonder;
  een gesprek met keuzes in het verhaalvenster, passend bij het uiterlijk (9 typen). Ze
  brabbelen in hun stem en stemming (`scripts/audio/babble.gd`, `brabbel_<stem>_<stemming>_<n>`
  uit `tools/megadrive/stemmen.py`; een vraag gaat omhoog) en hun lichaam beweegt mee
  (`scripts/world/emote.gd`: boos schudt, blij huppelt, verdrietig hangt voorover).
- Kleingeld (node `Kleingeld`, `scripts/world/loose_change.gd`): 20 munten (10, 20, 50 cent,
  soms een euro) op pleinen en stoepen tot 110 m van de start, drie dichtbij. Eroverheen lopen
  raapt ze op (`add_money`, geluid "munt", het bedrag stijgt op).
- Test: `tools/check/story_test.gd`.
- Statbalken: verandert een stat in één keer met minstens 1,5 punt (aanrijding, honger die
  bijt, eten), dan trilt de rij van die balk kort en licht op (wit bij erbij, rood bij eraf;
  `STAT_SHAKE_*` in hud.gd). Het langzame leeglopen en bijvullen trilt niet.

Op de rails rijden twee RandstadRails (`scripts/vehicles/randstadrail.gd`, twee wagons, 22,25 m) en
twee NS-treinen (`ns_train.gd`, drie wagons, 40 m; elk blijft op zijn eigen spoor, `own_track`), beide op `rail_vehicle.gd`. Ze passen op hun perrons: een tramhalte
is 6 cellen (24 m), een treinperron 11 cellen (44 m); `tools/check/rail_stop_test.gd` controleert dat. Op elk perron
staan OV-chipkaartpaaltjes (`ov/ov_incheckpaal`): aan beide uiteinden van een tramhalte en een viaducthalte, op
de ondergrondse haltes en op de treinperrons van Centraal. Wat erop mag rijden staat
op de tile: `"only": ["tram"]` of `["trein"]` in de `traffic`-metadata, en `"rails"` zegt welke
zijden de rails verbinden (`SN`, `SE`), zodat een voertuig bij een splitsing alleen kan gaan
waar de rails echt lopen. Ze stoppen bij perrons (een tile met `"platform": ["tram"]` of `["trein"]` in zijn metadata, `dwell_time`), openen dan de deuren aan de perronkant
(`door_model`: elk deurblad is een eigen mesh die uit de wagon stapt en opzij schuift) en rijden heen en weer: aan het
eind van het spoor wisselt de bestuurder van cabine en gaat het voertuig geleidelijk over op
het spoor ernaast, dat de andere kant op gaat (treinen niet: die rijden over hun eigen spoor terug). De kopwagons hebben een echte cabine: een
versmallende neus met schuin achteroverhellende voorruit, bord erboven, en een zijraam voor de
bestuurder. Dag en nacht branden wit voorop de eerste wagon en rood achterop de laatste
(`rear_lamp_positions`), zonder remlicht (`lamps_always_on`, `brake_lights`).

De verkeerslichten zijn Nederlands: zwarte kasten met een witte rand, fietslichten met een fiets in
elke lens en voor bus en tram een negenoog (negen witte lampjes: stop horizontaal, rijden verticaal,
attentie een driehoek).

Stoplichten werken: de node `Verkeerslichten` (`scripts/traffic/traffic_lights.gd`, in
elke scène die de bouwers maken) laat de stoplichtprops (`verkeerslichten/auto_*`,
`fiets_*`, `ov_*`, `voetganger_*`, `mast_*`) per kruispunt een vaste cyclus doorlopen:
noord-zuid groen, oranje, alles rood, oost-west groen, oranje, alles rood. De richting
van een licht volgt uit zijn draaiing; tijden zijn instelbaar op de node.

Er rijdt verkeer door de stad: een sedan, node `Auto` (`scripts/vehicles/car.gd`), en een
SUV, node `SUV` (`scripts/vehicles/suv.gd`), staan in de scène; de node `Verkeer`
(`scripts/traffic/traffic.gd`) zet er voertuigen bij (de mix in `MIX`, nodes `Verkeer1`..) en
hulpdiensten en dienstauto's (`SERVICES`, nodes `Dienst1`..). Dat is een set rond de speler,
niet het verkeer van de hele stad:
- Bij het starten komen ze op de wegen binnen `appear_within` (230 m) van de speler, op een
  recht stuk gewone weg dat ergens heen leidt, minstens `spacing` (20 m) uit elkaar.
- Een voertuig verder dan `keep_within` (280 m) van de speler, of dat al `renew_after` (90 tot
  200 s) rondrijdt en verder dan `renew_beyond` (70 m) is, gaat buiten beeld uit de stad: uit de
  boom (niet getekend, rijdt niet, geen geluid; de anderen laten het los, `Vehicle.forget`),
  bewaard om terug te zetten (hooguit `parked_kept`, 30). Nieuwe komen buiten beeld op een
  rijstrook tussen `appear_from` (110 m) en `appear_within` van de speler (een bewaarde van
  dezelfde soort, `Vehicle.put_down`, of een nieuwe). Wrakken, trams en treinen, en de Auto en
  SUV uit de scène blijven altijd.
- Hoeveel: `vehicle_count` (50) maal het aandeel van het uur van de dag en de wijk van de
  speler, hooguit `most_vehicles` (70); de diensten `services_count` (7) maal alleen het
  uuraandeel, minstens `fewest_services` (2). Wat er komt: een voertuigsoort (`auto`, `fiets`,
  `brommer`, `vracht`, `bus`, `landbouw`, `klein`, de derde kolom van `MIX`) getrokken met de
  gewichten van het uur en van de wijk waar het verschijnt, dan een van die soort die de
  rijstrook toestaat. Een fietspad komt zo vaak aan de beurt als er fietsers en brommers zijn.
  Alles in `data/drukte.json` (`scripts/world/crowd.gd`, zie hieronder).
- Per halve seconde (`tick_seconds`) hooguit `changes_per_tick` (4) wissels, na een sprong van de
  speler (een warp, een geladen spel) alles in één keer. In een binnenruimte staat het stil.
  Zonder camera (de tools) is niets buiten beeld, dus gaat er niets weg
  (`unseen_without_camera` zet dat aan voor een test).
- `whole_town` = true doet het zoals vroeger: `vehicle_count` + `services_count` over het hele
  wegennet (`traffic_seed`), allemaal gehouden; `tools/check/traffic_test.gd` gebruikt dat.
- Controle: `tools/check/crowd_test.gd` (aantallen om 13:00, 03:00 en 08:00, rust buiten de
  boom, een teruggezet voertuig rijdt, alles rond de speler na een sprong) en
  `tests/unit/test_crowd.gd` (de tabel). Soorten:

| Script | Model (`voertuigen/`) | Lengte | Massa | Koppel wielen |
|---|---|---|---|---|
| `hatchback.gd` | `auto_hatchback`, `_zilver`, `_groen` | 3,9 m | 1100 kg | 1155 Nm |
| `car.gd` | `auto_sedan`, `_wit`, `_zilver` | 4,5 m | 1300 kg | 1220 Nm |
| `trailer_car.gd` | `auto_hatchback_zilver` + `auto_trekhaak` + `auto_aanhanger` | 3,9 + 3,3 m | 1100 + 500 kg | 1155 Nm |
| `suv.gd` | `auto_suv` | 4,8 m | 2100 kg | 1575 Nm |
| `van.gd` (busje) | `auto_busje` | 5 m | 2400 kg | 1800 Nm |
| `truck.gd` (vrachtwagen met laadbak) | `auto_vrachtwagen` | 7 m | 7500 kg | 4875 Nm |
| `city_bus.gd` (stadsbus, mag op de busbaan) | `auto_stadsbus` | 10,5 m | 12000 kg | 6600 Nm |
| `police_car.gd` (politie) | `auto_politie` | 4,5 m | 1300 kg | 1500 Nm |
| `ministers_car.gd` (dienstauto kabinet) | `auto_dienstauto` | 4,5 m | 1900 kg | 1700 Nm |
| `riot_van.gd` (ME-busje) | `auto_politie_busje` | 5 m | 3200 kg | 2300 Nm |
| `ambulance.gd` | `auto_ambulance` | 5 m | 3500 kg | 2500 Nm |
| `fire_engine.gd` (brandweer) | `auto_brandweer` | 7 m | 14000 kg | 11000 Nm |
| `cyclist.gd` (fietser, 20 km/h, soort `fiets`) | fiets in code (`bicycle_parts.gd`) + `fiets_wiel` | 2 m | 95 kg | 36 Nm |
| `fatbike.gd` (30 km/h, soort `fiets`) | fatbike in code (`bicycle_parts.gd`) + `auto_wiel` | 1,9 m | 110 kg | 62 Nm |
| `moped.gd` (brommer, 45 km/h, soort `brommer`) | `brommer` + `brommer_wiel` | 1,8 m | 160 kg | 90 Nm |
| `scooter.gd` (45 km/h, soort `brommer`) | `scooter`, `_zwart` + `klein_wiel` | 1,8 m | 170 kg | 76 Nm |
| `motorbike.gd` (motorfiets, 130 km/h) | `motorfiets` + `auto_wiel` | 2 m | 300 kg | 450 Nm |
| `microcar.gd` (gehandicaptenauto/brommobiel, 45 km/h) | `gehandicaptenauto`, `_blauw` + `klein_wiel` | 2,5 m | 450 kg | 135 Nm |
| `tractor.gd` (trekker, 25 km/h) | `trekker`, `_rood` + `tractor_wiel` (achter) en `auto_wiel` (voor) | 3,75 m | 4500 kg | 2250 Nm |

De tweewielers zijn allemaal een `TwoWheeler` (`scripts/vehicles/two_wheeler.gd`) met een
berijder: een stadsbewoner (`scripts/world/townsfolk_figure.gd`, in code gebouwd uit voxels van
5 cm zoals de spelerfiguren, 1,75 m), zijn uiterlijk uit de `route_seed` (`rider_kind`: bloot
hoofd of pet op de fiets, open helm op brommer en scooter, integraalhelm en zwart leer op de
motor). Heupen op het zadel, handen aan de handvatten (het lijf leunt zo ver voorover als de
armen nodig hebben), voeten op de trappers of steunen; de benen buigen in de knie (twee-bot-IK).
- De fietsen (fietser, fatbike) worden in code gebouwd (`scripts/vehicles/bicycle_parts.gd`):
  frame, stuur (vork, voorspatbord, koplamp, stuurpen en stuur) en trapas (cranks en trappers)
  apart. Het stuur draait om de schuin naar achter staande balhoofdbuis met het voorwiel en de
  koplamp erin; de berijder trapt (de cranks draaien mee met het achterwiel, `PEDAL_GEAR`, en
  staan stil bij remmen en uitrollen) en zijn handen volgen het stuur. Kleuren en lage instap
  per fiets uit de seed. De oude tiles `fietser`, `_rood` en `fatbike` (met berijder erop)
  rijden niet meer mee.
- Brommer, scooter en motorfiets zijn tiles (`tools/voxgen/tiles/two_wheelers.py`) zonder
  berijder; `two_wheeler.gd` zet de stadsbewoner erop op zadel, voetsteunen en handvatten van
  die tile (`TwoWheeler.tile_point`).
- Alle tweewielers hellen in de bocht en sturen in: de helling begint al vóór de bocht
  (`LEAN_LEAD`, de bocht die het over 0,35 s rijdt) en om naar links te gaan hellen draait het
  voorwiel eerst even naar rechts (`countersteer`, `Vehicle._turn_wheels`).

De tiles van de tweewielers hebben voxels van 6,25 cm in plaats van 12,5 cm: de import-optie
`voxel_size` = 0,0625 in hun `<naam>.gox.import` (lijst `FINE_TILES`, ook `fiets_wiel` en
`brommer_wiel`; een nieuwe `.import` krijgt eerst de standaard 0,125, zet hem dan weer op 0,0625).
Materialen: frames, tanks, kappen en helmen gelakt (`painted`: `lak_*`, `bord_*`), chroom en
staal `metal` (`rvs`, `metaal*`), banden en zitjes mat (`opaque`), lampen en reflectoren
`emit` (`lamp_wit`, `signaal_rood`). Ze hebben een andere `vehicle_kind`: `fiets`
(fietser, fatbike) en `brommer` (brommer, scooter) mogen ook over de fietspaden die dat toestaan
(`RoadNetwork.allows`); motor en brommobiel zijn `auto`. Het voorwiel van brommer, scooter en
motor stuurt hooguit 15 graden, van de fietsen 25; fietsen hebben geen remlicht en
richtingaanwijzers.

Voetgangers (node `Voetgangers`, `scripts/world/pedestrians.gd` en `pedestrian.gd`):
stadsbewoners lopen over de stoep- en pleintiles (`stoep/`, `plein/`, zonder gebouw erop) in de
buurt van de speler, van cel naar cel, nu en dan even stilstaand; een plek waar ze niet in een
rechte lijn kunnen komen zonder tegen iets van de stad te lopen (lantaarnpaal, bank, boom)
kiezen ze niet. Ook dit is een set rond de speler: `count` (60) maal het aandeel van het uur en
de wijk (`data/drukte.json`), minstens `fewest` (6), hooguit `most` (84). Wie verder dan `reach`
(110 m) van de speler raakt, wordt iemand anders (`Pedestrian.become`: andere look, tempo,
hulpmiddel en tas, zelfde node) op een cel tussen `return_near` (50 m) en `reach`, buiten beeld.
Wie er `renew_after` (45 tot 110 s) rondloopt, buiten beeld is en verder dan `renew_beyond`
(30 m) van de speler, gaat ook: dan komt er iemand anders (of niemand, als er minder nodig zijn).
Wie niet nodig is rust uit de boom (`_resting`) tot er weer meer moeten. Per seconde hooguit
`changes_per_second` (3) wissels, na een sprong van de speler alles; in een binnenruimte staat
het stil. Wie er komt is een soort mens van dat uur en van de wijk waar hij verschijnt
(`Crowd.person_kind`): forenzen, kantoormensen en zakenmensen (in pak, met aktetas) in de spits,
scholieren na school, winkelend publiek, ouderen, toeristen (rolkoffer, rugzak) en wandelaars
overdag, werklui in geel in de Binckhorst, uitgaanspubliek 's avonds en nachtbrakers 's nachts;
gekleed als die soort (`Crowd.look_for`), op het tempo van die soort, met wat die soort draagt
(`CarriedItems`, `scripts/world/carried_items.gd`, als dat script er is). Een vast aandeel van
elke soort zit in een rolstoel of op een scootmobiel (`Pedestrians._aid_for`: geen toeval, het
aandeel komt precies uit), vooral ouderen. Wie doodgereden wordt, begint opnieuw als iemand
anders (`Pedestrians.start_again`). De lijst `TownsfolkFigure._parts` houdt hooguit `PARTS_KEPT`
(160) looks bij.

Bij een zebrapad (`weg/zebrapad`) steken ze recht over, haaks op de rijstroken: bij de
stoeprand claimen ze het zebrapad (de auto's stoppen ervoor, `Vehicle._someone_crossing`), ze
wachten zolang er een voertuig te dichtbij en te snel aankomt, en een auto die al gewacht heeft
rijdt pas door als er niemand meer op staat. Bij een kruising met voetgangerslichten
(`Verkeerslichten`, `pedestrian_phase`; `Pedestrians.walk_light`) wachten ze op groen zonder
het zebrapad te claimen (het verkeer met groen rijdt door) en claimen het pas als ze oversteken
(afslaand verkeer wacht dan). Voertuigen letten op mensen te voet (voetgangers en de speler, de
groep `lopers`, `Vehicle._watch_people`): ze kijken hun remweg plus 2,5 s vooruit, remmen tot
2 m voor iemand op hun pad, wijken (niet op rails) tot 0,9 m uit voor iemand aan de rand van
hun pad en waarschuwen met hun toeter: `auto_toeter`, `bus_toeter` (bus en vrachtwagen, boven
3500 kg), `brommer_toeter`, `fiets_bel` (fiets, fatbike), `tram_bel`, `trein_hoorn`,
`brandweer_hoorn` (`horn_sound` of `_horn()`), als iemand binnen 2,5 s op hun pad is of na 3 s
nog in de weg staat, hooguit elke 5 s. Controle: `tools/check/people_traffic_test.gd`. Een deel
zit in een rolstoel of op een scootmobiel (zie hierboven; `Pedestrian.mobility`, `scripts/world/mobility_aid.gd`, in code
gebouwd in voxels, de berijder een zittende stadsbewoner): ze rijden de kant op waar ze naar kijken en
draaien hooguit `TURN_RATE` per seconde; de wielen zijn de wielmodellen van de voertuigen
(`fiets_wiel`, `klein_wiel`, verkleind) en draaien via de wielshader (`voxel_wheel.gdshader`,
`roll`), de zwenkwieltjes van de rolstoel draaien om hun staande as achter de beweging van hun
punt aan, het voorwiel van de scootmobiel stuurt met de stuurkolom in (de handen gaan mee). De
scootmobiel mag ook over de fietspaden (`Pedestrians.may_use`: cellen waar fietsen mogen en
auto's niet) en toetert (`scootmobiel_toeter`) als iemand voor hem blijft staan. De botsvorm
omvat stoel en berijder. Controle: `tools/check/mobility_test.gd`.

Drukte (`data/drukte.json`, gelezen door `scripts/world/crowd.gd`, uitgelegd in
`data/LEESMIJ.md`): één tabel voor wanneer en waar het druk is en met wie.
- `uren`: momenten van de dag (`uur`) met het aandeel voetgangers en verkeer (`voetgangers`,
  `verkeer`; 1 = `count` en `vehicle_count`), de gewichten van de soorten mensen (`mensen`) en
  van de voertuigsoorten (`voertuigen`). Tussen twee momenten loopt het geleidelijk over, ook
  rond middernacht. Nu: 's nachts 0,08 tot 0,22, spits (7:30 en 17:00) 1,0, overdag 0,75 tot
  0,9, 's avonds 0,4 tot 0,7.
- `gebieden`: per wijk (de namen van de metadata `wijken`, zoals de HUD ze toont) een factor op
  voetgangers en verkeer en andere gewichten. Nu: Centraal Station 1,4 voetgangers / 1,1 verkeer
  (forenzen, zakenmensen, bussen, fietsers), Centrum en Grote Markt druk met voetgangers en
  fietsers, De Resident en Beatrixkwartier kantoormensen en auto's, Malieveld en Koekamp (het
  Haagse Bos) wandelaars en weinig auto's (0,4), woonwijken rustiger (0,6 tot 0,9), Binckhorst
  weinig voetgangers (0,5) maar drie keer zoveel vrachtverkeer en werklui, de A12 1,4 verkeer met
  vooral auto's en vrachtwagens en bijna geen voetgangers (0,3).
- `voertuig_basis`: het aandeel van elke voertuigsoort vóór uur en wijk.
- `mensen`: per soort mens de kleuren (`jassen`, `broeken`, `schoenen`, `haarkleuren`), de
  kapsels (gewichten), de kans op een rok, het `tempo`, het aandeel in een `rolstoel` en op een
  `scootmobiel`, wat ze dragen (`dragen`, gewichten, `""` is niets) en `pak` (in pak, via
  `CarriedItems.business_look`). De kleuren van kantoormensen (`#22242A`, `#6A6E74`) en toeristen
  (`#C8B48A`) zijn die waaraan de gesprekken hun persoon herkennen (`ambtenaar`, `toerist`).
De meters van de HUD (`scripts/ui/widgets/segment_bar.gd`) laten zien dat ze veranderen,
zonder te bewegen: wat een klap eraf haalt blijft even rood-oranje staan (knipperend, 0,45 s)
en loopt dan leeg naar het nieuwe niveau; een kleine daling (honger) laat het randsegment
knipperen; een sprong omhoog (eten, xp) laat de gewonnen segmenten oplichten, langzaam
bijvullen niet. Het getal ernaast licht kort op (rood bij omlaag). Controle:
`tools/check/segment_bar_test.gd`. Er zijn geen randjes om dingen of figuren. De speler en de voetgangers hebben een zachte
donkere vlek op de grond recht onder zich (`scripts/effects/ground_shadow.gd`, een Decal), zodat
ze van elke kant loskomen van de straat; de figuren zelf staan op visuele laag 2
(`FIGURE_LAYER`), waar die vlek niet op valt. In de stad zijn de figuren eenvoudiger dan op het
karakterscherm (`PlayerModel.simple`, `VoxelFigure.simplify`): bijna gelijke kleuren worden
één kleur en losse spikkels (knopen, steken, vlekjes) nemen de kleur eromheen aan; de vorm en
de ogen blijven. Controle: `tools/check/simple_figure_test.gd`. De bio op het
karakterscherm typt zich uit met de blokcursor, zoals het verhaal (`widgets/typewriter.gd`).
Buiten beeld kosten ze minder CPU-tijd (`scripts/world/sight.gd`): wat in beeld is (met 30 %
marge rond het scherm) doet elke physics-stap, wat erbuiten is om de 2 stappen en wat ook nog
verder dan 150 m van het kijkpunt (of 300 m van de camera) is om de 4, telkens met de tijd van
alle overgeslagen stappen; dan draaien ook wielen, trappers en ledematen niet mee. Voertuigen
(`vehicle.gd`) en voetgangers (`pedestrian.gd`) kijken elke 15 stappen opnieuw waar ze zijn, elk
op een eigen moment. Controle: `tools/check/sight_test.gd`. Elke voetganger heeft een botsvorm zo groot als de
figuur (`Botsvorm`), net als de speler: de speler loopt er niet doorheen en wrakken botsen erop.
De spelerfiguur staat in de stad op 0,78 (`PlayerController.FIGURE_SCALE`, ongeveer 1,75 m, Willem
krom 1,55 m), zodat spelers, voetgangers, berijders en voertuigen in verhouding zijn; de
schermen (portret, karakterkeuze) tekenen hem op ware grootte. Controle:
`tools/godot.sh --headless --script tools/check/townsfolk_test.gd` (maten, trappen, sturen,
insturen, handen en voeten, voetgangers, zebra en alle botsvormen).
De trekker heeft grote achterwielen (`wheel_model`/`wheel_radius` van `Vehicle`) en kleinere
voorwielen (`front_wheel_model`/`front_wheel_radius`: elk voertuig kan voorwielen van een andere maat
krijgen; die rollen in hun eigen tempo).

Hulpdiensten (`emergency`: politie, ME, ambulance, brandweer; modellen in
`tools/voxgen/tiles/emergency_vehicles.py`, met de Nederlandse striping en een lichtbalk; de ME-busjes donkerblauw (`lak_blauw`) met
wit-oranje striping tussen witte lijnen) hebben
een sirene (zonder geluid; de enige audio is de muziek van intro en menu en de menugeluiden) en blauwe zwaailichten (`beacon_positions`: links en rechts om beurten, met een blauw
licht op de omgeving). Ze gaan vanzelf aan en uit (`siren_duty`, `SIREN_ON_SECONDS`,
`SIREN_OFF_SECONDS`), met `set_siren`/`toggle_siren`, of met S terwijl de volgcamera het voertuig
volgt. Met de sirene aan (`has_priority`) rijdt het `EMERGENCY_SPEED_FACTOR` (1,4×) de limiet,
door rood en langs zebra's, en geeft het alleen voorrang aan een andere sirene, een tram of trein,
of wie al niet meer kan stoppen (`COMMITTED_SECONDS`). Het andere verkeer houdt er rekening mee:
op een kruising geeft iedereen voorrang aan een sirene die er binnen `PRIORITY_CLAIM_SECONDS`
is; wie ervoor rijdt (`SIREN_HEARD`) gaat naar een vrije strook ernaast met dezelfde richting,
of gaat rechts aan de kant (`yielding`, `YIELD_OFFSET`) en staat stil als de sirene vlak achter
hem is, tot die voorbij is (hooguit `YIELD_LONGEST` s). De sirene gaat er links langs
(`PASS_OFFSET`) als er geen tegenligger aankomt. Trams en treinen wijken niet (`makes_way`).

Allemaal zijn het een `Vehicle` (`scripts/vehicles/vehicle.gd`):
- Gewicht en koppel (`mass_kg`, `wheel_torque`): een zwaar voertuig heeft van allebei meer.
  Koppel gedeeld door wielstraal en massa geeft de acceleratie (een aanhanger telt mee). Bij
  een botsing delen de massa's de klap volgens de impuls: de lichtste krijgt de grootste
  snelheidsverandering en de meeste draaiing. Daarna rolt een wrak nog even door op zijn wielen
  met de motor aan (`ROLL_ON_*`), een bus veel langer dan een kleine auto, dus een bus duwt een
  hatchback voor zich uit. Test: `tools/check/crash_test.gd -- heavy` of `light`.
- Aanhanger (`trailer_model`, `hitch_position`): hij draait om zijn eigen punt, de bol van de
  trekhaak. Elke stap wordt zijn as recht naar de bol getrokken, zodat hij de bocht afsnijdt
  zoals een echte aanhanger, met eigen wielen en lampen. Bij een botsing blijft hij aangekoppeld
  aan het wrak.
- Route: bij een splitsing kiest een auto liever een weg die hij de laatste tijd niet
  heeft gereden (`variety`), zodat hij de hele stad doorrijdt in plaats van steeds
  hetzelfde rondje. Op een kruising slaat hij hooguit één keer af, en nooit terug waar
  hij vandaan kwam (geen U-bocht over een brede kruising).
- Rijden: gas geven en remmen bouwen geleidelijk op (`throttle_rate`, `brake_rate`).
- Sturen: een voertuig draait om zijn achteras. De vooras volgt de route met afgeronde
  bochten (`_corner_rounding`: hoe langer de wielbasis, hoe ruimer), de achteras wordt recht
  naar de vooras getrokken en snijdt de bocht dus af, en de carrosserie ligt op de lijn
  ertussen. De voorwielen wijzen waar de vooras echt heen beweegt. De aanhanger volgt op
  dezelfde manier: zijn as wordt naar de trekhaak getrokken. Treinen en trams rijden met
  elke wagon op twee draaistellen.
- Ramen: elk voertuig krijgt dezelfde glasinstellingen (`_tint_windows`): donker getint, met een
  gesimuleerde weerspiegeling van lucht en gebouwen die tijdens het rijden over het glas schuift
  (`passing_surroundings`, `pane_lean` in `voxel_glass.gdshader`; sterkte `reflection`).
- Buitenmaten: voor anderen en bij een botsing telt alles wat op een voertuig getekend is
  (carrosserie, wielen, trekhaak, lampen; `_outer_box`), ook bij aanhanger en wagons. Als
  wrak heeft de aanhanger een eigen collider die hem volgt.
- Elkaar ontwijken (`avoids_others`): een auto remt en stopt achter een andere auto op
  zijn route (tot 40 m vooruit), en geeft op een kruising voorrang aan wie er eerder is.
- Botsen: rijden twee auto's toch met minstens `CRASH_SPEED` (5 m/s) op elkaar in, dan worden
  het allebei een `RigidBody3D` (`Wrak`, met hun massa); een schampje in een bocht telt niet. Ze botsen met physics tegen elkaar en tegen de colliders van
  de stad (stoepranden, middenbermen, gebouwen en props in de GridMaps), maken een sprongetje,
  kantelen naar de kant waar ze heen geduwd worden (`CRASH_HOP`, `CRASH_TILT`), tollen en
  schuiven uit, met de alarmlichten aan. Er vliegen voxel-scherven (lak, glas, plastic) en een
  stofwolk uit (`scripts/effects/crash_burst.gd`) en de volgcamera schudt (`crash_shake`). Na
  8 s worden ze weggesleept naar de dichtstbijzijnde vrije plek op de rijstrook en rijden ze verder.
- Vastlopen: wachten voertuigen in een kring op elkaar (niet in de rij voor een stoplicht of
  zebra), dan wringt er na een tijdje één langs de ander (`SQUEEZE_TIME`): eerst negeert hij
  alleen de cellen die de anderen claimen en blijft hij achter de carrosserie vóór hem. Kwam hij
  zo niet verder (`SQUEEZE_IN_VAIN`), dan rijdt hij de volgende keer door de anderen heen.
- Verdwaald: keert een voertuig twee keer in zijn eigen rijstrook om (er is geen rijstrook
  terug ernaast) zonder tussendoor een kruising te halen, dan rijdt het alleen nog heen en weer.
  Zodra het buiten beeld is (of na `LOST_SECONDS`) wordt het op een vrije rijstrook elders
  neergezet. Over een kruising kijkt het ook naar afslagen (`_leads_on`): een T-splitsing
  waar rechtdoor ophoudt, is geen doodlopende weg.
- Buiten beeld (`unseen`: meer dan `UNSEEN_MARGIN` buiten het scherm, of verder dan
  `UNSEEN_DISTANCE` van een perspectiefcamera) rekent een voertuig maar elke tweede physics-stap
  (met de tijd van beide) en slaat het wielen en lampen over.
- Een sirene die inhaalt, blijft naast de auto die voor hem opzij ging tot hij erlangs is
  (`_beside_yielder`), ook als er tegenverkeer aankomt.
- Test op door elkaar heen rijden: `tools/godot.sh --headless --script
  tools/check/overlap_test.gd -- 300` meldt elke overlap van twee rijdende carrosserieën met de
  situatie erbij (`TRACE=Verkeer4,Verkeer9` volgt ook voertuigen per halve seconde).
- Bochten: alle bochtsnelheden (`corner_speed`, `tight_corner_speed` per type) keer
  `CORNER_SPEED_FACTOR` (1,6), zodat de verhoudingen tussen de typen blijven.
- Tweewielers (`leans`: motor, brommer, scooter, fiets, fatbike) hellen de bocht in, zo ver als
  snelheid en bocht vragen (`atan(v · draaisnelheid / g)`, hooguit `max_lean_degrees`: motor 28°,
  brommer en scooter 22°, fietsen 15°), geleidelijk (`LEAN_RATE`).
- De voorwielen sturen hooguit 40° (`max_steering_degrees`): een wiel steekt dan wat uit de
  wielkast, net als bij een echte auto.
De camera volgt de speler (node `Volgcamera`, `scripts/camera/follow_camera.gd`, `target` = `../Speler`).
Hij jaagt de speler niet zelf na, maar een punt dat doorlopend vóór hem ligt: waar hij over
`lead_time` seconden is bij zijn gladgestreken snelheid (`velocity_smoothing`, begrensd
tot `max_lead` van het beeld). Daar volgt hij op een kritisch gedempte veer
(`glide_time`), zodat de camera bij een constante snelheid even gelijkmatig meebeweegt
en bij optrekken en remmen geleidelijk meegaat.
Hij zoomt van 18 m in beeld bij stilstand (`zoom_still`, dichtbij: de figuur goed te zien)
via 38 m bij lopen (`zoom_walk` bij `walk_pace`, 3 m/s) tot 44 m bij rennen (`zoom_fast`,
`fast_speed`). Bij de start van het spel (zodra het laadscherm weg is) komt hij hoog uit de
lucht naar de speler toe (`arrival`: van 300 m in beeld naar `zoom_still` in 8 s; de speler slaapt door tot hij beneden is, pas
dan wordt hij wakker en begint het verhaal), dwars door
een wolkenlaag van vierkante voxelblokken (`scripts/effects/cloud_shroud.gd`/`.gdshader`: twee
lagen losse blokken die vanuit het midden groeien, bovenkant licht, de zijkant eronder
donkerder; het dikst bovenin, waar hij begint (hooguit ongeveer de helft van het beeld), en
steeds dunner naarmate hij zakt, weg op 60 % van de afdaling; in de wolken gaat de camera op
ruim een derde van zijn snelheid, `ARRIVAL_CLOUD_SPEED`, en vanaf 70 % (`ARRIVAL_SETTLE_FROM`) loopt
hij zacht uit tot stilstand bij de speler; 's nachts donker blauwgrijs); een dramatisch moment breekt de afdaling af.
Controle: `tools/check/arrival_test.gd`. Hij gaat mee de tunnelbak in: gaat de speler onder iets door, dan zakt de camera in
de open bak erachter en volgt als achtervolgcamera (`tunnel_*`; de tunnel heeft eigen lampen,
node `Tunnelverlichting`). Close-ups kunnen nog (`closeups`, standaard uit). Springt het doel
(opstaan na een aanrijding), dan glijdt het beeld er in `switch_time` s heen. Er zijn geen
debugtoetsen meer (geen ander voertuig volgen, geen tijd versnellen, geen demo-botsing; die
zit alleen nog in `tools/check/crash_test.gd`). De auto rijdt met een vaste
stap van 60 Hz; zijn carrosserie (node `Carrosserie`) wordt elk frame tussen de laatste
twee stappen gezet, zodat hij bij elke framerate vloeiend beweegt.
- Doorkijk (node `Doorkijk`, `scripts/world/building_fade.gd`): zolang de camera de speler
  volgt, krijgt elk gebouw (aaneengesloten cellen van de laag Gebouwen) dat tussen de
  speler en de camera staat een rond kijkgat (`hole_radius`, 3,5 m): een buis van de speler
  naar de camera, met een geditherde rand; alleen wat aan de camerakant van de speler ligt
  wordt weggesneden, de rest van het gebouw blijft staan. Het gat gaat open en dicht in
  `fade_time`. Middelpunt en straal staan in de laatste rij van de fade-kaart. Alles wat
  uit hun cel steekt (erkers, winkelpuien, luifels) en hun gevel-details vervaagt mee: de
  samengevoegde gebouwen dragen per vertex de cel waar ze bij horen (`layer_baker.gd`,
  CUSTOM0) en de shader kijkt die cel op in een fade-kaart (`voxel_fade.gdshaderinc`).
  Objecten op straat (props: bushokjes, lantaarnpalen, bomen) vervagen niet.
  Getest wordt vanuit een vierkant rond het gevolgde in beeld: `test_reach` (3 m) rond een
  voertuig, `walker_reach` (0,5 m) rond iemand te voet, zodat een gevel waar je naast staat
  (die alleen de ruimte naast je in beeld bedekt, niet jezelf) blijft staan.
  Viaducten vervagen ook: elke kolom van de laag Grond met een cel vanaf `deck_level` telt als
  een eigen klein gebouw, dus alleen het stuk dek boven het voertuig gaat open. Een dek vervaagt
  alleen als het minstens `deck_clearance` boven het voertuig ligt.
  Alleen wat vervaagt krijgt een shadervariant die pixels weglaat (`ZWERVR_FADE`): zo'n
  shader is op een Apple-GPU flink trager. Instelbaar: `fade_time`, `strongest_fade`,
  `test_reach`.
- Details (laag `Details`): je bouwt ze als losse laag, maar `DetailNiveau` bakt ze bij het
  laden in dezelfde stukken als de gebouwen (`merge_with`), ook per LOD-niveau. Dat
  scheelt een laag tekenen en draw calls, en elk detail vervaagt met zijn eigen gebouw.
- Lampen (`vehicle.gd`, posities in het script van elk voertuig): koplampen met een lichtbundel op de weg
  zodra het donker wordt (`night` van de `Dagcyclus`), achterlichten 's nachts, felle
  remlichten bij afremmen en stilstaan, en richtingaanwijzers die knipperen vanaf 30 m
  voor een afslag op een kruising, voor het invoegen in een andere rijstrook en voor
  keren (niet in gewone bochten van de weg).
- Ruiten: donker getint glas dat de lucht spiegelt, sterker naarmate je er schuiner op
  kijkt, met een scherpe zonneglinstering (`voxel_glass.gdshader`: `reflection`,
  `depth`, `glint_roughness`), en lichtstrepen die vast op de auto liggen
  (`streaks_on_object`): de strepen van gebouwglas liggen vast in de wereld en zouden
  bij een rijdende auto steeds over de ruit schuiven.
- Wielen: het wielmodel draait zelf niet; `voxel_wheel.gdshader` tekent band, velg en
  spaken en draait de spaken mee (`roll`). Bij hoge snelheid vervagen ze tot een
  draaiwaas, anders lijken ze stil te staan of achteruit te draaien. De voorwielen sturen
  mee in de bocht.
- Beeld: harde zonneschaduwen (`shadow_blur` 0,1), grasprieten pas onder 24 m in beeld. De
  schaduwafstand verandert alleen in stappen (`SHADOW_DISTANCE_SLACK` in
  `level_of_detail.gd`), anders kruipen de schaduwranden bij een zoomende camera.
  Gevels met ramen werpen een gevuld blok als schaduw, iets achter de gevel, dus zonder
  schaduwen van ramen en kozijnen (`filled_shadow_layers`, `layer_baker.gd`). Platte
  gevelonderdelen werpen niets; balkons, luifels, dakdetails en vlaggen wel (`SHADOW_DETAILS`).
- Wegennet (`scripts/traffic/road_network.gd`, `RoadNetwork`): het wegennet leest de
  rijstroken uit de grondtiles zelf. Dat werkt op elke kaart, ook als je hem met de hand
  bouwt. Elke tile waarop gereden wordt, heeft in zijn `.tile.json` een blok `traffic`,
  naast `id` en `materials`:

      "traffic": {"lanes": ["N"], "road": "straat", "rise": 1.0, "only": ["bus"]}

  `lanes` geeft de rijrichtingen ten opzichte van de tile zoals hij onverdraaid ligt
  (`N` = naar de achterkant van de tile). Ze draaien mee met de cel: draai je een tile
  in de editor, dan draait de rijrichting mee. Eén richting op een as is een rijstrook.
  Beide richtingen (`["N", "S"]`, of alle vier) betekent dat de tile zelf geen richting
  heeft, zoals een kruising, kaal asfalt, een zebrapad of de tunnel-tiles. De richting
  volgt dan uit de weg eromheen: de dichtstbijzijnde rijstrook met een richting op
  dezelfde lijn, anders de stroken ernaast, anders rechts rijden langs de rand. `road`
  is het soort weg, en daarmee de maximumsnelheid (`SPEED_LIMIT_KMH`, voor auto's: straat en
  hoofdweg 50, tunnel 80, snelweg 100 km/u). Zonder `road` (markeringen, kruisingen)
  neemt de tile het soort weg van zijn buren over. `rise` is hoeveel meter een helling
  naar zijn achterkant stijgt. `only` zijn de voertuigsoorten die er mogen rijden
  (busbaan, trambaan). De generator schrijft deze blokken (`tools/voxgen/traffic.py`,
  één regel per groep tiles; `generate.py --meta` werkt ze bij, ook voor aliassen). De
  bibliotheekbouwer zet ze per item op de MeshLibrary (meta `traffic`).
- Bovenleiding (node `Bovenleiding`, `scripts/world/overhead_lines.gd`): een rijdraad boven
  elk tram- en treinspoor, gemaakt uit de `rails` van de grondtiles, dus ook op een kaart die
  je met de hand bouwt. Hij volgt het spoor door bochten, over kruisingen en wissels en
  hellingen op en af. Vanaf elke bovenleidingmast in de props (`ov/tram_bovenleiding_mast`,
  `ov/tram_bovenleiding_dubbel`, `spoor/bovenleidingmast`) loopt een dwarsdraad over de
  sporen aan de kant waar ze liggen, met een hanger naar elke rijdraad. Zoals bij een echte
  bovenleiding blijft de rijdraad zelf waterpas, zodat de pantografen hem overal raken;
  erboven hangt een draagkabel (`carrier_rise` boven de rijdraad bij een dwarsdraad) die
  tussen de dwarsdraden doorhangt (`sag` over `typical_span`, dieper bij een langere
  overspanning), met elke 3 m een hanger naar de rijdraad. Onder een gebouw over het spoor
  loopt alleen de rijdraad door. In tunnels komt geen draad, op de open hellingen ervoor wel.
  De trams en treinen hebben een eenarmige pantograaf (`tools/voxgen/tiles/rail_vehicles.py`,
  `pantograph`): de RandstadRail op het achtereind van elke kopwagen (samen in het midden
  van de tram), de NS-trein op de middelste wagen. Het sleepstuk ligt precies onder de
  rijdraad (`TRAM_PANTOGRAPH_TOP`, `TRAIN_PANTOGRAPH_TOP`); verander je de draadhoogte, pas
  die dan mee aan. Ver uitgezoomd
  (`shown_until`) verdwijnen de draden. In de editor werken ze zich binnen een seconde bij.
  De arm van een masttile ligt langs zijn x-as: in de bouwer zet `MAST_ARM_ROTATION` de
  kant waar de arm heen wijst om in een draaiing.
- Rijrichtingen in de editor: de node `Rijrichtingen` (`scripts/traffic/lane_arrows.gd`)
  tekent in de editor een pijl per rijstrook op het wegdek. Geel is de richting van de
  tile zelf, lichtblauw is afgeleid uit de omgeving, magenta betekent nog beide kanten
  op (niet te bepalen), groen is met de hand gekozen voor deze tile (richtingen, wie er mag komen of de snelheid). Na het plaatsen of
  draaien van tiles of het kiezen van richtingen werkt hij zich binnen een seconde bij. In het spel verwijdert de node zichzelf. Instelbaar: `show_arrows`,
  `through_walls`, de kleuren.
- Auto's, busjes, vrachtwagens en bussen kiezen nooit een richting die naar een cel leidt
  waar ze niet mogen komen (ook niet over een kruising heen: `_leads_on` in `vehicle.gd`),
  zoals het plein van de Grote Marktstraat of een tramhelling: anders zouden ze op de
  kruising moeten keren en elkaar vastzetten. Trams en treinen volgen hun rails tot het eind.
- Verkeer per tile: elke grondtile zegt zelf wie erop mag komen en hoe hard, in `traffic`
  van zijn `.tile.json`: `only` is een lijst van `auto` (ook busjes, vrachtwagens en
  bussen), `brommer`, `fiets` en `voetganger`, voor een baan alleen `bus` of `tram`. `speed`
  is de limiet in km/u, in plaats van die van `road`. De regels per groep tiles staan in
  `tools/voxgen/traffic.py` (daarna `generate.py --meta` en `build_libraries.gd`). Een tile
  zonder `traffic` (water, kademuur) is voor niemand. Parkeerstroken en parkeervakken langs
  de weg (`parkeerstrook`, `parkeervak_gehandicapt`) hebben wel `traffic` maar geen `lanes`:
  er staan auto's, er rijdt niemand overheen.
- Per geplaatste tile kun je daarvan afwijken: in het Build-paneel, onder `Traffic`, zet je
  `Pick tile` aan en klik je een grondtile aan in de 3D-view (nog eens klikken = de tile
  eronder, bijvoorbeeld een tunnel; Esc stopt). Ctrl+Z werkt voor elke wijziging.
  - Richtingen: `Forward`, `Left`, `Right` en `Back` los aan of uit, in elke combinatie:
    alleen links, rechtdoor en rechts, alleen achteruit. De kanten staan als labels op de
    tile in de 3D-view en draaien mee met de tile. `Automatic` haalt de keuze weg. Een
    voertuig verlaat de tile alleen in een gekozen richting, waar het ook vandaan komt.
  - Wie: `Auto`, `Brommer`, `Fiets`, `Voetganger`; alles uit sluit de tile af, `Tile default`
    haalt de keuze weg. Auto's mogen standaard op fietsstroken en fietsstraten; een autovrije
    fietsstraat maak je door per tile `Auto` uit te zetten. Een voertuig dat er niet op mag, rijdt om, voegt in of keert. Nu
    rijden alleen auto's en bussen over het wegennet: voor de andere drie wordt de keuze
    bewaard (`RoadNetwork.allows`), maar die heeft nog geen effect.
  - Snelheid: `Speed limit` in km/u (5 tot 130), `Tile speed` haalt de keuze weg. Tiles
    zonder eigen limiet (markeringen, kruisingen) nemen die van de weg ernaast over, dus
    ook een gekozen limiet.

  De keuze staat in de scène (meta `lane_choices` op `Grond`) en blijft bewaard als je de
  stad opnieuw bouwt, zolang dezelfde tile in de cel ligt.
- Hoeken op het raster: waar rechte wegen haaks op elkaar aansluiten, buigt de belijning mee
  met `<rechte tile>_hoek_rechts` en `_hoek_links`, in dezelfde map als de rechte tile
  (`tools/voxgen/tiles/ground_corners.py`). Ze zijn er voor de rijstroken, fietsstrook,
  fietsstraat, busbaan, tram (de rails buigen mee), snelweg en het fietspad naast de weg. De
  tile komt binnen aan de voorkant en gaat er rechts of links uit, dus er rijdt verkeer
  overheen zonder dat het een kruising is. Een weg van n stroken beslaat n x n cellen: elke
  strook slaat af op de diagonaal, de andere cellen zijn gewone rechte tiles. Bij een
  tweerichtingsweg:

      rijstrook_geen_kant                      rijstrook_geen_kant_hoek_links  (buiten)
      rijstrook_onderbroken_kant_hoek_rechts   rijstrook_geen_kant

  De middenstreep buigt in de binnenste cel, dus de rechte tiles ernaast hebben die streep
  niet. Heeft een strook geen versie zonder streep, dan is er een `_zonder_streep`
  (busbaan, snelweg). De stadsbouwer legt ze zelf waar een tweestrookstraat de hoek omgaat
  (`_square_corners` in `city/streets.gd`). Test: `tools/godot.sh --headless --script
  tools/check/corner_test.gd`.
- Voertuig (`scripts/vehicles/vehicle.gd`, `Vehicle`): de rijlogica voor elk
  voertuig. Het plant een paar cellen vooruit (minstens de remafstand), kiest op
  kruisingen willekeurig (`straight_chance`, `route_seed`) en remt af voor bochten
  en een lagere maximumsnelheid (die het `LIMIT_LEAD` seconden rijden vóór het begin
  ervan al haalt, omdat zijn snelheid de toegestane een halve seconde volgt). Het stopt voor zebrapaden en rode lichten, voegt
  geleidelijk in waar een rijstrook ophoudt en keert op doodlopende wegen. Waar de
  kaart een uitvoegpunt heeft (meta `move_overs` van Grond, `{van cel: naar cel}`,
  `RoadNetwork.MOVE_OVERS`) schuift het geleidelijk naar de strook ernaast: als keuze
  (zoals afslaan, `straight_chance`) waar zijn eigen strook doorloopt, altijd waar die
  daar ophoudt. Zo nemen auto's de afritten van de A12. Het kiest geen vak waarna alleen
  de weg terug overblijft (`_only_back_after`). Het rijdt
  over het wegdek, ook op hellingen, en kantelt mee. Wielen
  (`wheel_model`, `wheel_positions`) rollen mee en de voorste sturen in. Een nieuw
  voertuig maak je door van `Vehicle` af te leiden en in `_init` model, wielen,
  snelheden en `vehicle_kind` te zetten (zie `car.gd`); met de hooks `_may_use`, `_choose_heading` en
  `_must_stop` pas je aan waar het mag rijden en waarvoor het stopt.
- Modellen: `props/voertuigen/` (carrosserieën zonder wielen, `auto_wiel` en
  `auto_wiel_groot`). Vanuit `tools/voxgen/tiles/props.py`. Overzicht:
  `tools/godot.sh --script tools/shots/shot_vehicles.gd -- <uit.png> [1|-1] [nummer]`.
- Test van al het verkeer samen (botsingen, vaststaan, rekentijd):
  `tools/godot.sh --headless --script tools/check/traffic_test.gd -- 300`
- Intro (startscène `scenes/intro.tscn`, `scripts/ui/intro.gd`): op zwart een teal regel ("Niet
  zo lang geleden, kortgeleden, recent en laatst…", `OPENING_LINE`), dan met een klap sterren en
  het logo ZWERVR in grote amberkleurige omlijnde letters dat even blijft staan (`LOGO_HOLD`) en dan langzaam de diepte in krimpt, dan
  het verhaal (`STORY`) dat in amber schuin wegrolt de verte in (op de muziek, `CRAWL_CUES`; de tekst
  in een eigen SubViewport, door een shader in perspectief gelegd), dan het hoofdmenu
  (al op de achtergrond geladen): het beeld fadet in 2,4 s naar zwart met een trackingstoring
  (`FADE_TO_MENU`) en het menu komt daar in 3,5 s uit omhoog (`UP_FROM_BLACK`), terwijl de
  muziek van intro naar menu overvloeit. Alleen de spatiebalk breekt hem af en gaat naar het
  hoofdmenu (andere toetsen, zoals de volumetoetsen, en de muis doen niets). Rechtsonder staan, zoals in het hoofdmenu en het karakterscherm, de toetsen
  op één regel: "[SPATIE] OVERSLAAN  [ENTER] SNELLER". De sterren fonkelen. Muziek: `assets/audio/muziek/zwervr_intro.ogg` (128 BPM, 64 maten van 1,875 s, 120 s, geen lus); de intro loopt op die
  muziek (de klok is waar de muziek is): het logo fadet in van 5 tot 6,0 s, heel groot, bijna buiten
  beeld, en krimpt langzaam naar zijn normale formaat tot de drop (maat 9, 15,0 s):
  daar wijkt het in 2,5 s de diepte in en fadet het daarbij uit (`LOGO_SECONDS`), met een
  plop (`UiSounds` "plop") als het verdwijnt, en komt de tekst op, de
  zwerver op het gevechtshoogtepunt (maat 25, 45,0 s), de handhavers op het duel (maat 41, 75,0 s), de
  winkelwagen op de systeemcrash (maat 57, 105,0 s: de band stopt, één harde klap, daarna de outro), het menu waar de muziek sterft (120,0 s; `LINE_IN_AT` …
  `END_AT`, `CRAWL_CUES`). Zo traag als de muziek toelaat: weinig ruimte tussen de alinea's
  (`PARAGRAPH_GAP`), en de laatste alinea rolt niet van boven weg maar komt in de verte tot
  rust (`CRAWL_REST`) terwijl het verhaal de laatste `CRAWL_FADE` s uitfadet. Bij het einde of overslaan loopt de muziek door in het menu en
  fadet daar in 2 s uit, terwijl de menumuziek infadet. Met het CRT-beeld en dezelfde storingen als het menu
  (rollende band, VHS-tracking; `CrtDisturbance`). De hele intro duurt zo lang als de muziek: 120 s. Test: `tools/check/intro_test.gd` (met `-- volledig`:
  de hele intro, met de gemeten duur).
- Karakterscherm (`scenes/karakter.tscn`, `scripts/ui/character_creation.gd`): een eigen stap
  tussen NIEUW SPEL en de stad, in dezelfde stijl (nachtlucht met sterren, geen stad erachter,
  CRT-beeld). De archetypes staan in `scripts/player/player_character.gd` (`ARCHETYPES`: bijnaam,
  ondertitel met hun kracht, moeilijkheid 1-5, startlevel, eventueel een eigenschap die alleen
  zij hebben (`perk`), een kort verhaal en de stats; 100 is gewoon; de verslaving staat erin
  voor het spel maar niet op het scherm):
  Jos ("de ijzeren maag": leven 70, stamina 60, honger 140; moeilijk), Martin ("de renner":
  100, 150, 70), Ufo Piloot ("de onverwoestbare": 150, 60, 70), Willem ("de oude rat": overal
  80, maar level 3), Sjaan ("de toiletjuffrouw": 90, 110, 90; begint met € 25 op het schoteltje,
  `start_money`, die de HUD als geld zet; makkelijk) en
  Gerrit ("de visser": 120, 80, 120; kan vissen in de grachten).
  Links de lijst: alle zes precies verdeeld over de hoogte van het detailpaneel (hele pixels,
  `ENTRY_GAP`; pas onder `ENTRY_LOWEST` per regel zou hij scrollen), per regel een thumbnail van
  het gezicht, de naam, de ondertitel en het level; de gekozen in amber, de andere grijs. Rechts
  de gekozen in het groot: het hele poppetje in 3D dat op de plaats loopt (`walking`, `WALK_IN`)
  en langzaam om zijn as draait (`SPIN`; bij elke keuze begint het meteen te draaien, steeds van
  voren af aan), rechtsboven de moeilijkheid (MOEILIJKHEID, vijf blokjes van groen naar rood en de
  naam), de naam, de ondertitel, het level, de eigenschap ("EXTRA", teal), het verhaal en de
  stats als segmentbalken van de HUD (aandeel van `STAT_CEILING`). Pijltjes of 1-9 kiezen, Enter
  of BEGIN begint, Esc gaat terug naar het hoofdmenu; met de muis kiest een klik, nog een klik op
  de gekozen begint. De keuze blijft bewaard in `PlayerCharacter.chosen_id` (een statische
  variabele) en de HUD neemt die over: het portret linksboven (het gezicht in 3D), de naam, het
  level, het geld en het maximum van de stats.
  De poppetjes (`scripts/player/player_model.gd`) zijn allemaal zwervers (versleten kleren,
  hun spullen bij zich) en worden in code uit voxels van 0,0625 m gebouwd (geen geïmporteerde
  tile). Armen en benen zijn losse delen (`RIGS`: de voxels van elk ledemaat, met wat het
  vasthoudt) die om hun eigen gewricht draaien, met ruimte ertussen: `walking` laat ze lopen,
  `pose_limb` zet er een met de hand, en de rustbewegingen gebruiken ze (Jos zwaait, Martin
  tikt met zijn voet, Sjaan wiegt mee, de anderen ademen). Schaduw: per vlak lichter
  boven en donkerder opzij en onder, en ambient occlusion per voxelhoek; elke kleur iets
  verzadigder en met meer contrast (`SATURATION`, `CONTRAST`). Materialen per soort
  (`VoxelFigure.mark`): stoffen en haar met een eigen shader (`scripts/player/figure.gdshader`:
  geweven draden die over en onder elkaar lopen (linnenbinding, keper bij spijkerstof met
  een lichtere inslag), elke draad rond met een eigen gebolde normaal en een iets andere tint,
  rijen steken bij breisel, fijn en glanzend bij nylon, strengen bij haar, vervaagd waar het
  kleiner dan een pixel wordt; `CLOTH`), huid, ogen, leer,
  plastic, metaal en glas als gewone materialen met hun eigen glans (`MATERIALS`).
  `scripts/ui/widgets/player_portrait.gd` toont een poppetje in een eigen SubViewport: warm
  hoofdlicht met schaduw (ook op een onzichtbare vloer die alleen de schaduw toont), zacht
  vul- en tegenlicht, een lage grijze ambient en een eenvoudige lucht voor de reflecties.
  Muziek: `karakterkeuze_loop.ogg` (zacht: pad, klokjes op het motief, een zachte chiptune-melodie; 100 BPM, 38,4 s, lus), op -12 dB en
  infadend. Test: `tools/check/character_test.gd` (`-- figures`: alleen de poppetjes).
- Hoofdmenu (`scenes/hoofdmenu.tscn`, `scripts/ui/main_menu.gd`), naar het ontwerp
  "Titelscherm" in de HUD-stijl: titel ZWERVR, menu (VERDERGAAN en LADEN uitgegrijsd tot er
  opslag is; NIEUW SPEL toont "LADEN…" en opent het karakterscherm (hieronder), dat daarna de stad opent (op de hoofdthread: op een achtergrondthread crashte het met het LOD-systeem; daarna het laadscherm van de stad);
  INSTELLINGEN: CRT-beeld en scanlijnen aan/uit in `user://instellingen.cfg`, die de HUD ook
  leest; CREDITS; AFSLUITEN), pijltjes/Enter/Esc of de muis, en het CRT-beeld. Erachter het
  kleine 3D-kaartje (meteen staat er de nachtkleur; het kaartje laadt op de achtergrond en
  vloeit er in 1,5 s overheen). Zon en maan, gloeiende schijven met een zachte gloed ver weg,
  gaan met de snelle menudag mee: de zon van opkomst tot ondergang, de maan door de nacht,
  elk links op, in een boog over het beeld en rechts onder (`sky_arc_left`, `sky_arc_right`,
  `sky_arc_highest` op `Menu`); de zon in de kleur van het zonlicht. De camera staat op 6 m. De tijd gaat in het menu snel (`MENU_HOURS_PER_SECOND` 0,4:
  een dag in een minuut, vanaf `MENU_START_HOUR` 21:30), en om de 20 tot 40 s rijdt een
  RandstadRail-tram door het beeld, op twee lijnen: op de voorgrond en vlak voor de gebouwen
  achterin (`Tramlijn1`, `Tramlijn2`, gebakken door de tool; `TRAM_EVERY`, `TRAM_SPEED`). Over het gras achter het water komen af en toe colonnes langs
  (`COLUMN_KINDS`): boze boeren met 6 tot 12 trekkers (groen en rood, hobbelend; om de 20 tot 35 s,
  de eerste na een paar seconden) op weg naar het Malieveld, en de politie: een politieauto
  met ME-busjes erachter, blauwe zwaailichten knipperend met hun blauwe licht op de omgeving
  (om de 15 tot 30 s, de eerste zo'n 5 s na het openen); ze beginnen net buiten beeld. Ze rijden
  op twee stroken; af en toe (`CRASH_CHANCE`) komt de politie de trekkers tegemoet op hun
  strook en botsen ze: de voertuigen worden wrakken (RigidBody3D met een box-collider ter grootte
  van het voertuig, hun massa en snelheid, een sprong en een draai) die over het gras (een
  vloer-collider) stuiteren, met scherven en stof; wat erachter rijdt en een wrak raakt,
  botst ook; na `WRECK_SECONDS` verdwijnen ze. Trekkers vliegen bij een botsing in de fik: vlammen van gloeiende
  blokjes, een rookkolom en een flakkerend oranje licht op het wrak (`menu_fire.gd` op
  `BURNING_SIZE`); ze branden `BURNING_WRECK_SECONDS`, het vuur dooft in de laatste
  `WRECK_DIE_SECONDS`, en de laatste rook drijft nog even na
- Hoe langer het menu openstaat, hoe ellendiger het erachter wordt: de chaos groeit in
  `CHAOS_SECONDS` (120 s) van 0 naar 1; de colonnes komen tot `CHAOS_PACE` (3×) zo vaak en
  tot `CHAOS_CROWD` (1,8×) zo lang, botsingen worden waarschijnlijker (`CRASH_CHANCE` per
  colonne, van/tot), er branden meer daken tegelijk (een extra brand bij elk van `FIRE_AT`)
  en ze branden heviger (`fury` tot `CHAOS_FURY`). Naast trekkers en politie/ME rijden er
  ook hulpdiensten (`Hulpdiensten`: ambulances en brandweerauto's, de eerste na zo'n 18 s,
  vooral brandweer als er iets brandt) op een eigen strook (`LANE_OFFSETS`); ook zij komen
  bij meer chaos de trekkers tegemoet. Als de trekkers vertrekken, komt de politie snel
  (`CHASE_WAIT`), zodat ze elkaar tegenkomen. De zwaailichten zijn ook overdag goed te zien:
  grotere blokjes (`BEACON_SCALE`), onbelicht en fel gloeiend (`BEACON_GLOW`).
- Brand in de skyline (`scripts/effects/menu_fire.gd`): na 12 s vat ergens rond Centraal een
  dak vlam (een dak van de Gebouwen-GridMap in beeld, op de achtergrond): vlammen van gloeiende
  blokjes, een dikke rookkolom van donkere blokjes die met de wind meedrijft en een flakkerend
  oranje licht. Hij wordt steeds groter: hij begint klein (`START_SHARE`) en breidt zich uit
  tot `FULL_SIZE` keer een dak, met meer vlammen, meer rook en een feller, verder licht; na
  45 tot 75 s dooft hij, de rook trekt langzaam weg, en na een pauze breekt
  er ergens anders brand uit (`Trekkers` en `Politie` in het kaartje). De voorgrond tot Centraal is grasland
  (grastiles in de grove `_lod2`-versie, met wuivende grasplukjes van de grassprieten-shader in
  drie banden naar afstand, over de hele strook; de voorste strook, van de camera tot zo'n
  65 m, is water met reflectie en een oever aan de overkant, `DITCH_ROWS`; alleen gewoon water,
  met hogere golven, meer glinstering en een spiegeling die tot de skyline reikt: `MENU_WATER`), de zon heeft schaduw tot 900 m. Achter de skyline staan, bewust
  niet op hun echte plek, de Malietoren, de toren van de Grote Kerk, de Paulussen-schoorsteen en
  Paleis Huis ten Bosch (`TRANSPLANTS`), en het Strijkijzer en de woontoren in Laak
  (`LANDMARK_AREAS`). Het kaartje wordt al tijdens de intro
  geladen, zodat het menu er meteen mee opent: een stuk van de stad rond Centraal 's nachts, met een lage camera ver weg
  (de skyline van het ontwerp), die langzaam heen en weer glijdt (exports op de node `Menu`:
  `pan_speed` 2,5 m/s: de camera glijdt eindeloos opzij; het kaartje herhaalt zich over een
  strook van 356 m, kolommen `STRIP_FIRST_COLUMN`..`STRIP_LAST_COLUMN`, metadata `periode`, het
  menu legt kopieën links en rechts en de camera springt na een periode ongemerkt terug). Je past de bron aan:
  `scenes/menu_kaart_bron.tscn` (gewone GridMaps, camera, licht). Het menu toont de gebakken
  versie `scenes/menu_kaart.scn` (vaste meshes, de details zoals borden samen met de gebouwen
  gebakken zoals in de stad, zonder de props die je van die afstand niet ziet, materialen in de
  scène zelf; 23:45, zomernacht), zodat het menu de
  enorme tilebibliotheken van de stad niet laadt; met die bibliotheken in het menu crashte Godot
  bij het openen van de stad. Na het aanpassen van de bron opnieuw bakken met
  `tools/godot.sh --headless --script tools/build/build_menu_map.gd` (de bron opnieuw uit de
  stad maken, je aanpassingen weg: `-- overschrijf`). De shaderkaarten die TintKaart en
  GrondKaart in de stad uit de GridMaps maken (kleurvariatie per cel, soorten grond voor gras,
  reliëf en randen) rekent de tool bij het bakken uit en bewaart ze in het kaartje (node
  `Shaderkaarten`, `scripts/world/baked_shader_maps.gd`), want daar zijn geen GridMaps meer. Pauze in het spel: Esc (VERDER SPELEN,
  HOOFDMENU, AFSLUITEN; `GameHud.set_paused`).
  Bij aankomst komt het menu langzaam binnen, in twee delen: eerst het logo (de titel schuift
  met een fade van links in, `TITLE_SECONDS`), en als dat er bijna is (`MENU_AFTER`) volgen
  de knoppen een voor een, dan de voettekst; het beeld verliest even zijn tracking alsof de band
  start (`_play_entrance`, `ENTRANCE_*`). Het menu werkt meteen. Bij NIEUW SPEL gaat het
  omgekeerd (`_play_exit`): de knoppen faden weg, de titel schuift naar links uit beeld, alles
  vervaagt naar inktblauw met een sterke trackingstoring, en het laadscherm van de stad (ook
  inktblauw) neemt het over.
  Muziek: `assets/audio/muziek/nachtstad_menu_loop.ogg` (afgeleid van de compositie, zie hieronder), heel en in een lus, die bij het openen meteen op vol volume
  begint (geen infade) en bij het verlaten (NIEUW SPEL, AFSLUITEN) in 2 s uitfadet, ook als de
  stad al opent (`MUSIC`, `MUSIC_VOLUME_DB`, `MUSIC_FADE_OUT`).
  Stadsmuziek: één lus overal, `spel_loop.ogg` (`CITY_MUSIC` in `scripts/ui/hud.gd`; geen
  wijkmuziek), na het kaartdeuntje (`deuntje_kaart_start.ogg`) infadend; in een gebouw met eigen
  muziek (de handelaar, `set_indoor_music`) vloeit hij over en terug; op -10 dB en zachter zolang
  het spel stilstaat (pauzemenu, spelmenu, verhaalvak; `CITY_MUSIC_VOLUME_DB`, `CITY_MUSIC_PAUSED_DB`).
  Test: `tools/check/city_music_test.gd`.
  **Alle muziek komt uit één compositie** (nu "Blast Processing Overdrive" van Gemini, 136 BPM,
  D mineur, 32 maten): die wordt letterlijk de intro (`zwervr_intro.ogg`), en menu,
  karakterkeuze, handelaar, de stad en de deuntjes (nieuwe missie, taak klaar, missie gehaald,
  level omhoog, dood) worden ervan afgeleid, in Mega Drive-klank. Een nieuwe compositie
  aanleveren: de skill **`/muziek-compositie`** (`.claude/skills/muziek-compositie/SKILL.md`).
  De regels, de notatie en de lijst van stukken staan in **`docs/MUZIEK.md`**; de generator in
  `tools/muziek/` (`render.sh` maakt alles en `scripts/ui/intro_timing.gd`,
  `render.sh --controle` kijkt alles na).
  Verkeersgeluiden in Mega Drive-klank (`tools/megadrive/geluiden.py` op de geluidschip `megadrive.py`,
  `render.sh geluiden`; mono, in `assets/audio/geluiden/`): per voertuig (auto, brommer, bus,
  tram, trein) een langsrij-geluid (`*_voorbij.ogg`, met Doppler) en een naadloze motorlus
  (`*_motor_loop.ogg`, voor een AudioStreamPlayer3D op het voertuig), botsingen
  (`auto_botsing_hard.ogg`, `auto_botsing_licht.ogg`), `tram_bel.ogg`, `trein_hoorn.ogg` en
  `bus_remmen.ogg`, toeters om voetgangers te waarschuwen (`auto_toeter.ogg`, `bus_toeter.ogg`,
  `brommer_toeter.ogg`, `fiets_bel.ogg`, `scootmobiel_toeter.ogg`), en voor de hulpdiensten een eigen twee-toonsirene per dienst
  (`politie_sirene_loop.ogg`, `ambulance_sirene_loop.ogg`, `brandweer_sirene_loop.ogg`, plus
  `sirene_yelp_loop.ogg`), voorbijrazen met sirene (`*_voorbij.ogg`), `brandweer_hoorn.ogg` en
  de politiehelikopter (`helikopter_loop.ogg`, `helikopter_voorbij.ogg`); zie `docs/GELUIDEN.md`.
  Ruimtelijk geluid (`scripts/audio/spatial_audio.gd`, autoload `RuimtelijkGeluid`, alleen
  actief als de speler er is): het oor (AudioListener3D) zit bij de speler of het gevolgde
  voertuig en draait mee met de camera, zodat links en rechts op het scherm ook links en rechts
  klinkt. De `MAX_EMITTERS` dichtstbijzijnde voertuigen krijgen hun motorlus (toonhoogte volgt de
  snelheid, plus Doppler), hulpdiensten hun sirene zolang `siren_on`; botsingen, busremmen, de
  trambel bij vertrek en soms de treinhoorn klinken vanzelf, de helikopter heeft zijn rotor.
  Rijdt een voertuig snel en dichtbij langs (`PASS_BY_DISTANCE`, de helikopter overhead), dan
  speelt zijn `*_voorbij.ogg` (een hulpdienst met sirene: de zijne, met sirene), getimed zodat
  het hardste moment op het dichtstbijzijnde punt valt; motorlus en sirene duiken zolang weg.
  Remt een hulpdienst met sirene af (kruispunt, file), dan wordt de sirene de yelp; de
  brandweer toetert daarbij soms (`brandweer_hoorn.ogg`). Afscherming met raycasts: drie stralen van het oor naar elke bron tegen de stad (laag 1);
  staat er een gebouw tussen, dan klinkt de bron gedempt (low-pass) en zachter. Echo en galm
  volgen de omgeving: stralen rondom het oor meten hoe ingesloten je staat en hoe ver de
  gevels links en rechts zijn; daarmee stelt het de echo (vertraging per gevel, flutter tussen
  smalle gevels) en de galm (nat en groot in een straat of tunnel, droog op een plein of in
  het park) van de bus `Verkeer` in; de muziek blijft droog. Test:
  `tools/check/spatial_audio_test.gd`.
  Geluidseffecten (`scripts/ui/ui_sounds.gd`, `UiSounds.play(node, naam)`, in code gemaakt in
  de stijl van de FM-geluidschip van een 16-bit console: twee-operator-FM, snelle
  toonhoogtesweeps, 6-bit korrel; geen samples): `kies` (ander item kiezen: twee snelle heldere
  oplopende noten), `doe` (een item uitvoeren, een menu in, intro overslaan: snelle oplopende arpeggio van een
  majeurakkoord, de laatste noot klinkt na),
  `terug` (terug of een menu verlaten: twee zachtere dalende noten); in het hoofdmenu, het pauzemenu
  en de intro.
  Om de 6 tot 16 s stoort het beeld even: een lichte band rolt in 0,7 s van boven naar beneden
  over het scherm, het beeld verspringt daarin een fractie opzij (`glitch_y`,
  `glitch_strength` van de CRT-shader; `every`, `roll_seconds` in `scripts/ui/crt_disturbance.gd`,
  dat het menu en de intro allebei gebruiken). Bij
  ongeveer de helft verliest de "band" ook zijn tracking, zoals een VHS-band: beeldlijnen
  springen opzij (het meest in een rafelige strook onderaan), het beeld golft, de kleuren
  schuiven uit elkaar en er komt ruis (`tracking` van de shader; `tracking_chance`,
  `tracking_seconds`).
  Test: `tools/godot.sh --headless --script tools/check/menu_test.gd`.
- Test van de richtingen per tile: `tools/godot.sh --headless --script tools/check/lane_choice_test.gd`
- Stukken die in elkaar staan (muren door muren, knipperende vlakken): `tools/godot.sh --headless
  --script tools/check/clash_test.gd -- 60` geeft per paar tiles hoe vaak hun meshboxen door
  elkaar of in één vlak liggen (stukken van één gebouw naast elkaar tellen niet), met plekken.
  Grof (boxen, geen echte vlakken): gebruik het om plekken te vinden. De bouwer ruimt het
  meeste zelf op: hoekstukken die tegen een ander gebouw staan worden recht
  (`_straighten_hidden_corners`), balkons naast een viaduct vlak (`_flatten_facades_by_viaducts`)
  en bomen die in een gevel groeien gaan weg (`_remove_trees_in_buildings`).
- Test: `tools/godot.sh --headless --script tools/check/drive_test.gd -- 300`
  (optioneel startcel en richting, bv. `-- 300 70 24 1 0` voor de A12). De test meldt
  of de auto ergens naast de weg rijdt, boven of onder het wegdek zit, te hard gaat of
  te scherp draait.


Binnenruimtes (snackbars, Den Haag Centraal)
--------------------------------------------
Gebouwen waar je in kunt lopen staan in `scripts/world/interiors.gd` (node `Binnenruimtes`),
één regel per soort in `KINDS`. Voor elke ingang op de kaart staat een deinende oranje pijl
(groot, op en neer, met de nep-3D-schaduw van de teksten) en "[E] Naar binnen". Naar binnen
en buiten gaan klinkt als het elektronische deurgeluid van een winkel ("pling-plong",
`deur_binnen`/`deur_buiten` in `tools/megadrive/geluiden.py`). De binnenruimte ligt ver
buiten de kaart (`at`), staat stil en is onzichtbaar zolang je buiten bent.

- Snackbars (`scenes/binnen/snackbar.tscn`, `scripts/world/interior.gd`): elke gevel
  `_bg_snackbar` is een ingang; naam, kleurvariant en gasten per snackbar.
- Den Haag Centraal (`scenes/binnen/centraal.tscn`, `scripts/world/station.gd`): de drie
  deuren van de stationshal aan het Stationsplein (west naar oost deur 1..3) komen uit bij
  Deur1..3 binnen; naar buiten ga je bij de deur waar je uitloopt. De indeling staat in
  `scripts/world/station_layout.gd` (één bron voor bouwer en spel): een kopstation met 12
  sporen en 7 perrons (`grond/spoor/perron`, `trein_recht`, `trein_stootblok` van de stad,
  `PLATFORM_DROP` omlaag zodat de perrons gelijk liggen met de hal), een hal van 96 x 32 m met
  13 winkels (o.a. Smikkels met automatiekwand, Broodje Seinstoring, Duwus Bertus; een
  Smikkels-verkoper verkoopt kroketten als in de snackbar), OV-chipkaartautomaten, drie
  vertrekborden, een stationsklok met rode secondewijzer, pilaren, banken, OV-paaltjes.
  - Treinen (`station_train.gd`, de NS-wagons van de stad): elk spoor heeft een vertrek
    (bestemming, Intercity/Sprinter, 2 of 3 wagons, soms vertraging of "rijdt niet"). Op een
    willekeurig moment rijdt de trein door de achterwand binnen, remt voor het stootjuk,
    opent de deuren aan de perronkant, staat 2,5-4,5 min, de conducteur fluit (17 s voor
    vertrek), de deuren piepen dicht (12 s), en hij vertrekt zoals hij kwam.
  - Klok: de stationsklok begint bij de tijd van de stad als je de eerste keer binnenkomt
    en loopt dan in echte tijd. Borden en perronschermen tonen tijd, bestemming, spoor en
    vertraging.
  - Omroep (`station_audio.gd`): eigen bussen "Stationshal" (galm van de hal) en "Omroep"
    (luidsprekerband, echo van verre speakers, door de hal-galm): de gong `omroep_gong`, dan de
    brabbelstem van het spel, de tekst onderin beeld. Vertrek, vertraging, uitval en af en toe
    een mededeling (`NOTICES`).
  - Poortjes (`station_gates.gd`) voor elk perron: kasten met poortjes in (vanuit de hal) en
    uit (naar de hal), glazen klepjes die echt dichtzitten (botsvorm) en open zwaaien de kant
    op die je gaat. Groen lampje aan de kant waar je in mag, rood aan de andere. Zonder
    OV-chipkaart (item `ov_chipkaart`, € 7,50 uit een automaat) zoemt de lezer nee. Inchecken
    is één piep, uitchecken twee. Bij de OV-paaltjes check je met [E] in of uit.
  - Mensen (`station_person.gd`, met tassen uit `scripts/world/carried_items.gd`):
    reizigers, zakenmensen met aktetas, toeristen met rolkoffer en rugzak, scholieren met
    rugzak; hoeveel en wie hangt af van het uur (`BUSY_BY_HOUR`, `WHO_BY_HOUR`). Ze lopen om
    winkels en obstakels heen, wachten bij een poortje tot het open is, checken in, wachten
    op het perron, stappen in als de deuren open zijn; uit een binnengekomen trein stappen
    mensen uit en gaan naar buiten of een winkel in. Conducteurs (NS-blauw met pet) lopen naar
    hun trein en fluiten; handhavers (zwart met geel) lopen in paren door de hal en één over
    de perrons. Onzichtbare randen langs de perrons: niemand valt op het spoor.
  - Markers in de scène (verplaatsbaar in de editor, ook voor missies): Deur1..3,
    Dienstdeur, Poortjes_<n>, Vertrekbord_<n>, Perronscherm_<spoor>, Klok, Winkel_<n>,
    Verkoper_<n> (metadata `kind`, `shop_name`), Uithangbord_<n>, Automaat_<n>.
  - Test: `tools/check/station_test.gd` (ingangen, sporen, poortjes met en zonder kaart,
    een vertrekkende trein, instappen, niemand vast, naar buiten bij deur 3).

Binnenruimtes maken (dezelfde opzet als de snackbar):

1. Tiles in `tools/voxgen/tiles/interior.py` onder `binnen/<naam>/` (voxels van 0,125 m,
   vloeren en muren 4 m breed; hoge muren achter en links, lage voor en rechts, waar de
   camera inkijkt). `python3 tools/voxgen/generate.py --only binnen/<naam>`, dan importeren
   (editor open: hij doet het zelf; dicht: `tools/godot.sh --headless --import`) en
   `tools/godot.sh --headless --script tools/build/build_libraries.gd`.
2. Een bouwfunctie in `tools/build/build_interiors.gd` (zoals `_build_snack_bar` en
   `_build_station`): GridMaps `Vloer` (y -0,125) en `Inrichting` met de bibliotheek
   `binnen`, eventueel `Props` en grondtiles, markers (`Deur` of `Deur1..n`, plekken voor
   mensen), lampen. Bouwen: `tools/godot.sh --headless --script tools/build/build_interiors.gd -- <naam>`
   (een bestaande scène blijft staan; `-- opnieuw <naam>` bouwt hem over).
3. Een script: `scripts/world/interior.gd` als basis; met meer leven een script dat het
   uitbreidt (`extends "res://scripts/world/interior.gd"`) en `dress()`, `doors()`,
   `player_came_in()`/`player_went_out()` invult.
4. Een regel in `KINDS` van `interiors.gd`: `scene`, `music`, `at` (een eigen plek ver buiten
   de kaart), en waar de ingangen zijn: `front` (deel van de naam van een geveltile) of
   `doors` + `place` + `place_reach` (deurtiles bij een plek op de kaart).
5. Een check in `tools/check/` naar het voorbeeld van `interior_test.gd`/`station_test.gd`.

Projectstructuur
----------------
    addons/vox_tiles/      editor-plugin (plugin.gd, plugin.cfg)
      importer/            tiles inlezen en meshen: voxel_model, gox_parser (.gox),
                           vox_parser (.vox), vox_mesher, vox_import_plugin,
                           slopes (hellingen/bochten), tile_metadata (.tile.json)
      library/             MeshLibraries bouwen: library_builder, atlas
      editor/              bouwpaneel en editor-weergave: build_dock, build_tools, stamps,
                           editor_view, outline, layer_highlight, scene_preview
      materials/           shaders en materialen van de voxels
    assets/                tiles (.gox + .tile.json, kleurentabel materialen.json),
                           libraries (gemaakt), fonts
    scenes/                stad.tscn (de kaart), intro, hoofdmenu, karakter, menu_kaart(_bron)
    scripts/               spelcode
      camera/              iso_camera, free_camera (alleen nog voor de tools), follow_camera
      player/              player_controller (de speler in de stad), player_character
                           (archetypes), player_model (voxelfiguur), items
      player/              player_character (archetypes en keuze), player_model (voxelpoppetjes)
      world/               de kaart zelf: level_of_detail, layer_baker, building_fade,
                           ground_map, grass_blades, tint_map, tint_area, day_cycle,
                           overhead_lines, tunnel_lights, zebra_clock
      traffic/             wegennet en verkeer: road_network, traffic, traffic_lights,
                           lane_arrows, helicopter_flights
      vehicles/            vehicle, rail_vehicle en de
                           voertuigsoorten (auto's, RandstadRail, NS-trein, helikopter, ...)
      effects/             crash_burst, vehicle_fire, menu_fire, death_blink, smoke, vignette
      ui/                  hud, intro, main_menu (+ menu/: de 3D-kaart erachter),
                           loading_screen, action_prompts, warp_transition, crt_disturbance,
                           ui_sounds, ui_style (kleuren, fonts, panelen, CRT) + crt.gdshader,
                           widgets/ (pixel_icon, segment_bar, check_square, player_arrow,
                           speech_balloon: tekstballon voor kreten, typewriter: tekst die
                           zich uittypt met cursor en Sega-tekstgeluid)
    tools/                 command-line tools (start ze met tools/godot.sh)
      godot.sh             Godot met tijdslimiet en zonder stdin
      bake.sh              de kaart vooraf baken (zie "Baken en thumbnails")
      thumbnails.sh        de thumbnails van de tiles maken (idem)
      tool_common.gd       gedeelde helpers van de tools
      progress.gd          voortgangsregels van de tools ("[ 42% ] ... nog ~25 s")
      build/               build_city (+ city/: de bouwer in delen), build_menu_map,
                           build_libraries, build_previews, bake_maps,
                           reimport_stale.sh (verouderde tiles headless herimporteren)
      check/               coverage, corner_test, crash_test, drive_test, fps_test,
                           axle_test, player_test, hud_test, lane_choice_test, traffic_test,
                           clash_test, intro_test, menu_test, mesh_audit, offscreen_audit,
                           overlap_test, rail_stop_test, triangle_count, speech_balloon_test,
                           street_lights_test, drown_test, building_fade_test,
                           arrival_test, simple_figure_test,
                           loading_after_warp_test
      shots/               shot_tiles, shot_iso, shot_scene, shot_vehicles
    data/                  het verhaal, de missies en de gesprekken als JSON (zelf aan te passen
                           en uit te breiden; uitleg in data/LEESMIJ.md)
    tests/                 unit tests: kleine onderdelen los, zonder de stad (snel);
                           tests/unit/test_*.gd, elke functie test_* een test;
                           tools/godot.sh --headless --script tests/run_unit_tests.gd [-- <filter>]
      voxgen/              Python-generator van de tiles (zie "Tiles (opnieuw) genereren")
      megadrive/           Python-generator van alle muziek en de verkeersgeluiden in Mega Drive-stijl (FM, PSG, PCM-drums)
    docs/                  Goxel-handleiding (GOXEL.md -> handleiding_goxel.html), MUZIEK.md (de muzikale huisstijl), GELUIDEN.md (geluidseffecten en stemmen)


Snel starten
------------
1. Open de map in Godot 4.7 (`project.godot`). De eerste keer importeert Godot
   alle tiles en maakt de plugin de palet-previews (dat duurt even).
2. Open `scenes/stad.tscn`.
3. Selecteer een GridMap-node (Grond / Gebouwen / Details / Props); onderin
   verschijnt het tile-palet. Zoek op naam, klik een tile, en klik in de 3D-view.
4. F5 start de stad (`scenes/stad.tscn`, zie boven). Je loopt rond met het gekozen
   karakter (WASD of pijltjes, Shift = rennen, Tab/I = spelmenu, Escape = pauze); de camera
   volgt je in isometrische stand: een perspectiefcamera met een smalle kijkhoek (20°),
   135 graden gedraaid (de camera staat in het noordoosten, zodat je de voorkant van Centraal
   met de letters DEN HAAG CENTRAAL ziet) en ~35 graden naar beneden (`scripts/camera/iso_camera.gd`). Een
   echte perspectiefcamera, omdat Godot schaduwsplits en SSR alleen daarmee goed berekent.
   De vrije camera (`scripts/camera/free_camera.gd`, op de Camera-node: schuiven, zoomen,
   draaien) is in het spel uit: de Volgcamera neemt hem bij de start over. Hij werkt nog
   in de tools, die de Volgcamera weghalen (`Common.instantiate`).

Vox Tiles-scene en editor-weergave: bovenaan het Build-paneel staat het vinkje
"Vox Tiles scene". Het markeert de geopende scene als scene die met de tiles gebouwd
wordt (opgeslagen als metadata op de root-node, één stap in Ctrl+Z). De stad
en de lege kaart zijn al gemarkeerd. In een gemarkeerde scene zijn de bouwtools
beschikbaar en kies je met "View" hoe de 3D-view eruitziet:
- Editor (standaard): snel, voor een hoge framerate tijdens het bouwen. Geen
  schaduwen, reflecties, SSAO/SSIL/glow/mist, rook of animatie; lijnen op
  de 4 m tile-randen; een lichtblauw kader om elke tile van de geselecteerde laag
  (Grond, Gebouwen, Details of Props); orthografische camera.
- Game: zoals in het spel, met schaduwen, zon, reflecties, effecten en animatie, en
  een perspectiefcamera. LOD en het samenvoegen van lagen (DetailNiveau) draaien alleen
  in het spel zelf (F5/F6), in geen van beide weergaven.
Het spel gebruikt de editor-weergave nooit. Schaduwen staan in de Editor-weergave uit,
maar worden vóór opslaan en starten weer aangezet, dus de scene blijft zoals hij was.
De plugin zelf staat aan in de projectinstellingen; je hoeft niets te activeren.

GridMap-bediening in de editor (Godot 4):
- klik = plaatsen, rechtsklik = verwijderen
- A / S / D = tile draaien om de X / Y / Z-as (S draait om de verticale as)
- Q / E (of het menu "GridMap > Verdieping") = een laag omlaag/omhoog
- Ctrl+klik-slepen = selecteren; daarna dupliceren/verplaatsen/verwijderen


Bouwpaneel ("Build", rechtsboven in de editor)
----------------------------------------------
- Vox Tiles scene: vinkje bovenaan; alleen in een gemarkeerde scene verschijnen de
  tools hieronder (zie hierboven).
- View: Editor (snel, kaders, orthografisch) of Game (zoals in het spel).
- Laag: één knop per GridMap (Grond, Gebouwen, Details, Props). Klik = die laag
  bewerken; het tile-palet van Godot verschijnt onderin.
- Verdieping: `-`/`+` (of Q/E in de 3D-view) en de hoogte van die verdieping in
  meters. Grond-verdiepingen zijn 1 m, gebouw-verdiepingen 3 m.
- Wat je bewerkt valt op in de 3D-view zodra je een laag hebt geselecteerd (uit in de
  weergave `Game`): de verdieping krijgt een dun oranje raster, dat bij ver uitzoomen wegvalt, zijn tiles een oranje waas met
  felle lijnen (`layer_highlight.gd`, `outline.gd`), de andere verdiepingen vage lijnen. Een
  kaart linksboven toont laag, verdieping en de tile uit het palet met zijn voorbeeld; onder
  de muis staat een dikke box. Daarnaast staat de naam van de tile die daar ligt (wit; op de
  gekozen verdieping, anders de hoogste verdieping van de laag), en oranje de tile die je zou plaatsen.
- "Hide other layers": verbergt de andere lagen zolang je bewerkt. Bij opslaan of
  starten worden ze eerst weer zichtbaar gemaakt, dus dit komt nooit in de scene.
- Godot zelf: met "Edit X/Z Axis" teken je op een staand vlak (pijlers, muren over
  meerdere verdiepingen); fill en duplicate werken ook over meerdere verdiepingen.
- Stempels (op de Grond-laag): kies een stempel en de instellingen, klik "Draw
  stamp" en klik in de 3D-view een begin- en een eindcel op straatniveau. Een
  stempel is één stap in Ctrl+Z. Rechtsklik/Esc annuleert.
  - Canal / river: water op laag -2 over de gekozen breedte, kademuren op -2 en -1
    en kades (naar het water gericht) op straatniveau; straatniveau boven het water
    wordt leeggemaakt.
  - Bridge (street level): brugdekken op straatniveau (breedte 2 = gespiegeld dek,
    voor dekken met een leuning aan één kant).
  - Viaduct on pillars: dek op de gekozen laag, pijlers om de zoveel tiles (in het
    water op de bodem, op land op gras/stoep; niet op wegen of spoor, daar komt een
    ligger) en liggers ertussen. Einden: landhoofden voorbij beide einden, of
    opritten (`brug/helling/*`) die per tile 1 m stijgen van straatniveau tot het
    dek, zodat een weg over een andere weg gaat (lijn minstens 2 x hoogte + 1).
  - Car tunnel (3 lanes): toerit omlaag, open bak, portaal en tunnel op laag -6,
    aan het eind gespiegeld; minstens 19 tiles lang.
  De lijn volgt de langste as; breedte loopt naar links gezien in de tekenrichting
  (de blauwe voorvertoning laat zien waar alles komt).


De vier lagen
-------------
| GridMap   | Celgrootte (m)  | Hoogte-offset | Gebruik                                          |
|-----------|-----------------|---------------|--------------------------------------------------|
| Grond     | 4 x 1 x 4       | 0             | wegen, stoepen, water, spoor, tunnels, bruggen, hellingen |
| Gebouwen  | 4 x 3 x 4       | 0.375         | gebouwblokken, 1 verdieping per laag              |
| Details   | 0.5 x 0.5 x 0.5 | 0.375         | luifels, ramen, balkons, teksten, dak-installaties |
| Props     | 0.5 x 0.5 x 0.5 | 0.25          | bomen, lantaarns, borden, banken, boten            |

Maten: 1 voxel = 12,5 cm. Een grond-tile is 32x32 voxels (4x4 m), een
gebouwblok 32x32x24 voxels (4x4x3 m). Alles is op ware schaal voor spelers: een
persoon van 1,80 m is 14-15 voxels (zie prop `overig/persoon_1m80`). Deuren
zijn 2,0-2,6 m hoog, verdiepingen 3 m, de autotunnel heeft 4,75 m vrije hoogte,
trappen hebben treden van 12,5 cm.

Hoogtes en lagen (grond):
- Een grond-laag is 1 m hoog. Wegdek ligt op 0,25 m, stoep en gras op 0,375 m.
- Hellingen staan in de submap `helling` van hun categorie (`weg/helling/helling_*`,
  brughellingen in `brug/helling/*`) en stijgen 1 laag over 1 tile; flauwe hellingen
  (`weg/helling/flauw_*_a` en `_b`) stijgen 0,5 m per tile (a eerst, dan b).
  Zet `terrein/grond_blok` eronder als je verder ophoogt. De meeste hellingen
  hebben geen eigen `.gox`: de importer maakt ze van de vlakke tile (`slopes` in
  de tile-metadata, zie hieronder).
- Bruggen: brugdek op de gewenste laag, `brug_pijler` eronder gestapeld,
  `brug_pijler_kop` direct onder het dek en `brug_pijler_gras/stoep/water` op
  laag 0 (grond + pijler in één tile). Stalen boogbrug: `staalboog_1..5` (5 tiles
  overspanning), tuibrug: `tuibrug_0` (pyloon) + `tuibrug_1..3`.
- Grachten en rivieren: water op laag -2, `kademuur` op laag -2 en -1 en
  `stoep_kade` op laag 0. De bakstenen boogbrug en de kadetrap zet je op laag -2.
- Bochten: buiten een bocht in de straat volgt de stoeprand de lijn (`<rijstrook>_hoek_links_stoep`,
  `_goot` of `_klinker`, met schuin buiten de hoek een volle stoeptegel `stoep_vol`). Stoephoeken
  `stoep_*hoek_buiten` hebben een straal van 1,5 m.
- Tunnels (6 lagen hoog): tunnel-tiles op laag -6; het dak komt dan precies op
  straatniveau, zodat je er een weg of snelweg bovenop kunt leggen. Toerit:
  `tunnel_toerit_*_d1` t/m `_d6` op laag -1 t/m -6; daarna `tunnelbak_*_d6` (open
  bak) en `tunnel_*_portaal` aan het begin van de overkapping. Varianten
  `_wand` / `_wand_rechts` hebben een keerwand links/rechts; fiets-varianten
  bestaan ook. Tram: `tramtunnel_toerit_wand[_rechts]_d1` t/m `_d6`,
  `tramtunnel_wand[_rechts][_portaal]`, `tramtunnel_kaal` en `tramtunnel_perron[_begin|_eind]` naast het
  spoor bij een ondergrondse halte, met op straat de prop `ov/tramtunnel_ingang`.
- Zwembaden buiten: `zwembad_*` op laag -1 (de rand komt op stoepniveau).
- Grote bochten (`*_bocht_groot_3x3`) beslaan 3x3 tiles: plaats ze in de
  middelste cel en laat de 8 cellen eromheen leeg.

Richting van tiles:
- De "voorkant" van elke tile wijst in Godot naar +Z (zuid, naar de camera
  toe). Stoepranden, gevels, oevers en kade-randen zitten aan die kant.
- Rijstroken: het verkeer rijdt naar -Z. De naam `rijstrook_<links>_<rechts>`
  zegt welke markering aan de linker- en rechterkant van de rijstrook ligt
  (geen, onderbroken, streep, dubbel, blok, kant = kantstreep). Tram met
  belijning: `tram_rijstrook_<links>_<rechts>`.
- Hoekstukken (`*_hoek`, `hoek_buiten`) hebben iets aan de voor- én
  rechterkant.


Gebouwen bouwen
---------------
Stijlen (map `assets/tiles/gebouwen/<stijl>/`):
klassiek_rood, klassiek_donker, klassiek_geel, herenhuis_1600, herenhuis_1900,
jaren30 (bovenhuizen), jaren60 (eengezins/maisonnette), galerijflat,
modern_wit, modern_donker, modern_hout, appartement_modern, luxe_appartement,
kantoor_glas, kantoor_beton, kantoor_80, kantoor_2000, kantoor_modern,
museum_klassiek, museum_modern, kerk_baksteen, kerk_steen (kathedraal),
kerk_modern, school, universiteit, hogeschool, overheid, bedrijfspand,
schuur_zwart, schuur_rood, loods_staal, loods_steen, magazijn, fabriek
(laaddocks, roldeuren, lichtstraten, tondaken, sheddaken). Daarnaast: daken/ (dakpansoorten), hallen/ (holle
hallen, ook zwembad- en sporthal), overkapping/, pilaren/, parkeergarage/,
overig/ (radiotoren).

Onderdelen per stijl:
- `bg_*` begane grond: deur, raam, portiek, erker, garage, poort, entree,
  kolonnade (pilaren aan de voorkant), winkels en horeca (kleding, restaurant,
  cafe, bar, telefoon, bakker, slager, bloemist, boekhandel, fietsenwinkel,
  supermarkt, drogist, kapper, ijssalon, snackbar, juwelier, dierenwinkel)
- `verd_*` verdiepingen: ramen (ook groot/klein), luiken, balkon, erker,
  galerij, loggia, vliesgevel, lamellen, terras, spitsramen, roosvenster, ...
- `*_hoek` hoekblok met gevel aan voor- én rechterkant
- `blok_dicht` blok zonder ramen (binnenhoeken, zijkanten, torenvoeten)
- Platte daken: `dak_plat_midden / rand / hoek / tegenover / eind / los`
  (dakrand aan 0, 1, 2 of meer kanten), en `dak_bitumen_*`, `dak_grind_*`,
  `dak_groen_*` (sedum), plus zonnepanelen, lichtkoepel, daktuin,
  dakzwembad, installaties, kroon, kroonlijst en kantelen.
- Schuine daken:
  - `dak_schuin`: halve kap met goot aan de voorkant en nok achter. Twee rijen
    met de ruggen tegen elkaar = zadeldak over een blok van 2 tiles diep.
  - `dak_schuin_hoek_buiten`: hoekkeper, voor de buitenhoek van een bouwblok
    (of een schildeind).
  - `dak_schuin_hoek_binnen`: kilkeper, voor de binnenhoek van een bouwblok.
  - Varianten: dakkapel, schoorsteen, dakraam, zonnepanelen, dakterras (kap
    deels opengebroken), `half_plat` en `afgeplat` (afgeknotte kap).
  - `dak_zadel*`: complete kap over een blok van 1 tile diep, met `schild`
    (eind), `hoek` (L-hoek) en `t` (T-splitsing).
  - `gebouwen/daken/<soort>/`: alle kapvormen in rode, oranje, zwart
    geglazuurde en antraciet pannen, leisteen, riet, golfplaat, zink, koper en
    sedum, plus piramide- en lessenaarsdaken.
- Toppen: grachtengevels (`gevel_trap/klok/hals/tuit`), lijstgevels,
  frontons, mansardedaken, kerkgevels, penthouses.
- Torens: `toren_*` (portaal, raam, klok, galmgat, spits onder/boven,
  pinakels) stapel je per verdieping.

Zo loopt een kap om de hoek van een bouwblok (ring van 2 tiles diep):
buitenhoek = `dak_schuin_hoek_buiten`, de tegels ernaast = `dak_schuin` (goot
naar de straat), binnenhoek = `dak_schuin_hoek_binnen`, en de rij aan de
binnenhof = `dak_schuin` met de goot naar de binnenhof.

Holle gebouwen: de tiles in `hallen/`, `parkeergarage/` en `overkapping/` zijn
van binnen leeg, zodat je er (later met spelers) in kunt lopen. Leg de vloer
(bv. zwembad- of pleintiles) op de grond-laag eronder.

Collision: grond en holle/beloopbare gebouwtiles hebben een exacte botsvorm;
dichte gebouwblokken een doos van 4x3x4 m; props een omhullende doos.


Kleur en tint aanpassen (zonder de .gox te wijzigen)
----------------------------------------------------
In elke kaart zit een node `TintKaart` (script `scripts/world/tint_map.gd`):
- `variation`: geeft elke 4x4 m cel automatisch een net iets andere kleur.
- Voeg een kind-node toe met script `scripts/world/tint_area.gd` (TintArea), schuif
  hem over een gebouw of stuk grond en kies `color`, `brightness`, `strength`
  en `size` (in cellen). De tint werkt live in de editor.
  Wit = geen verandering; helderheid > 1 is lichter, < 1 donkerder.
Dit werkt via globale shader-parameters (Project > Project Settings >
Shader Globals: `zwervr_tint_map`, `zwervr_tint_area`, `zwervr_variation`).


Rook, water, vlaggen en voxelstructuur
--------------------------------------
- Rook: de node `Rook` (script `scripts/effects/smoke.gd`) zet automatisch rookpluimen
  op alle fabrieksschoorstenen (`overig/fabrieksschoorsteen_top`) en op de
  kleine schoorsteen-details. Werkt live in de editor; vink `rescan`
  aan nadat je schoorstenen hebt toegevoegd. `wind` bepaalt de richting.
- Voxelstructuur: `materials/voxel.gdshader` tekent (optioneel) lichte randen en kleine
  helderheidsverschillen per voxel (`voxel_noise`; randjes via `voxel_edge`, standaard uit), zodat grote
  vlakken minder vlak ogen.
- Water golft met golven uit vier richtingen (niet rechtlijnig) en heeft lichte,
  bewegende vlekken en glinsteringen (`materials/voxel_water.tres`:
  `wave_height`, `wave_speed`, `wave_length`, `patches`, `glitter`). De
  importer maakt het wateroppervlak daarvoor per voxel fijnmazig.
- Spiegeling in water, zonder raytracing: de shader volgt de gespiegelde
  kijkstraal in 12 stappen over het scherm (diepte- en schermbuffer) en toont
  wat hij raakt (bruggen, bomen, gevels); anders spiegelt de lucht (kleuren uit
  de dagcyclus). Instelbaar in `materials/voxel_water.tres`: `reflection`,
  `sky_reflection`, `step_size`, `steps`, `thickness`, `ripple`. De SSR van Godot
  gaf hier geen zichtbare spiegeling en staat uit.
- Drijvende objecten (boten, boeien, waterlelies; metadata `"animation": "float"`,
  zie hieronder) deinen mee: `materials/voxel_drijf.tres` volgt dezelfde golf als
  het water, deint extra (`heave`) en laat het object rollen en stampen (`roll`).
  Grond-tiles met waterplanten gebruiken `voxel_drijf_plant.tres`: alleen wat
  boven het water ligt dobbert, elk stukje op zijn eigen plek.
  Houd `wave_height`, `wave_speed` en `wave_length` gelijk aan die van het
  water. Zulke tiles worden niet samengevoegd.
- Zonnepanelen hebben een eigen glanzend materiaal (`materials/voxel_paneel.tres`,
  een gewoon StandardMaterial3D); kleur `zonnepaneel` in het palet.
- Glas is ondoorzichtig met een goedkope, nagebootste spiegeling (lucht, horizon,
  straat en lichte strepen; `reflection`), zie verderop.
- Lampen, verkeerslichten en verlichte ramen (emit-materiaal, energie 6) geven
  's nachts een zachte gloed via de glow van de Environment (drempel 1,6).
  Overdag branden ze op 25% (shader global `zwervr_night`, gezet door de
  dagcyclus), zodat verlichte ramen overdag geen witte vlekken zijn.
- Vlaggen wapperen via `materials/voxel_vlag.tres` (`speed`, `strength`,
  `wavelength`). Hoe verder van de mast, hoe meer beweging.
- Water en vlagdoek zijn gewone kleuren uit het palet (`water1`, `vlag_rood`, …);
  de kleurentabel `assets/tiles/materialen.json` geeft ze hun materiaal.


Tiles aanpassen in Goxel
------------------------
Uitgebreide, visuele handleiding (Goxel klaarzetten, modelmaten, palet, materialen,
metadata, met alle kleuren): `docs/handleiding_goxel.html` (bron: `docs/GOXEL.md`).
Het palet voor Goxel (`zwervr.gpl`), een kleurenoverzicht (`palet.gox`) en een
legenda (`palet.md`) staan in `tools/voxgen/paletten/`; opnieuw maken met
`python3 tools/voxgen/generate.py --palettes`.

Alle tiles staan in `assets/tiles/<categorie>/<groep>/<naam>.gox`.
1. Open een `.gox` in Goxel, pas aan, sla op (Ctrl+S).
2. Ga terug naar Godot: de tile wordt automatisch opnieuw geïmporteerd en de
   bibliotheek (palet, preview en collision) wordt bijgewerkt.

Belangrijk bij het bewerken:
- Houd het kader van het model (paneel Image: Origin en Size) gelijk; het
  draaipunt is het midden-onder van het kader. Grond-tiles 32x32 (Origin
  -16, -16, 0), gebouwblokken 48x48 (blok in het midden, 8 voxels rand voor
  balkons en luifels; Origin -24, -24, 0).
- De voorkant is de kant met de laagste Y in Goxel.
- Een `.gox` bewaart alleen kleuren. Het materiaal komt uit de kleur
  (kleurentabel `assets/tiles/materialen.json`, gemaakt uit `palette.py`); teken
  dus met de exacte kleuren van het palet Zwervr. Een laag met de naam van een
  materiaal (`glass`, `emit`, `water`, …) dwingt dat materiaal af, de
  tile-metadata (zie hieronder) gaat boven alles.
- Alle zichtbare lagen samen vormen de tile; maximaal 255 kleuren per tile.
- Oude MagicaVoxel-bestanden (`.vox`) worden nog gelezen; omzetten naar `.gox`
  met `python3 tools/voxgen/convert_vox.py <bestand.vox>`.

Tile-metadata (`<naam>.tile.json`)
----------------------------------
Naast elke `.gox` kan een `<naam>.tile.json` staan met instellingen die het
modelbestand niet kent:

    {
        "animation": "float",
        "materials": {"#3a3a3e": "asphalt"}
    }

- `animation`: `none`, `wind` (bomen, planten), `flowers` (bloemperken) of
  `float` (dobbert op het water). Laat je hem weg, dan raadt de importer het aan
  de bestandsnaam.
- `materials`: alleen voor uitzonderingen in deze tile: per `#rrggbb`-kleur
  een materiaal: `opaque`, `metal`, `panel` (glanzend, zonnepanelen), `glass`,
  `emit` (licht), `water`, `flag` (wapperend), `asphalt`, `stone`, `brick`,
  `gravel`, `painted`, `paving`, `cobble` of `plaster` (`cobble`: kinderkopjes, de tile is
vlak en de shader tekent onregelmatige keien van ~`cobble_size` voxels in licht slingerende
rijen, elk een eigen tint met dunne voegen, zonder diepte). Gaat voor op
  materiaallagen en de kleurentabel.
- `bake` (geschreven door `tools/voxgen/bake.py`): `shadow` (wel of geen schaduw, weg = naar
  hoogte), `merge` (`false`: blijft een losse mesh; `true`: ook een vlag meebaken) en
  `building_part` (`false`: fade niet mee met het gebouw ernaast). De baker kent geen
  tilenamen, alleen deze metadata.
- Sla je het bestand (of de kleurentabel) op terwijl de editor open is, dan
  worden de tiles opnieuw geïmporteerd. Zonder editor: verwijder
  `.godot/imported/<naam>.gox-*` en draai `tools/godot.sh --headless --import`.
- De generator schrijft deze bestanden zelf voor gegenereerde tiles (id,
  animatie, hellingen) en schrijft bij elke run de kleurentabel. Alleen de
  metadata opnieuw schrijven, zonder `.gox` te wijzigen:
  `python3 tools/voxgen/generate.py --meta`.
- In het Import-paneel van Godot kun je `animation` per tile overschrijven.
- `slopes`: hellingen die de importer van deze (vlakke) tile maakt, bv.
  `["steil", "flauw_a", "flauw_b"]`. Vormen: `steil` (1 m per tile) wordt
  `<categorie>/helling/helling_<naam>`, `flauw_a`/`flauw_b` worden
  `<categorie>/helling/flauw_<naam>_a`/`_b`, `hoek_buiten`/`hoek_binnen` worden
  `<categorie>/helling/helling_<naam>_hoek_buiten`/`_binnen`,
  `brug`/`brug_rand` (brugoprit, dunne plaat; `_rand` met borstwering links) worden
  `brug/helling/helling_<naam>` en `brug/helling/helling_<naam>_rand`.
  Een cel van een vlakke bocht (`bocht/<profiel>_<i>_<j>`) heeft daarnaast
  `"curve": [i, j, delen]` en de bochtvormen `bocht`/`bocht_rechts` (stijgende
  bocht, `bocht/helling/<profiel>[_rechts]_<i>_<j>`), `brug_bocht`/`brug_bocht_rechts`
  (`brug/helling/bocht_<profiel>[_rechts]_<i>_<j>`) en `brug_vlak`
  (`brug/bocht_<profiel>_<i>_<j>`).
  Er is geen eigen `.gox` voor; pas je de vlakke tile aan, dan veranderen de
  hellingen mee. Zo kun je van elk wegdeel een helling maken. Hellingen zijn glad
  (geen voxeltrapjes): de importer bouwt de tile op een opgehoogd blok en schuift de
  mesh daarna op het schuine vlak.
- `smooth`: voor hellingen zonder eigen vlakke tile (heuvels, betondijk,
  tunneltoeritten) is de `.gox` zelf het opgehoogde blok (vlak oppervlak `lift`
  voxels boven de grond, met vulling eronder), bv.
  `{"shape": "steil", "lift": 2, "keep_x": [0, 1]}`. De importer maakt er een gladde
  helling van (`steil`, `flauw_a`, `flauw_b`, `hoek_buiten`, `hoek_binnen` of
  `heuvel_top`); kolommen in `keep_x` (een tunnelwand) blijven staan.
- Alias-tile: alleen een `.tile.json`, zonder `.gox`, met
  `{"id": 285, "same_as": "weg/weg_vlak"}` (pad binnen dezelfde categorie). Hij
  houdt zijn eigen naam en ID in de bibliotheek, maar gebruikt de mesh van de tile
  waar hij naar wijst. Zo staan identieke tiles maar één keer in het atlas.
  Wil je een alias weer een eigen model geven: verwijder zijn `.tile.json` en
  genereer hem opnieuw (of sla een `.gox` onder zijn naam op).


Nieuwe tile toevoegen: zet een nieuw `.gox` bestand in de juiste map onder
`assets/tiles/`. Hij verschijnt vanzelf in het palet van de juiste GridMap.
Bestaande item-ID's blijven gelijk, dus je kaarten breken niet: de ID van elke tile
staat in zijn `.tile.json`. De bibliotheken (`assets/libraries/*.res`) staan daarom
niet in git; ze worden gemaakt uit de `.gox`- en `.tile.json`-bestanden, door de
plugin bij het openen van de editor of met
`Godot --headless --script tools/build/build_libraries.gd`. Het register
`assets/libraries/<categorie>_ids.json` (naam -> ID) staat wel in git, als overzicht.


Tiles (opnieuw) genereren
-------------------------
De tiles worden gemaakt door een Python-generator (alleen standaard Python 3):

    python3 tools/voxgen/generate.py              # alleen ontbrekende tiles maken
    python3 tools/voxgen/generate.py --list       # lijst van alle tiles
    python3 tools/voxgen/generate.py --only weg   # alleen tiles met 'weg' in het pad
    python3 tools/voxgen/generate.py --force --only klassiek_rood   # overschrijven
    python3 tools/voxgen/generate.py --dedup      # alleen identieke tiles ontdubbelen
    python3 tools/voxgen/generate.py --palettes   # Goxel-palet, kleurenoverzicht, handleiding

LET OP: `--force` overschrijft bestaande bestanden, dus ook je eigen
aanpassingen in Goxel. Zonder `--force` blijven bestaande tiles staan.
Wil je één tile opnieuw laten genereren: verwijder het `.gox` bestand en draai
de generator. Na het maken van tiles worden identieke tiles (zelfde voxels,
kleuren, materialen en importopties, binnen een categorie) vervangen door
alias-tiles naar de tile met de kortste naam (`dedupe.py`).

Generator-bestanden (`tools/voxgen/`):
- `generate.py`  startpunt: schrijft alles naar `assets/tiles/`
- `palette.py`   kleurenpalet + materiaaltypes (metal/glass/emit/water/flag, ...;
  elke rgb heeft precies één materiaal);
  `VARIATION` (standaard 0,65) dempt de kleurverschillen binnen groepen als
  asfalt1..4, gras1..5 en baksteen1..5 (bestrating zoals tegels en klinkers niet)
- `vox.py`       voxelmodel, tekenfuncties, tile-schrijver (`.gox`), kleurentabel
  (`assets/tiles/materialen.json`) en metadata
- `gox.py`       Goxel-bestanden lezen en schrijven (alleen standaard Python)
- `convert_vox.py`  zet MagicaVoxel-tiles (`.vox`) om naar `.gox`
- `common.py`    maten, registry, pixelfont en pictogrammen
- `dedupe.py`    vervangt identieke tiles door alias-tiles
- `palettes.py`, `handbook.py`   Goxel-palet, kleurenoverzicht en de visuele handleiding (`--palettes`)
- `tiles/`       de tile-modules; `tiles/__init__.py` importeert ze in vaste volgorde:
  - `ground.py`, `ground_extra.py`, `ground_bridges_curves.py`, `ground_rising_curves.py`,
    `ground_junction.py`   grond: wegen, stoepen, pleinen, natuur, water, spoor, tram,
    tunnels, zwembaden, waterkant, bruggen, (stijgende) bochten, op- en afritten
  - `buildings.py`, `building_styles.py`, `building_roofs.py`, `building_campus.py`
    gebouwstijlen, gevels, daken, dakpansoorten, kerken, musea, hallen, parkeergarage,
    radiotoren, universiteit, hogeschool, kolonnades
  - `details.py`, `details_extra.py`   gevel- en dakonderdelen, zonwering, teksten, vlaggen
  - `props.py`, `props_extra.py`   straatmeubilair, borden (RVV), bomen, planten,
    hekken, muurtjes, speeltuin, terras, zwembad, containers, steigers
  - `small_vehicles.py`   brommobiel en trekker met hun wielen
  - `two_wheelers.py`   fietsers, fatbike, brommer, scooter en motorfiets met berijder, in
    voxels van 6,25 cm (import-optie `voxel_size`)
  - `tram_tunnel.py`   tramtunnel, tramhelling naar de tunnel, ondergrondse halte, tram in
    een klinkerbocht en brugdekken met een opening voor trappen
  - `extras_business_paths.py`, `extras_shops_lanes.py`, `traffic_lights_industry.py`
    latere uitbreidingen over meerdere categorieën (bedrijfspand, heuvels, loopbruggen,
    winkels, tunnelbakken, tram- en busbanen, luxe appartementen, groendaken,
    standbeelden, verkeerslichten, loodsen en fabrieken)
  De namen van gevelfuncties bepalen de seed van gebouwen: hernoem ze niet.

Na het genereren (vanuit de projectmap):

    # 1. alle tiles importeren
    tools/godot.sh --headless --import
    # 2. bibliotheken bijwerken (zonder previews)
    tools/godot.sh --headless --script tools/build/build_libraries.gd [-- force]
    # 2b. thumbnails (palet-previews) renderen (met venster, ~1,5 min voor alles)
    tools/thumbnails.sh [alles]
    # 3. de stad opnieuw bouwen (overschrijft scenes/stad.tscn, behalve de keuzes per tile)
    tools/godot.sh --headless --script tools/build/build_city.gd
    # 4. de kaart vooraf baken, zodat het spel snel laadt
    tools/bake.sh

Previews worden bewaard in `.godot/vox_tiles_previews/` (per tile en importtijd); een
bibliotheek die opnieuw gebouwd wordt, krijgt ze daar direct uit terug.
`tools/godot.sh` start Godot met een tijdslimiet (`GODOT_TIMEOUT`, standaard 600 s)
en zonder invoer, zodat een run nooit blijft hangen; de tools in `tools/` stoppen
bovendien zelf na een script-fout (`Common.watchdog`). Elke tool die langer dan een seconde
bezig is, laat zien hoe ver hij is (`tools/progress.gd`: een regel per 5% of elke 10 s, met
de geschatte resterende tijd); de Python-generators zetten `[ n/totaal ]` of een percentage
voor elke regel.

Heb je de kleurentabel (`assets/tiles/materialen.json`) of de `.tile.json` van tiles
aangepast? Dan wil de editor-plugin die tiles bij het openen herimporteren (Godot zelf kijkt
alleen naar het `.gox`). Doe dat vooraf headless, met de editor dicht:

    tools/build/reimport_stale.sh          # verouderde tiles herimporteren + bibliotheken
    tools/build/reimport_stale.sh --list   # alleen laten zien welke verouderd zijn

Baken en thumbnails
-------------------
Twee scripts die je zelf draait (vanuit de projectmap), wanneer je wilt:

    tools/bake.sh                    # de kaart vooraf baken
    tools/bake.sh opnieuw            # alles opnieuw baken (eerst de cache leeg)
    tools/bake.sh scenes/stad.tscn   # alleen deze kaart

Het spel voegt bij het starten de lagen Gebouwen en Grond samen tot grote meshes
(`DetailNiveau`, zie "Hoe het werkt") en bewaart dat in `user://merged/`. Zonder cache duurt
dat minuten; `bake.sh` doet het vooraf, headless (zonder venster, de editor mag open blijven),
zodat het spel alleen hoeft te laden. Een kaart waarvan de cache klopt wordt overgeslagen, dus
het kan geen kwaad om het vaak te draaien. Draai het na het bouwen van de stad, na het
opnieuw opbouwen van de tiles en na een wijziging aan `layer_baker.gd`. Het ruimt ook de
cache van kaarten op die niet meer bestaan.

    tools/thumbnails.sh              # thumbnails van tiles die er nog geen (actuele) hebben
    tools/thumbnails.sh alles        # alle thumbnails opnieuw
    tools/thumbnails.sh bouwen       # eerst de bibliotheken bijwerken (build_libraries.gd)

`thumbnails.sh` rendert de palet-previews van alle tiles (`tools/build/build_previews.gd`)
in een klein venster rechtsonder (renderen kan niet headless), zodat de editor bij het
openen van een scène geen "Creating mesh previews" meer hoeft te doen. Doe het liefst met
de editor dicht: die schrijft dezelfde bibliotheken. De beide scripts gebruiken
`tools/godot.sh` (tijdslimiet `GODOT_TIMEOUT`, de Godot-app in `GODOT`).

In de editor staat ook: Project > Tools > "Vox Tiles: bibliotheken volledig
herbouwen" (maakt collision en alle previews opnieuw; handig als een preview
niet meer klopt na een `--force`).


Hoe het werkt (techniek)
------------------------
- `addons/vox_tiles/importer/vox_import_plugin.gd`: importer voor `.gox` (en `.vox`).
  Leest het model (`gox_parser.gd` of `vox_parser.gd` naar `voxel_model.gd`, dat
  ook het materiaal per kleur bepaalt) en maakt een mesh (`vox_mesher.gd`) met greedy
  meshing, vertex-kleuren en ingebakken ambient occlusion. Per materiaaltype
  een eigen surface en shader (`materials/`: opaque, metal, glass, emit,
  water, vlag).
- `addons/vox_tiles/library/library_builder.gd`: bouwt per map onder `assets/tiles/`
  een MeshLibrary in `assets/libraries/` (grond, gebouwen, details, props),
  met previews en collision. Item-ID's blijven stabiel op naam.
- `addons/vox_tiles/plugin.gd`: houdt de bibliotheken automatisch bij als er
  tiles bijkomen, verdwijnen of opnieuw geïmporteerd worden.
- `scripts/camera/free_camera.gd`: vliegcamera; `scripts/world/tint_map.gd` en
  `scripts/world/tint_area.gd`: tint-systeem.
- `tools/build/build_city.gd`: bouwt de stad via code. De bouwer staat in
  `tools/build/city/`, een keten van
  scripts die elk het vorige uitbreiden. Eerst de algemene delen: `base` (toestand, scene,
  `G/B/D/Pr`) -> `kit` (herbruikbare helpers) -> `street_grid` (straten, kruisingen,
  stoepranden); dan die van Den Haag: `map` (het stratengrid, namen van wijken en straten,
  gedeelde posities en kleine helpers) -> `streets` (straten, singel, bruggen) ->
  `old_centre` -> `east` -> `south` -> `a12` (met Voorburg) -> `rail` (trams, tramtunnel,
  viaducten, spoor) -> `finishing` (rondes over de hele stad, camera en hulpnodes).
  `build_city.gd` zelf is alleen de volgorde van de bouw. Een deel kan alleen functies uit
  zichzelf of een eerder deel aanroepen (de keten staat in `base.gd`). Handige helpers om zelf kaarten te scripten: `G/B/D/Pr` (één
  tile per laag, `base.gd`), `block()` (rechthoekig gebouw met automatisch de juiste
  hoek-, gevel- en dakstukken), `ring()` (gesloten bouwblok met kappen om de hoek),
  `tower()` (alle in `kit.gd`).
  Een paar regels houden de stad logisch: een begane grond die tegen de muur van een ander
  gebouw ligt, krijgt geen deur, portiek of winkelpui maar ramen (`_faces_building` in
  `kit.gd`, voor `block()` en `ring()`; de achterkant van een rij winkelhuizen heeft altijd
  ramen); een gebouw dat los in het gras staat, krijgt een pad van zijn ingang naar de
  dichtstbijzijnde stoep (`_paths_to_lonely_buildings`). Onder een gebouw komt nooit gras:
  waar je de vloer ziet (glazen hallen, overkappingen, pilaren) ligt bestrating. Hoge glazen
  hallen (`_tall_hall`) hebben op de begane grond glazen deuren met een eigen afdakje (de
  stationshal, het atrium van Castalia, de wintertuin, de Statenzaal). Kades hebben overal
  dezelfde kadebestrating. Het Binnenhof heeft poorten op straatniveau (Stadhouderspoort naar
  het Buitenhof, naar het Plein, naar de Hofvijver en naar de Grote Marktstraat). Een straat
  krijgt één thema over zijn hele lengte (`_dress_streets`), zodat strepen en stroken van
  kruising tot kruising doorlopen. Naast Centraal Station ligt een tramhalte aan de sporen
  langs het stationsplein (`STATION_TRAM_STOP_ROWS`). Gesloten bouwblokken (`ring()`)
  zijn langs elke kant een rij panden van 4 cellen die soms een laag hoger of lager zijn
  (`_ring_floors`, nooit onder 3, de hoeken op de blokhoogte; `"vary": false` houdt het
  blok vlak); in een winkelrij is af en toe een pand een laag hoger. Daken krijgen waar het
  klopt installaties (`_roof_equipment`): kantoren luchtbehandeling, koelunits en
  installatiedaken, flats zonnepanelen en ventilatiekappen, loodsen en fabrieken grote
  zonnepanelenvelden, huizen zonnepanelen op het zuid- of westdakvlak en soms een airco;
  kerken, musea en monumenten (`BARE_ROOF_STYLES`) blijven kaal.
- `tools/check/coverage.gd`: telt welke tiles in de stad liggen.
- `tools/shots/shot_tiles.gd` / `tools/shots/shot_scene.gd` / `tools/shots/shot_iso.gd`: maken
  screenshots van tiles of scenes, ook isometrisch (voor controle).

Belichting (in `tools/build/city/base.gd`, functie `_make_scene`): een zon
uit het oost-noordoosten met schaduwen (in de isometrische stand, de camera in het
noordoosten, krijgen zowel de noord- als de oostgevels licht), een zacht blauwig vullicht zonder schaduw,
lucht-ambient, SSAO, glow en een lichte kleur/contrast-correctie. Pas
`Zon`, `Vullicht` en `Omgeving` in de scene aan voor een andere sfeer.


Prestaties en uiterlijk
-----------------------
- Shader-globals (Project > Shader Globals, 0 = uit, 1 = normaal): `zwervr_relief`
  (alle reliëf, scheurtjes, putjes, asfaltkorrel en grindschaduw), `zwervr_grass`,
  `zwervr_undulation` (de grond wordt belicht alsof hij zacht golft: een trage
  hoogtekaart van brede glooiingen van ~18 en 40 m kantelt alleen de normaal, heel licht; sterk op gras, zwakker op plaveisel, nauwelijks op asfalt) en
  `zwervr_far_noise`. Bakstenen zijn in de shader 6 x 2 voxels (`brick_scale` = 2 in
  `voxel.gdshader`), klinkers en natuursteen 3 x 1,5 voxels in halfsteensverband
  (`block_size`), stoeptegels 4 x 4 voxels (`tile_size`); grind: kiezels van ~4,5 cm (`pebble_size`). Asfalt heeft geen scheurtjes maar het patroon van
  echt asfalt: steentjes van ~4 cm in donkere bitumen (Voronoi), elk een eigen
  grijstint met een bolle bovenkant waarop de zon glinstert, plus zachte slijtplekken;
  dichtbij worden de voxelblokjes van 12,5 cm eerst verzacht (gemiddeld met de
  buur-texels), zodat het patroon de structuur draagt en niet het voxelraster.
- `DetailNiveau` (`scripts/world/level_of_detail.gd`): schakelt bij het uitzoomen naar
  grove tiles (`coarse_from`, standaard 100 m in beeld: daar is een voxel al kleiner
  dan een pixel) en heel grove tiles (`very_coarse_from`, 130 m), voor Grond,
  Gebouwen en Props (bomen: een plataan 9.500 / 5.800 / 1.500 driehoeken), verbergt
  Details (vanaf 120 m) en Props (vanaf 300 m), past de schaduwafstand aan het
  zoomniveau aan. De grove versies
  maakt de importer zelf: gelijkende kleuren samengevoegd (`lod`) en blokjes
  van 2x2x2 voxels (`lod2`). Een blok krijgt de kleur van zijn bovenste laag; is
  die laag dun (bloemen of plukjes met aarde ertussen), dan telt wat je van boven
  ziet en wisselen bloemen en aarde elkaar af in een dambord. UV2 van `lod2` blijft
  in voxels van het volle model, zodat stenen en tegels in de shader even groot
  blijven. De grove bibliotheken (`*_lod.res`, `*_lod2.res`)
  worden automatisch gemaakt en staan in `.gitignore`.
- Ook het volle detailniveau voegt bijna gelijke kleuren samen (import-optie
  `color_merge`, standaard 14) voor minder driehoeken; de fijne korrel
  komt uit de shader (`voxel_noise`). Gras en boomkruinen hebben hun detail in de
  kleur van de voxels, niet in uitstekende voxels.
- Schaduwen: vlakke tiles (lager dan 0,7 m) en kleine details werpen geen
  schaduw; de zon gebruikt 4 schaduwsplits (4096 px). Bij het samenvoegen werpen
  ook de lage driehoeken (minder dan 0,7 m boven de onderkant van hun tile, op de
  onderste rij cellen) van schaduwwerpende tiles geen schaduw: een sloot of kade
  werpt alleen nog de schaduw van zijn riet of muur. De schaduwpass tekent de
  geometrie opnieuw en is de grootste kostenpost na de geometrie zelf.
- Rendering (`project.godot`): render-resolutie 85% met temporele upscaling (vrijwel niet te zien naast 100%, ~13% sneller; bij 77% werd het van ver korrelig en kartelig) en anti-aliasing: MetalFX op macOS, FSR 2 elders (MSAA/FXAA uit), debanding,
  depth prepass uit; GridMaps gebruiken octant-grootte 4 (snelst gemeten).
- Samenvoegen (`scripts/world/layer_baker.gd`, aangestuurd door `DetailNiveau`, export
  `merge_layers`): bij het starten worden de lagen Gebouwen en Grond samengevoegd tot
  grote meshes (chunks van 8x8 cellen, per LOD-niveau). Zijden die tegen een
  dichte buurcel liggen en alle onderkanten vallen daarbij weg. De importer
  groepeert de driehoeken daarvoor per celzijde (import-optie `cell_block`: 4x3x4 voor
  gebouwen, 4x1,5x4 voor grond). Komt de stad uit de golf van een scèneovergang
  (`WarpTransition`), dan staat het laadscherm er meteen maar begint het samenvoegen pas als de
  golf is uitgedeind, zodat die niet schokt. Tot het samenvoegen klaar is, staat er een laadscherm
  (export `loading_screen`; in de stijl van de HUD: inktblauw, "ZWERVR", een blokjesbalk met
  percentage, en hetzelfde CRT-beeld met de instellingen van de HUD, `UiStyle.make_crt_overlay`,
  dat met het scherm mee uitfadet; `scripts/ui/loading_screen.gd`); het resultaat wordt
  bewaard in `user://merged/`, zodat de volgende keer direct klaar is (zolang de kaart en de
  tiles niet veranderen). `tools/bake.sh` vult die cache vooraf (zie "Baken en thumbnails").
  Je bewerkt gewoon de GridMaps; botsingen blijven daar ook. Tiles met een vlag
  blijven losse meshes (de vlag-shader rekent in lokale coördinaten).
- `Dagcyclus` (`scripts/world/day_cycle.gd`): basis voor dag en nacht (`time_of_day`,
  start 13:00; `speed` 0,08 uur per seconde: een dag duurt 5 minuten, 0 = stilstaan; een
  Nederlandse zomerdag: zon op `SUNRISE` 5:30, onder `SUNSET` 22:00, blauw uur tot ruim tien,
  pas rond half twaalf echt donker). De tijd
  loopt en zon, vullicht, omgevingslicht, lucht en de shader-global `zwervr_night` (verlichte
  ramen, lampen, borden, koplampen) volgen hem, met de kleuren van het moment (`DAY_COLOURS`:
  blauw uur, roodoranje zonsopkomst, gouden uren, wit middaglicht, rode zonsondergang onder
  violet, diepblauwe nacht met maanlicht; ertussen vloeiend gemengd); dat wordt elke `APPLY_STEP_HOURS` (0,02 uur)
  bijgewerkt, niet elk frame, omdat de lucht bij elke kleurwijziging opnieuw wordt gebakken. De zon staat rechts in beeld (ze draait mee met
  `ROTATION.y` van `scripts/camera/iso_camera.gd`), zodat de schaduwen naar links vallen (bij de
  start, 13:00, recht naar links en iets omhoog; 's ochtends iets omlaag, 's avonds meer
  omhoog) en de gevels licht
  houden, en blijft tussen `min_elevation` (36°) en `max_elevation` (44°) hoog: geen
  lange schaduwen. Alle licht is realtime.
- Ruis van ver (`voxel.gdshader`, sterkte in de shader-global `zwervr_far_noise`,
  Project > Shader Globals, 0 = uit): zodra je zo ver bent uitgezoomd dat een voxel
  kleiner wordt dan een pixel, krijgt de grond (bovenvlakken op straathoogte, lager dan
  2,5 m) een rustige ruis in wereldcoördinaten: vlekken van ~12, 4 en 1 m in helderheid,
  en bij gras en aarde ook in tint. Alles komt uit de shader; de tiles en LOD-modellen
  zelf veranderen niet. Dichtbij, op daken en op asfalt doet hij niets.
- Gras en grind (`voxel.gdshader`, sterkte gras in de shader-global `zwervr_grass`,
  0 = uit): geen echt reliëf, alleen kleur die het gevoel van reliëf geeft, dus goedkoop
  en zonder flikkeren. Gras wordt aan zijn kleur herkend (duidelijk groen, bovenvlakken):
  een korrel van 60 en 20 cm (geen vlekken van ver; uitgezoomd zachter), en dichtbij lange, dunne grassprieten. Grind
  (`gravel()`) ligt in wereldcoördinaten (naadloos over tiles heen): losse kiezels van
  ~4,5 cm in een onregelmatig patroon (geen raster), bemonsterd op een raster van een
  kwart kiezel zodat elke steen een blokkerige voxelrand heeft; per kiezel een eigen tint
  (iets warmer of koeler, een paar duidelijk lichter of donkerder), een bolle bovenkant
  die de normaal kantelt en donkere spleten. Daaronder grovere stenen (~12 cm) in rustige
  tinten en zachte vlekken van ~25 cm. Elke laag vervaagt zodra hij een pixel of twee
  klein is, dus van ver is grind egaal, zonder flikkeren.
- Echte grassprieten (node `Grassprieten`, `scripts/world/grass_blades.gd`, shader
  `materials/grass_blade.gdshader`) in drie detailniveaus die in elkaar overgroeien:
  fijne sprieten tot `show_from` (48 m in beeld, helemaal vol tot `full_from`, 40 m: ook bij de
  loopzoom van de Volgcamera, 38 m), daarna dikkere plukken (`medium_*`, tot
  55 m) en nog grovere, schaarse plukken (`far_*`, tot 220 m, die twee over het hele beeld;
  uit met `low_detail`). Ingezoomd groeien hoekige sprieten in voxelstijl uit het gras (drie vierkante blokjes van 3 x 3 cm
  op elkaar, getrapt in de buigrichting, elk een eigen tint, alleen in kwartslagen gedraaid) rond het punt waar de camera
  naar kijkt, met een MultiMesh per stuk van 8 x 8 m. Ze buigen met dezelfde wind en
  windvlagen als de grasshader, staan in plukken (dicht, dun, kaal) en groeien alleen
  op het grasdeel van een tile (`GrondKaart` houdt per grastile een masker bij), dus
  niet op paden, oevers onder water of waterlelies. Instelbaar: `density` (220 sprieten
  per m², vol en dicht), `blade_height`, `blade_width` (3 cm, dun), `show_from`/
  `full_from`. Uitgezoomd worden de sprieten rustiger (shader-parameter `calm`, van 30 tot 90 m
  in beeld): de zijkanten worden bijna zo licht als de toppen en het verschil per spriet en
  van voet tot top wordt kleiner, zodat een grasveld van ver niet spikkelt. Kost op 2560 x 1440 ongeveer 20% framerate zolang ze in beeld zijn; een
  lagere `density` is de snelste winst.
- Randen tussen grondtiles (`zwervr_ground_edges`, 0 = uit): waar een grondtile een
  andere soort grond raakt (gras, weg, fietspad, stoep, grind, klinkers, ...), tekent de
  shader een rand die leest als een klein hoogteverschil, zonder echte geometrie. De
  `GrondKaart` (`scripts/world/ground_map.gd`, globals `zwervr_ground_types` en
  `zwervr_ground_area`) kent elke 4 x 4 m-cel een soort toe (hoofdmateriaal plus
  kleurgroep, dus rood fietspadasfalt is iets anders dan grijs wegasfalt) en een
  nep-hoogte (`RANK`: weg laagst, fietspad, klinkers, grind en aarde, gras, stoep
  hoogst); hij wordt opnieuw gemaakt bij elk deel en in de editor elke 2 s. De hogere
  kant krijgt een afgeronde, lichtere rand (de normaal kantelt ook, dus de zon maakt
  hem licht of donker), de lagere een contactschaduw, en ertussen ligt een donkere voeg.
- Ramen (`voxel_glass.gdshader`, `interior`): gebouwtiles zijn hol, dus door het glas
  zag je de witte binnenkant van andere gevels (kozijnen, dakkapellen). Tiles waarvan
  minder dan 30% van het oppervlak glas is (ramen, deuren, etalages) krijgen daarom
  ondoorzichtig glas met een nep-kamer erachter: donker, per raam een andere tint, iets
  lichter naar het plafond, 's nachts brandt in ongeveer een derde het licht. Dat zet
  `library_builder.gd` (`_set_interior`) bij het bouwen; glazen hallen, overkappingen,
  het penthouse en moderne glazen ramen/deuren krijgen getinte diepte (zie hieronder).
- Vlakke tiles: grond, muren en daken hebben in de tiles één vlakke kleur per soort
  (`FLAT_GROUPS` in `tools/voxgen/palette.py`: alle leden van bv. gras1..gras5 krijgen
  de gemiddelde kleur en één kleur-id). Het detail komt uit de shaders: korrel, steentjes,
  verband, gras, reliëf en per steen een eigen tint. Groepen met bewust verschillende
  kleuren (bladeren, gordijnen, reclame, glas, hout, metaal, ...) houden hun variatie.
- Glas is ondoorzichtig en lijkt alleen op glas (`voxel_glass.gdshader`): een
  nep-weerspiegeling van lucht, horizon en stad (sterker onder een schuine hoek), bij
  ramen een nep-kamer erachter, bij grote glasvlakken een gedempte, getinte diepte.
- Bomen en planten bewegen in de wind (`materials/voxel_wind.tres`:
  `wind_strength`, `wind_speed`, `wind_height`); de importer kiest dit
  materiaal automatisch voor `props/bomen`, `props/planten`, hagen, bloembakken
  en riet (metadata `"animation": "wind"`, of import-optie `animation`). Tiles met wind (of een vlag) worden niet
  samengevoegd, omdat die shaders in lokale coördinaten rekenen.
- Bloemperken in de grond (tulpen) wiegen sneller en over een kortere hoogte
  (`materials/voxel_wind_bloem.tres`, animatie `"flowers"`): alles boven `wind_base`
  (het grondoppervlak van de tile) buigt mee, vol op `wind_height` (0,4 m) erboven.
  In de polder naast het park ligt een bollenveld.
- Gras: `natuur/gras` (kort, in de stad) en `natuur/gras_hoog` (hoog, in de polder) zijn
  dezelfde egale tile; ze verschillen alleen in de lengte van de grassprieten
  (`SHORT_GRASS`/`TALL_GRASS` in `scripts/world/ground_map.gd`: kort gras ~30 cm, hoog
  gras ~65 cm). Ook `gras_droog` is in het palet gewoon gras.
  Dichtbij tekent de shader lange, dunne grassprieten van ~30 cm die in de windrichting overhellen
  en elk een beetje wiegen, en op elke afstand trekken windvlagen als lichtere stroken
  langzaam over het gras (de sprieten buigen daar verder door).
- HUD (node `HUD`, een CanvasLayer met `scripts/ui/hud.gd`, door `tools/build/city/base.gd`
  bij de hulpnodes gezet; ontwerp "HUD — open world", 1280 x 720, schaalt mee met het venster,
  de hoeken blijven in de hoeken). Pixelstijl: inktblauwe panelen (#141831/#0B0D1A), randen
  #343B70, harde schaduw van 5 px, geen ronde hoeken; lettertypen Silkscreen, Pixelify Sans en
  JetBrains Mono (`assets/fonts`, OFL, licenties in `OFL_*.txt`; Rubik als er een ontbreekt).
  - Linksboven: portret met niveau (`set_player(naam, niveau)`) en de stats als blokjesbalken
    met eigen icoon en kleur: `gezondheid`, `uithoudingsvermogen`, `honger`,
    `overprikkeldheid` (`set_stat(naam, waarde, maximum)`, `get_stat`; nieuwe stats in `STATS`).
    Daaronder de ervaring: een dunne balk (teal) met "XP 6.420 / 10.000" (`set_xp(punten, punten_voor_niveau)`).
  - Midden boven: de melding, in- en uitfaden: "nieuw gebied ontdekt" met de naam
    (`show_area(naam)`) of "nieuwe missie" met de titel en het missiedeuntje
    (`show_mission(titel)`, `deuntje_nieuwe_missie.ogg`); één tegelijk, de volgende wacht.
  - Rechtsboven: kaartje van 200 x 200, noord boven, pijl in het midden (de gevolgde auto van
    de `Volgcamera`, anders het punt waar de camera naar kijkt). Geen extra camera: één
    afbeelding, één pixel per cel van 4 m, gemaakt bij het starten uit `Grond` (kleur per soort
    grond, `MINIMAP_KINDS`) en `Gebouwen` (donker); `minimap_metres` (160) in beeld. Daaronder
    dag en tijd uit de `Dagcyclus` (de dag telt op na middernacht; zonder Dagcyclus `set_time`).
  - Rechts: opdrachten (`set_quests([...])`, verborgen zolang de lijst leeg is; voorbeelden
    alleen met `show_example_quests`).
  - Rechtsonder: geld in euro (`set_money`).
  - Waar je bent, in een vak even breed als het kaartje erboven (de gevolgde auto, anders het punt waar de camera naar
    kijkt): de wijk, de straat en de dichtstbijzijnde bekende plek (binnen `place_near`, 45 m).
    De bouwer zet de wijken (`WIJKEN`) en straten (`STRATEN`, in cellen, met de stoep ernaast)
    als scènemetadata `wijken` en `straten` in `city/map.gd`; plekken komen uit `places`. Kom
    je voor het eerst in een wijk, dan meldt de HUD die als nieuw gebied (`show_area`).
  - CRT-beeld over het hele beeld: de wereld bolt als een beeldbuis en de randen buigen naar
    zwarte, afgeronde hoeken (`crt_curvature` 0,05, `crt_corner` 0,035). De HUD wordt eerst in
    een eigen SubViewport (`HUDBeeld`) getekend en buigt in dezelfde shader mee, maar minder
    (`crt_ui_curvature` 0,02), zodat de hoeken leesbaar blijven; de zwarte hoeken snijden de HUD
    niet af. Scanlijnen (`scanlines`, `scanline_strength` 0,1) en een iets donkerdere rand
    liggen over beide.
  Test: `tools/godot.sh --headless --script tools/check/hud_test.gd`.
- Spelmenu (`scripts/ui/game_menu.gd`, `GameMenu`, een CanvasLayer die de HUD als kind
  krijgt; ontwerpen "Inventory & character", "Questlog" en "Wereldkaart", 1280 x 720, schaalt
  mee zoals de HUD, met scanlijnen en de lichte buiging van de HUD). Helemaal in code
  opgebouwd. Bovenin een tabbalk "[Q] INVENTARIS QUESTS KAART [E]" (open tab amber), rechts
  het geld en "[ESC] SLUITEN".
  - INVENTARIS: links het karakter (naam, "LV n · subtitel", het figuur in 3D dat langzaam
    draait, de vier stats als blokjesbalken), midden ALLES/ETEN/DRINKEN/SPULLEN/SLEUTEL en een
    raster van 6 x 5 vakjes (rand in de kleur van de zeldzaamheid, aantal rechtsonder), rechts
    het gekozen ding: zeldzaamheid, naam, soort, effecten (groen = goed voor je, rood = slecht;
    bij `overprikkeldheid` is minder goed), de tekst cursief, de knop uit `action` (ETEN,
    DRINKEN...) als het iets doet en WEGGOOIEN (niet bij sleutelvoorwerpen). De spullen staan
    in `scripts/player/items.gd` (`ITEMS`, `START_ITEMS`); de pixeliconen bij `icon` staan in
    `GameMenu.ITEM_ICONS` (of de HUD-iconen `heart`, `bolt`...), zonder icoon dat van de soort.
  - QUESTS: links VERHAAL / ZIJMISSIES met de opdrachten uit `hud.quests()` (het formaat van
    `set_quests`; optioneel ook `description`, `giver`, `rewards` = lijst teksten en per stap
    `progress`), rechts de gekozen opdracht met doelen (vinkjes) en beloningen. Zonder
    opdrachten: "Nog geen opdrachten. Zwerf wat rond."
  - KAART: de hele kaart van het kaartje (`hud.minimap_texture()`, pixels scherp), de speler als
    witte driehoek, de plekken uit `places` als blokjes (klikken of pijltjes), wijken waar je
    nog niet was (`hud.visited_areas()`) onder een mist. Rechts de gekozen plek (naam, wijk,
    afstand), waar je nu bent (wijk en straat) en een legenda; linksonder X/Y in meters.
  - Toetsen: Tab of I opent de inventaris, J de quests, M de kaart; Q/E wisselt van tab; Tab,
    Escape of nog eens dezelfde letter sluit. Pijltjes of WASD kiezen, Enter gebruikt, X
    gooit weg, 1-5 kiest een soort; de muis werkt ook. Open = het spel staat stil (de boom
    gepauzeerd); niet tijdens het pauzemenu of als de speler dood is.
  - Gegevens van de node `Speler` (`archetype_id`, `level`, `money`, `stat(naam)`,
    `inventory`, `use_item`, `drop_item`, `is_dead`, signalen `inventory_changed` en
    `stats_changed`); zonder speler het gekozen karakter en zijn `START_ITEMS`.
    API: `open(tab)`, `close()`, `is_open()`.
  Test: `tools/godot.sh --headless --script tools/check/game_menu_test.gd`.
- Lettertype: Rubik (`assets/fonts/Rubik.ttf`, OFL-licentie), ingesteld als
  projectfont.
- Meten: `Godot --script tools/check/fps_test.gd -- 20 flyover` of
  `-- 10 140` (vaste zoom 140 m), of een vast beeld met vlaggen:
  `-- 10 140 72 60 s` (drukke wijk rond x 72, z 60, zonder schaduw). Sluit de Godot-editor tijdens het meten, anders
  delen ze de GPU. `tools/check/triangle_count.gd` toont het aantal driehoeken per tile en
  LOD-niveau.

Afgeronde bochten
-----------------
In `grond/bocht/` staan bochten voor hele straatprofielen (straat,
klinkerstraat, weg, hoofdweg, tramweg, laan, fietspad). Elke bocht bestaat uit
(n x n) tiles: `<profiel>_<i>_<j>`, met n = 1 + aantal delen van het profiel.
De weg komt van het zuiden en buigt af naar het westen; leg cel (i, j) op
(x + i, z - j) en draai alles samen.
