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
Kerk, wit stadhuis en Amare. De Grote Markt heeft cafés en terrassen aan drie kanten. Winkels
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
overdekte Parnassusplein als glazen atrium ertussen) en de donkere Muzentoren (25 lagen), het
Beatrixkwartier en de kantoren aan de Prins Clauslaan. De A12 (Utrechtsebaan) komt van
de oostrand als snelweg binnen, zakt in twee tunnelbakken en gaat overkapt verder van
de Laan van NOI tot de Juliana van Stolberglaan; op het dek erboven staan de
Malietoren, een rij winkels met Snackbar De Vrijheid en kantoren. Tussen Haagse Bos en
Malieveld komt hij weer boven bij een kruispunt met stoplichten aan de Koningskade,
naast het ministerie. Drie tramlijnen (Kneuterdijk - Korte Voorhout - Malieveld en
Grote Marktstraat - Spui - Centraal, verbonden met bogen via de Buitenhof) met haltes.
Vier bruggen gaan over de oostarm van de singel: Mauritskade, de twee tramstraten en
Zuidwal. Het RandstadRail-viaduct (rijen z 90-91) begint met een helling naast Centraal
Station en loopt naar het oosten, met haltes bij Centraal en het Beatrixkwartier, en verder
tot de kaartrand. Twee sporen langs de westkant van het station (x 72-73) sluiten het aan op
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
in zijn park; loodsen 9 m, bedrijfsunits 6 m hoog). De kaart is zo een vierkant van 176 x 176 cellen (x en z 0..175, 704 x 704 m). Over het vlakke deel van de A12 (x 160) gaat een voetbrug met trappen van de
kantoren aan de Prins Clauslaan naar de straat z 29. Opnieuw bouwen:
`tools/godot.sh --headless --script tools/build/build_city.gd`.

De game start met deze kaart (`run/main_scene` = `scenes/stad.tscn`): de node
`Rondvlucht` (`scripts/camera/fly_over.gd`) laat de iso-camera langzaam in een ronde
langs alle buurten glijden: boven elke buurt zoomt hij in, onderweg weer uit
(instelbaar: `speed`, `zoom_near`, `zoom_far`, `route`).
Een toets, muisklik of scroll geeft de camera aan jou (vrije camera); `active` uit =
meteen zelf rondkijken. Over het beeld ligt een vignet (node `Vignet`,
`scripts/effects/vignette.gd` + `vignette.gdshader`) dat alleen de randen wat afdonkert
(het begint op 75% van het midden, `inner`; het midden blijft schoon)
(`strength`, `inner`, `softness`, uit met `enabled`): een laag die over het beeld wordt
gemengd, zonder schermkopie of blur, dus vrijwel gratis. Er is geen tilt-shift en geen
scherptediepte (DOF) meer: het beeld is overal scherp.

Op de rails rijden twee RandstadRails (`scripts/vehicles/randstadrail.gd`, twee wagons, 22,25 m) en
twee NS-treinen (`ns_train.gd`, drie wagons, 40 m; elk blijft op zijn eigen spoor, `own_track`), beide op `rail_vehicle.gd`. Ze passen op hun perrons: een tramhalte
is 6 cellen (24 m), een treinperron 11 cellen (44 m); `tools/check/rail_stop_test.gd` controleert dat. Wat erop mag rijden staat
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

Stoplichten werken: de node `Verkeerslichten` (`scripts/world/traffic_lights.gd`, in
elke scène die de bouwers maken) laat de stoplichtprops (`verkeerslichten/auto_*`,
`fiets_*`, `ov_*`, `voetganger_*`, `mast_*`) per kruispunt een vaste cyclus doorlopen:
noord-zuid groen, oranje, alles rood, oost-west groen, oranje, alles rood. De richting
van een licht volgt uit zijn draaiing; tijden zijn instelbaar op de node.

Er rijdt verkeer door de stad: een sedan, node `Auto` (`scripts/vehicles/car.gd`), en een
SUV, node `SUV` (`scripts/vehicles/suv.gd`), staan in de scène; de node `Verkeer`
(`scripts/world/traffic.gd`) zet er bij het starten nog `vehicle_count` (24) voertuigen bij,
verspreid over het wegennet (`spacing`, `traffic_seed`, de mix in `MIX`). Soorten:

| Script | Model (`voertuigen/`) | Lengte | Massa | Koppel wielen |
|---|---|---|---|---|
| `hatchback.gd` | `auto_hatchback`, `_zilver`, `_groen` | 3,9 m | 1100 kg | 1155 Nm |
| `car.gd` | `auto_sedan`, `_wit`, `_zilver` | 4,5 m | 1300 kg | 1220 Nm |
| `trailer_car.gd` | `auto_hatchback_zilver` + `auto_trekhaak` + `auto_aanhanger` | 3,9 + 3,3 m | 1100 + 500 kg | 1155 Nm |
| `suv.gd` | `auto_suv` | 4,8 m | 2100 kg | 1575 Nm |
| `van.gd` (busje) | `auto_busje` | 5 m | 2400 kg | 1800 Nm |
| `truck.gd` (vrachtwagen met laadbak) | `auto_vrachtwagen` | 7 m | 7500 kg | 4875 Nm |
| `city_bus.gd` (stadsbus, mag op de busbaan) | `auto_stadsbus` | 10,5 m | 12000 kg | 6600 Nm |

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
  de stad (stoepranden, middenbermen, gebouwen en props in de GridMaps), tollen en
  schuiven uit, met de alarmlichten aan. Na 8 s worden ze weggesleept naar de dichtstbijzijnde
  vrije plek op de rijstrook en rijden ze verder.
- Vastlopen: wachten voertuigen in een kring op elkaar (niet in de rij voor een stoplicht of
  zebra), dan wringt er na een tijdje één langs de ander (`SQUEEZE_TIME`).
- De voorwielen sturen hooguit 40° (`max_steering_degrees`): een wiel steekt dan wat uit de
  wielkast, net als bij een echte auto.
Druk op F en de camera volgt de sedan (node `Volgcamera`, `scripts/camera/follow_camera.gd`). Die jaagt de
auto niet zelf na, maar een punt dat doorlopend vóór de auto ligt: waar hij over
`lead_time` seconden is bij zijn gladgestreken snelheid (`velocity_smoothing`, begrensd
tot `max_lead` van het beeld). Daar volgt hij op een kritisch gedempte veer
(`glide_time`), zodat de camera bij een constante snelheid even gelijkmatig meebeweegt
en bij optrekken en remmen geleidelijk meegaat.
Hij zoomt van 16 m in beeld bij stilstand (`zoom_still`) tot 55 m (`zoom_fast`) en gaat
mee de tunnelbak in. Rijdt de auto onder iets door, dan zakt de camera al in de open bak
achter hem en volgt hem als achtervolgcamera door de tunnel, die zijn eigen lampen heeft
(node `Tunnelverlichting`, `scripts/world/tunnel_lights.gd`); pas als auto en camera weer
buiten zijn, glijdt hij omhoog (`tunnel_*`). Om de 20 tot 35 s (`closeup_every`) maakt hij een close-up: hij
zoomt in tot 7 m, zakt wat lager en zwaait om de auto heen (`closeup_*`, uit met
`closeups`). Tijdens het volgen laat B de SUV als spookrijder op de gevolgde auto
inrijden (demo-botsing, `Vehicle.drive_into`), en zet T het spel op 4× snelheid en weer
terug (`fast_forward`, de physics-stappen schalen mee). Tab volgt het volgende voertuig en
Shift+Tab het vorige, ook de treinen en trams (die staan in de lijst vlak vóór de sedan, dus
Shift+Tab is er het snelst). Het beeld glijdt er in `switch_time` seconden heen en zoomt op een
lange weg wat uit (`switch_zoom_out`, `switch_zoom_out_most`); F volgt daarna het laatst gevolgde
voertuig. Een andere toets geeft je de vrije camera terug. De auto rijdt met een vaste
stap van 60 Hz; zijn carrosserie (node `Carrosserie`) wordt elk frame tussen de laatste
twee stappen gezet, zodat hij bij elke framerate vloeiend beweegt.
- Doorkijk (node `Doorkijk`, `scripts/world/building_fade.gd`): zolang de camera de auto
  volgt, vervaagt elk gebouw (aaneengesloten cellen van de laag Gebouwen) dat tussen de
  auto en de camera staat als geheel, en komt terug als het zicht weer vrij is. Alles wat
  uit hun cel steekt (erkers, winkelpuien, luifels) en hun gevel-details vervaagt mee: de
  samengevoegde gebouwen dragen per vertex de cel waar ze bij horen (`layer_baker.gd`,
  CUSTOM0) en de shader kijkt die cel op in een fade-kaart (`voxel_fade.gdshaderinc`).
  Objecten op straat (props: bushokjes, lantaarnpalen, bomen) vervagen niet.
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
- Wegennet (`scripts/world/road_network.gd`, `RoadNetwork`): het wegennet leest de
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
- Rijrichtingen in de editor: de node `Rijrichtingen` (`scripts/world/lane_arrows.gd`)
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
  (`_square_corners` in `build_city.gd`). Test: `tools/godot.sh --headless --script
  tools/check/corner_test.gd`.
- Voertuig (`scripts/vehicles/vehicle.gd`, `Vehicle`): de rijlogica voor elk
  voertuig. Het plant een paar cellen vooruit (minstens de remafstand), kiest op
  kruisingen willekeurig (`straight_chance`, `route_seed`) en remt af voor bochten
  en een lagere maximumsnelheid. Het stopt voor zebrapaden en rode lichten, voegt
  geleidelijk in waar een rijstrook ophoudt en keert op doodlopende wegen. Het rijdt
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
- Test van de richtingen per tile: `tools/godot.sh --headless --script tools/check/lane_choice_test.gd`
- Test: `tools/godot.sh --headless --script tools/check/drive_test.gd -- 300`
  (optioneel startcel en richting, bv. `-- 300 70 24 1 0` voor de A12). De test meldt
  of de auto ergens naast de weg rijdt, boven of onder het wegdek zit, te hard gaat of
  te scherp draait.


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
    scenes/                stad.tscn, nieuwe_kaart.tscn
    scripts/               spelcode
      camera/              free_camera, iso_camera
      world/               level_of_detail, layer_baker,
                           ground_map, tint_map, tint_area
      effects/             day_cycle, smoke, grass_blades, vignette
      vehicles/            vehicle en de voertuigen (auto's, RandstadRail, NS-trein)
    tools/                 command-line tools (start ze met tools/godot.sh)
      godot.sh             Godot met tijdslimiet en zonder stdin
      tool_common.gd       gedeelde helpers van de tools
      build/               build_city (+ city/: de bouwer in delen),
                           build_libraries, build_previews
      check/               coverage, corner_test, crash_test, drive_test, fps_test,
                           axle_test, follow_switch_test, lane_choice_test, traffic_test,
                           triangle_count
      shots/               shot_tiles, shot_iso, shot_scene, shot_vehicles
      voxgen/              Python-generator van de tiles (zie "Tiles (opnieuw) genereren")
    docs/                  Goxel-handleiding (GOXEL.md -> handleiding_goxel.html)


Snel starten
------------
1. Open de map in Godot 4.7 (`project.godot`). De eerste keer importeert Godot
   alle tiles en maakt de plugin de palet-previews (dat duurt even).
2. Open `scenes/stad.tscn` of `scenes/nieuwe_kaart.tscn` (leeg).
3. Selecteer een GridMap-node (Grond / Gebouwen / Details / Props); onderin
   verschijnt het tile-palet. Zoek op naam, klik een tile, en klik in de 3D-view.
4. F5 start de stad (`scenes/stad.tscn`, zie boven). De camera staat standaard in
   isometrische stand: een perspectiefcamera met een smalle kijkhoek (20°),
   45 graden gedraaid en ~35 graden naar beneden (`scripts/camera/iso_camera.gd`).
   Een echte perspectiefcamera, omdat Godot schaduwsplits en SSR alleen daarmee
   goed berekent; zoomen = de afstand veranderen. In de iso-stand: WASD of de
   pijltjestoetsen = over de kaart schuiven, muiswiel = in- en uitzoomen, Q/E = vloeiend
   uit- en inzoomen, rechtermuisknop ingedrukt = de kaart verslepen, Z/X = het beeld een
   kwartslag naar links/rechts draaien, middelste muisknop ingedrukt = vrij draaien, Shift =
   sneller (`iso_pan_speed`, `iso_zoom_step`, `iso_zoom_speed`, `iso_turn_speed`,
   `iso_turn_sensitivity`; 6 tot 600 m in beeld). Draaien gaat om het punt midden in beeld;
   de iso-helpers (`iso_camera.gd`: `direction`, `position`, `place`) nemen een draaiing mee. Zet `isometric`
   op de Camera-node uit voor een vrije perspectief-camera (rechtermuisknop =
   kijken, WASD = bewegen, Q/E = omlaag/omhoog, Shift = sneller, muiswiel = snelheid).
   `iso_size` bepaalt hoeveel meter van de kaart in beeld is.

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
    # 2b. palet-previews renderen (met venster, ~1,5 min voor alles; daarna hoeft de
    #     editor bij het openen geen "Creating mesh previews" meer te doen)
    tools/godot.sh --script tools/build/build_previews.gd [-- all]
    # 3. de stad opnieuw bouwen (overschrijft scenes/stad.tscn, behalve de keuzes per tile)
    tools/godot.sh --headless --script tools/build/build_city.gd

Previews worden bewaard in `.godot/vox_tiles_previews/` (per tile en importtijd); een
bibliotheek die opnieuw gebouwd wordt, krijgt ze daar direct uit terug.
`tools/godot.sh` start Godot met een tijdslimiet (`GODOT_TIMEOUT`, standaard 600 s)
en zonder invoer, zodat een run nooit blijft hangen; de tools in `tools/` stoppen
bovendien zelf na een script-fout (`Common.watchdog`).

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
  scripts die elk het vorige uitbreiden: `base` (toestand, scene, `G/B/D/Pr`) -> `kit`
  (herbruikbare helpers) -> `street_grid`. Een deel kan alleen functies uit zichzelf of een
  eerder deel aanroepen. Handige helpers om zelf kaarten te scripten: `G/B/D/Pr` (één
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
uit het zuid-zuidoosten met schaduwen (in de isometrische stand krijgen zowel
de zuid- als de oostgevels licht), een zacht blauwig vullicht zonder schaduw,
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
  (`block_size`), stoeptegels 4 x 4 voxels (`tile_size`); kiezels ~12 cm. Asfalt heeft geen scheurtjes maar het patroon van
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
  gebouwen, 4x1,5x4 voor grond). Tot het samenvoegen klaar is, staat er een laadscherm
  (export `loading_screen`); het resultaat wordt bewaard in `user://merged/`, zodat de
  volgende keer direct klaar is (zolang de kaart en de tiles niet veranderen).
  Je bewerkt gewoon de GridMaps; botsingen blijven daar ook. Tiles met een vlag
  blijven losse meshes (de vlag-shader rekent in lokale coördinaten).
- `Dagcyclus` (`scripts/effects/day_cycle.gd`): basis voor dag en nacht (`time_of_day`,
  `speed`). De zon komt schuin van opzij (oost tot zuidoost, gezien vanuit de
  isometrische camera), zodat de schaduwen in beeld vallen en de gevels licht
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
  een korrel van 60 en 20 cm (geen vlekken van ver), en dichtbij lange, dunne grassprieten. Grind
  krijgt per kiezel een lichte en een schaduwkant en vlekken van ~15 cm.
- Echte grassprieten (node `Grassprieten`, `scripts/effects/grass_blades.gd`, shader
  `materials/grass_blade.gdshader`) in drie detailniveaus die in elkaar overgroeien:
  fijne sprieten tot `show_from` (36 m in beeld, helemaal vol tot `full_from`, 26 m), daarna dikkere plukken (`medium_*`, tot
  55 m) en nog grovere, schaarse plukken (`far_*`, tot 220 m, die twee over het hele beeld;
  uit met `low_detail`). Ingezoomd groeien hoekige sprieten in voxelstijl uit het gras (drie vierkante blokjes van 3 x 3 cm
  op elkaar, getrapt in de buigrichting, elk een eigen tint, alleen in kwartslagen gedraaid) rond het punt waar de camera
  naar kijkt, met een MultiMesh per stuk van 8 x 8 m. Ze buigen met dezelfde wind en
  windvlagen als de grasshader, staan in plukken (dicht, dun, kaal) en groeien alleen
  op het grasdeel van een tile (`GrondKaart` houdt per grastile een masker bij), dus
  niet op paden, oevers onder water of waterlelies. Instelbaar: `density` (220 sprieten
  per m², vol en dicht), `blade_height`, `blade_width` (3 cm, dun), `show_from`/
  `full_from`. Kost op 2560 x 1440 ongeveer 20% framerate zolang ze in beeld zijn; een
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
(x + i, z - j) en draai alles samen. In `tools/build/city/situations.gd` doet
`curve(x, z, profiel, draaiing)` dit inclusief de rechte stukken.
