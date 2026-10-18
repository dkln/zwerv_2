===========
ZWERVR GAME
===========

Een tile-gebaseerde wereldbouwer in Godot 4.7 met voxel-tiles uit MagicaVoxel.
Je bouwt kaarten met vier GridMap-lagen (grond, gebouwen, details, props). Elke
tile is een los `.vox` bestand dat je in MagicaVoxel kunt openen en aanpassen.
Na opslaan importeert Godot hem automatisch opnieuw.

Er zijn ongeveer 2000 tiles. Ze staan allemaal in context in de voorbeeldkaart
`scenes/wereld.tscn`.


Snel starten
------------
1. Open de map in Godot 4.7 (`project.godot`). De eerste keer importeert Godot
   alle tiles en maakt de plugin de palet-previews (dat duurt even).
2. Open `scenes/wereld.tscn` (voorbeeldkaart) of `scenes/nieuwe_kaart.tscn` (leeg).
3. Selecteer een GridMap-node (Grond / Gebouwen / Details / Props); onderin
   verschijnt het tile-palet. Zoek op naam, klik een tile, en klik in de 3D-view.
4. Druk op F5/F6: een automatische rondleiding vliegt isometrisch langs alle
   situaties, met titel en uitleg in beeld (node `Rondleiding`; zet `actief`
   uit om zelf rond te kijken). Daarnaast: De camera staat standaard in
   isometrische stand (orthografisch, 45 graden gedraaid). Zet `isometrisch`
   op de Camera-node uit voor een vrije perspectief-camera (rechtermuisknop =
   kijken, WASD = bewegen, Q/E = omlaag/omhoog, Shift = sneller).
   `iso_grootte` bepaalt hoeveel meter van de kaart in beeld is.

GridMap-bediening in de editor (Godot 4):
- klik = plaatsen, rechtsklik = verwijderen
- A / S / D = tile draaien om de X / Y / Z-as (S draait om de verticale as)
- Q / E (of het menu "GridMap > Verdieping") = een laag omlaag/omhoog
- Ctrl+klik-slepen = selecteren; daarna dupliceren/verplaatsen/verwijderen


De voorbeeldkaart (`scenes/wereld.tscn`)
----------------------------------------
De kaart is 96 x 80 tiles stad, met daaronder een campus en de demowijken.
Gebruik hem als naslag: zoek een tile in het palet en kijk hoe hij in de kaart
is ingezet.

| Gebied (tile-coördinaten x, z) | Wat je er ziet |
|---|---|
| 0..35, 0..29 | Oude stad: gracht met grachtenpanden (trap/klok/hals/tuitgevels), boogbrug, bouwblok met kappen die om de hoek lopen, plein met terrassen, park met vijver, spoorviaduct, perron, overweg |
| 36..58, 0..11 | Kathedraal (torens, roosvenster, luchtbogen), school met speelplaats |
| 63..95, 0..11 | Klassiek museum met koepel, raadhuis met klokkentoren en vlaggen, modern museum |
| 36..58, 18..39 | Jaren-30 bovenhuizen (gesloten bouwblok, 4 lagen) met horeca en terrassen, middelhoge portiekflats, herenhuizen (1600 en 1900), dorpskerk, moderne kerk met klokkenstoel |
| 63..95, 18..39 | Hoogbouw: kantoren jaren 80/2000/modern, appartemententoren, galerijflat, parkeergarage, radiotoren, glazen overkapping, glazen hal, binnen- en buitenzwembad, pilaren, loopbrug |
| z 40..46 | Zuidweg: fietspaden, busstrook, middenberm-lantaarns, bushaltes |
| z 48..54 | Rivier met stalen boogbrug, tuibrug, ophaalbrug, moderne voetbrug, kadetrap, woonboten |
| 0..30, 55..71 | Jaren-60 wijk: eengezinswoningen (erkers, dakkapellen), maisonnettes met galerij, parkeerplaats met laadpalen, speeltuin, vijver met strand/beschoeiing/basalt |
| 31..58, 55..71 | Boerderij met schuren, moestuin, heide, bos, sloot met duiker, heuvels (gras/zand/grind), bedrijfspand met industrieel hekwerk, kasteeltoren met kantelen |
| 59..63, 55..79 | Tunnelbak voor auto en fiets die onder de snelweg door gaat |
| 63..72, 55..71 | Brede boulevard: 2 rijstroken, stoep met halte, 2 trambanen, stoep met halte, 2 rijstroken |
| 73..95, 55..71 | Viaduct over een weg met middenberm, luxe appartementen met penthouse en daktuin/dakzwembad, kantoor met grind-/bitumen-/groendak en koelinstallaties, rijtjes met groendak, busstation, sporthal |
| z 72..79 | Snelweg (vluchtstroken, middenberm, portalen met blauwe borden, lantaarns) met auto- en fietstunnel eronder |
| z 80..98 | Campus: universiteit, hogeschool, twee kantoortorens met kolonnade en een loopbrug ertussen; ernaast (x 62..95, z 86..97) een autovrije winkelstraat met alle winkel- en horecatypes, terrassen, bomen, fontein en paaltjes bij de ingangen |
| vanaf z 100 | Demowijken (ook: kruisingen met verkeerslichten in alle standen en een bedrijventerrein met loodsen, magazijn, fabriek met rokende schoorsteen): een buurt per gebouwstijl (bouwblok met alle gevels, winkels en hoekpanden, hofje met kappen om de hoek, zadeldak-L en -T, rijtje smalle panden met elk een andere gevel/top, torens, een "detailpand" met aangebrachte ramen/deuren/luifels/zonwering/teksten/dakonderdelen), een dakenwijk met alle dakpansoorten, hallen en parkeergarage, een verkeerstuin met alle markeringen in doorlopende straten, kruispunten met eilanden/rotonde/stoephoeken, fiets-, tram- en spoorlussen, een dijk met alle hellingen en heuvels, een tunnelpark, een kanaal met alle bruggen en een natuur- en recreatiepark |

Elke tile staat ergens in de kaart in een realistische situatie; de wijken
worden automatisch opgebouwd uit de bibliotheken, dus nieuwe tiles komen er bij
het opnieuw bouwen vanzelf bij (`_demowijken()` in `tools/bouw_voorbeeldstad.gd`).

Controleren of echt alle tiles in de kaart staan:

    /Applications/Godot.app/Contents/MacOS/Godot --headless --script tools/dekking.gd


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
- Hellingen (`helling/helling_*`) stijgen 1 laag over 1 tile; flauwe hellingen
  (`helling/flauw_*_a` en `_b`) stijgen 0,5 m per tile (a eerst, dan b).
  Zet `terrein/grond_blok` eronder als je verder ophoogt.
- Bruggen: brugdek op de gewenste laag, `brug_pijler` eronder gestapeld,
  `brug_pijler_kop` direct onder het dek en `brug_pijler_gras/stoep/water` op
  laag 0 (grond + pijler in één tile). Stalen boogbrug: `staalboog_1..5` (5 tiles
  overspanning), tuibrug: `tuibrug_0` (pyloon) + `tuibrug_1..3`.
- Grachten en rivieren: water op laag -2, `kademuur` op laag -2 en -1 en
  `stoep_kade` op laag 0. De bakstenen boogbrug en de kadetrap zet je op laag -2.
- Tunnels (6 lagen hoog): tunnel-tiles op laag -6; het dak komt dan precies op
  straatniveau, zodat je er een weg of snelweg bovenop kunt leggen. Toerit:
  `tunnel_toerit_*_d1` t/m `_d6` op laag -1 t/m -6; daarna `tunnelbak_*_d6` (open
  bak) en `tunnel_*_portaal` aan het begin van de overkapping. Varianten
  `_wand` / `_wand_rechts` hebben een keerwand links/rechts; fiets-varianten
  bestaan ook.
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


Kleur en tint aanpassen (zonder de .vox te wijzigen)
----------------------------------------------------
In elke kaart zit een node `TintKaart` (script `scripts/tint_kaart.gd`):
- `variatie`: geeft elke 4x4 m cel automatisch een net iets andere kleur.
- Voeg een kind-node toe met script `scripts/tint_vlak.gd` (TintVlak), schuif
  hem over een gebouw of stuk grond en kies `kleur`, `helderheid`, `sterkte`
  en `grootte` (in cellen). De tint werkt live in de editor.
  Wit = geen verandering; helderheid > 1 is lichter, < 1 donkerder.
Dit werkt via globale shader-parameters (Project > Project Settings >
Shader Globals: `zwervr_tint_kaart`, `zwervr_tint_gebied`, `zwervr_variatie`).


Rook, water, vlaggen en voxelstructuur
--------------------------------------
- Rook: de node `Rook` (script `scripts/rook.gd`) zet automatisch rookpluimen
  op alle fabrieksschoorstenen (`overig/fabrieksschoorsteen_top`) en op de
  kleine schoorsteen-details. Werkt live in de editor; vink "opnieuw zoeken"
  aan nadat je schoorstenen hebt toegevoegd. `wind` bepaalt de richting.
- Voxelstructuur: `materials/voxel.gdshader` tekent (optioneel) lichte randen en kleine
  helderheidsverschillen per voxel (`voxel_ruis`; randjes via `voxel_rand`, standaard uit), zodat grote
  vlakken minder vlak ogen.
- Water golft met golven uit vier richtingen (niet rechtlijnig) en heeft lichte,
  bewegende vlekken en glinsteringen (`materials/voxel_water.tres`:
  `golf_hoogte`, `golf_snelheid`, `golf_lengte`, `vlekken`, `glinstering`). De
  importer maakt het wateroppervlak daarvoor per voxel fijnmazig.
- Spiegeling in water, zonder raytracing: de shader volgt de gespiegelde
  kijkstraal in 12 stappen over het scherm (diepte- en schermbuffer) en toont
  zwak wat hij raakt (bruggen, bomen, gevels). Raakt hij niets, dan spiegelt de
  lucht (kleuren uit de dagcyclus, shader globals `zwervr_lucht_*`). Instelbaar:
  `spiegeling`, `lucht_spiegeling`, `stap`, `stappen`, `dikte`, `rimpeling`.
  DetailNiveau zet de spiegeling uit vanaf `grof_vanaf`. De ingebouwde SSR van
  Godot werkt niet met de orthografische camera en staat uit.
- Glas heeft een goedkope, nagebootste spiegeling (lucht, horizon, straat en
  lichte strepen; `spiegeling`, `opacity`).
- Lampen, verkeerslichten en verlichte ramen (emit-materiaal, energie 6) geven
  een zachte gloed via de glow van de Environment (drempel 1,6).
- Vlaggen wapperen via `materials/voxel_vlag.tres` (`snelheid`, `sterkte`,
  `golflengte`). Hoe verder van de mast, hoe meer beweging.
- In MagicaVoxel: paletkleuren 225-232 worden water, 233-248 worden
  wapperend vlagdoek. De generator zet die kleuren automatisch op die plekken.


Tiles aanpassen in MagicaVoxel
------------------------------
Alle tiles staan in `assets/tiles/<categorie>/<groep>/<naam>.vox`.
1. Open een `.vox` in MagicaVoxel, pas aan, sla op (Ctrl+S).
2. Ga terug naar Godot: de tile wordt automatisch opnieuw geïmporteerd en de
   bibliotheek (palet, preview en collision) wordt bijgewerkt.

Belangrijk bij het bewerken:
- Houd de modelgrootte (Size) gelijk; het draaipunt is het midden-onder van
  het model. Grond-tiles 32x32, gebouwblokken 48x48 (blok in het midden, 8
  voxels rand voor balkons en luifels).
- De voorkant is de kant met de laagste Y in MagicaVoxel.
- Materialen komen uit MagicaVoxel: metaal (`_metal`), glas (`_glass`) en
  licht (`_emit`) worden in Godot metaal, doorzichtig glas en lichtgevend.
- Elk bestand heeft een eigen palet (max 224 gewone kleuren + water + vlag).
- Eén model per bestand (het eerste model wordt gebruikt).

Nieuwe tile toevoegen: zet een nieuw `.vox` bestand in de juiste map onder
`assets/tiles/`. Hij verschijnt vanzelf in het palet van de juiste GridMap.
Bestaande item-ID's blijven gelijk, dus je kaarten breken niet. Daarom moet je
`assets/libraries/*.res` ook in git houden (zie `.gitignore`).


Tiles (opnieuw) genereren
-------------------------
De tiles worden gemaakt door een Python-generator (alleen standaard Python 3):

    python3 tools/voxgen/generate.py              # alleen ontbrekende tiles maken
    python3 tools/voxgen/generate.py --list       # lijst van alle tiles
    python3 tools/voxgen/generate.py --only weg   # alleen tiles met 'weg' in het pad
    python3 tools/voxgen/generate.py --force --only klassiek_rood   # overschrijven

LET OP: `--force` overschrijft bestaande bestanden, dus ook je eigen
aanpassingen in MagicaVoxel. Zonder `--force` blijven bestaande tiles staan.
Wil je één tile opnieuw laten genereren: verwijder het `.vox` bestand en draai
de generator.

Generator-bestanden (`tools/voxgen/`):
- `palette.py`   kleurenpalet + materiaaltypes (metal/glass/emit/water/flag);
  `VARIATIE` (standaard 0,65) dempt de kleurverschillen binnen groepen als
  asfalt1..4, gras1..5 en baksteen1..5 (bestrating zoals tegels en klinkers niet)
- `vox.py`       voxelmodel, tekenfuncties, .vox schrijver (palet per bestand)
- `common.py`    maten, registry, pixelfont en pictogrammen
- `ground.py`, `ground2.py`, `ground3.py`   grond: wegen, stoepen, pleinen,
  natuur, water, spoor, tram, tunnels, zwembaden, waterkant, bruggen, hellingen
- `buildings.py`, `buildings2.py`, `buildings3.py`   gebouwstijlen, gevels,
  daken, dakpansoorten, kerken, musea, hallen, parkeergarage, radiotoren
- `details.py`, `details2.py`   gevel- en dakonderdelen, zonwering, teksten, vlaggen
- `props.py`, `props2.py`   straatmeubilair, borden (RVV), bomen, planten,
  hekken, muurtjes, speeltuin, terras, zwembad, containers, steigers
- `extras4.py`, `extras5.py`, `extras6.py`   latere uitbreidingen (bedrijfspand,
  heuvels, loopbruggen, winkels, tunnelbakken, boulevards, luxe appartementen,
  groendaken, standbeelden, universiteit, hogeschool, kolonnades)
- `generate.py`  schrijft alles naar `assets/tiles/`

Na het genereren (vanuit de projectmap):

    # 1. alle tiles importeren
    /Applications/Godot.app/Contents/MacOS/Godot --headless --import
    # 2. bibliotheken bijwerken (zonder previews; de editor maakt die bij openen)
    /Applications/Godot.app/Contents/MacOS/Godot --headless --script tools/build_libraries.gd [-- force]
    # 3. voorbeeldkaart opnieuw bouwen (overschrijft scenes/wereld.tscn!)
    /Applications/Godot.app/Contents/MacOS/Godot --headless --script tools/bouw_voorbeeldstad.gd

In de editor staat ook: Project > Tools > "Vox Tiles: bibliotheken volledig
herbouwen" (maakt collision en alle previews opnieuw; handig als een preview
niet meer klopt na een `--force`).


Hoe het werkt (techniek)
------------------------
- `addons/vox_tiles/vox_import_plugin.gd`: importer voor `.vox`. Leest het
  model (`vox_parser.gd`) en maakt een mesh (`vox_mesher.gd`) met greedy
  meshing, vertex-kleuren en ingebakken ambient occlusion. Per materiaaltype
  een eigen surface en shader (`materials/`: opaque, metal, glass, emit,
  water, vlag).
- `addons/vox_tiles/library_builder.gd`: bouwt per map onder `assets/tiles/`
  een MeshLibrary in `assets/libraries/` (grond, gebouwen, details, props),
  met previews en collision. Item-ID's blijven stabiel op naam.
- `addons/vox_tiles/plugin.gd`: houdt de bibliotheken automatisch bij als er
  tiles bijkomen, verdwijnen of opnieuw geïmporteerd worden.
- `scripts/vrije_camera.gd`: vliegcamera; `scripts/tint_kaart.gd` en
  `scripts/tint_vlak.gd`: tint-systeem.
- `tools/bouw_voorbeeldstad.gd`: bouwt de voorbeeldkaart via code. Handige
  helpers om zelf kaarten te scripten: `G/B/D/Pr` (één tile per laag),
  `blok()` (rechthoekig gebouw met automatisch de juiste hoek-, gevel- en
  dakstukken), `ring()` (gesloten bouwblok met kappen om de hoek), `toren()`,
  `profiel_x/z()` (straatprofiel), `vlak()`.
- `tools/dekking.gd`: telt welke tiles in de voorbeeldkaart in context staan.
- `tools/screenshots.gd`: maakt isometrische screenshots van alle gebieden en
  buurten met titel en uitleg in beeld, naar `docs/screenshots/` (met
  `index.json`).
- `tools/shot.gd` / `tools/shot_scene.gd` / `tools/shot_iso.gd`: maken
  screenshots van tiles of scenes, ook isometrisch (voor controle).

Belichting (in `tools/bouw_voorbeeldstad.gd`, functie `_maak_scene`): een zon
uit het zuid-zuidoosten met schaduwen (in de isometrische stand krijgen zowel
de zuid- als de oostgevels licht), een zacht blauwig vullicht zonder schaduw,
lucht-ambient, SSAO, glow en een lichte kleur/contrast-correctie. Pas
`Zon`, `Vullicht` en `Omgeving` in de scene aan voor een andere sfeer.


Rondleiding, prestaties en uiterlijk
------------------------------------
- `Rondleiding` (`scripts/rondleiding.gd`): stops komen uit
  `scripts/rondleiding_data.gd` (vaste gebieden + alle demowijken). Instelbaar:
  `reistijd`, `kijktijd`, `inzoomen`.
- `DetailNiveau` (`scripts/detail_niveau.gd`): schakelt bij het uitzoomen naar
  grove tiles (`grof_vanaf`, standaard 100 m in beeld) en heel grove tiles
  (`heel_grof_vanaf`, 130 m), verbergt Details (vanaf 120 m) en Props (vanaf
  300 m) en past de schaduwafstand aan het zoomniveau aan. De grove versies
  maakt de importer zelf: gelijkende kleuren samengevoegd (`lod`) en blokjes
  van 2x2x2 voxels (`lod2`). De grove bibliotheken (`*_lod.res`, `*_lod2.res`)
  worden automatisch gemaakt en staan in `.gitignore`.
- Ook het volle detailniveau voegt bijna gelijke kleuren samen (import-optie
  `kleur_samenvoegen`, standaard 14) voor minder driehoeken; de fijne korrel
  komt uit de shader (`voxel_ruis`). Gras en boomkruinen hebben hun detail in de
  kleur van de voxels, niet in uitstekende voxels.
- Schaduwen: vlakke tiles (lager dan 0,7 m) en kleine details werpen geen
  schaduw; de zon gebruikt 4 schaduwsplits (4096 px). De orthogonale modus gaf bij de verre isometrische camera vrijwel geen schaduw.
- Rendering (`project.godot`): MSAA 4x + FXAA, debanding, FSR-schaling 0,77,
  depth prepass uit; GridMaps gebruiken octant-grootte 4 (snelst gemeten).
- Samenvoegen (`scripts/bakker.gd`, aangestuurd door `DetailNiveau`, export
  `bakken`): bij het starten worden de lagen Gebouwen en Grond samengevoegd tot
  grote meshes (chunks van 8x8 cellen, per LOD-niveau). Zijden die tegen een
  dichte buurcel liggen en alle onderkanten vallen daarbij weg. De importer
  groepeert de driehoeken daarvoor per celzijde (import-optie `blok`: 4x3x4 voor
  gebouwen, 4x1,5x4 voor grond). Tot het samenvoegen klaar is, zie je de gewone
  GridMaps; het resultaat wordt bewaard in `user://samengevoegd/`, zodat de
  volgende start direct klaar is (zolang de kaart en de tiles niet veranderen).
  Je bewerkt gewoon de GridMaps; botsingen blijven daar ook. Tiles met een vlag
  blijven losse meshes (de vlag-shader rekent in lokale coördinaten).
- `Dagcyclus` (`scripts/dagcyclus.gd`): basis voor dag en nacht (`tijd`,
  `snelheid`). De zon komt schuin van opzij (oost tot zuidoost, gezien vanuit de
  isometrische camera), zodat de schaduwen in beeld vallen en de gevels licht
  houden, en blijft tussen `min_hoogte` (36°) en `max_hoogte` (44°) hoog: geen
  lange schaduwen. Alle licht is realtime.
- Bomen en planten bewegen in de wind (`materials/voxel_wind.tres`:
  `wind_sterkte`, `wind_snelheid`, `wind_hoogte`); de importer kiest dit
  materiaal automatisch voor `props/bomen` en `props/planten` (import-optie `wind`).
- Scherptediepte (tilt-shift): Camera > Attributes (focus op 250–330 m; de
  camera staat op 300 m van het focuspunt).
- Lettertype: Rubik (`assets/fonts/Rubik.ttf`, OFL-licentie), ingesteld als
  projectfont.
- Meten: `Godot --script tools/fps_test.gd -- 20 rondleiding` of
  `-- 10 140` (vaste zoom 140 m). Sluit de Godot-editor tijdens het meten, anders
  delen ze de GPU. `tools/driehoeken.gd` toont het aantal driehoeken per tile en
  LOD-niveau.

Afgeronde bochten
-----------------
In `grond/bocht/` staan bochten voor hele straatprofielen (straat,
klinkerstraat, weg, hoofdweg, tramweg, laan, fietspad). Elke bocht bestaat uit
(n x n) tiles: `<profiel>_<i>_<j>`, met n = 1 + aantal delen van het profiel.
De weg komt van het zuiden en buigt af naar het westen; leg cel (i, j) op
(x + i, z - j) en draai alles samen. In `tools/bouw_voorbeeldstad.gd` doet
`bocht(x, z, profiel, draaiing)` dit inclusief de rechte stukken.
