===========
ZWERVR GAME
===========

Een tile-gebaseerde wereldbouwer in Godot 4.7 met voxel-tiles uit MagicaVoxel.
Je bouwt kaarten met vier GridMap-lagen (grond, gebouwen, details, props); elke
tile is een los `.vox` bestand dat je in MagicaVoxel kunt openen en aanpassen.
Na opslaan importeert Godot hem automatisch opnieuw.

Snel starten
------------
1. Open de map in Godot 4.7 (`project.godot`).
2. Open `scenes/wereld.tscn` (de voorbeeldstad) of `scenes/nieuwe_kaart.tscn` (leeg).
3. Selecteer een GridMap-node (Grond / Gebouwen / Details / Props); onderin
   verschijnt het tile-palet. Zoek op naam, klik een tile, en klik in de 3D-view.
4. Druk op F5/F6 om rond te vliegen: rechtermuisknop = kijken, WASD = bewegen,
   Q/E = omlaag/omhoog, Shift = sneller, muiswiel = snelheid.

GridMap-bediening in de editor (Godot 4):
- klik = plaatsen, rechtsklik = verwijderen
- A / S / D = tile draaien om de X / Y / Z-as (S draait om de verticale as)
- Q / E (of het menu "GridMap > Verdieping") = een laag omlaag/omhoog
- Ctrl+klik-slepen = selecteren; daarna dupliceren/verplaatsen/verwijderen

De vier lagen
-------------
| GridMap   | Celgrootte (m)  | Hoogte-offset | Gebruik                                        |
|-----------|-----------------|---------------|------------------------------------------------|
| Grond     | 4 x 1 x 4       | 0             | wegen, stoepen, water, spoor, bruggen, hellingen |
| Gebouwen  | 4 x 3 x 4       | 0.375         | gebouwblokken, 1 verdieping per laag            |
| Details   | 0.5 x 0.5 x 0.5 | 0.375         | luifels, ramen, balkons, schoorstenen           |
| Props     | 0.5 x 0.5 x 0.5 | 0.25          | bomen, lantaarns, borden, banken, boten         |

Maten: 1 voxel = 12,5 cm. Een grond-tile is 32x32 voxels (4x4 m), een
gebouwblok 32x32x24 voxels (4x4x3 m).

Hoogtes en lagen (grond):
- Een grond-laag is 1 m hoog. Wegdek ligt op 0,25 m, stoep en gras op 0,375 m.
- Hellingen (`helling/...`) stijgen precies 1 laag over 1 tile. Zet ze op
  oplopende lagen achter elkaar om naar een brug of viaduct te gaan.
- Bruggen: brugdek (`brug/brug_dek_*`) op de gewenste laag, pijlers
  (`brug_pijler`) eronder gestapeld, `brug_pijler_kop` direct onder het dek en
  `brug_pijler_gras/stoep/water` op laag 0 (grond + pijler in één tile).
  `brug_ligger` is een optionele balk onder het dek.
- Grachten: water (`water/water_gracht`) op laag -2, `kademuur` blokken op
  laag -2 en -1 langs de rand, en `stoep_kade` op laag 0. De bakstenen
  boogbrug (`brug_boog_gracht_*`) zet je op laag -2 (waterniveau); het wegdek
  komt dan precies op straatniveau.
- Terrein ophogen: `terrein/grond_blok` (1 m blok) en daar een gewone tile op.
- Grote bochten (`*_bocht_groot_3x3`) beslaan 3x3 tiles: plaats ze in de
  middelste cel en laat de 8 cellen eromheen leeg.

Richting van tiles:
- De "voorkant" van elke tile wijst in Godot naar +Z (zuid, naar de camera
  toe). Stoepranden, gevels, oevers en kade-randen zitten aan die kant.
- Rijstroken: het verkeer rijdt naar -Z. De naam `rijstrook_<links>_<rechts>`
  zegt welke markering aan de linker- en rechterkant van de rijstrook ligt
  (geen, onderbroken, streep, dubbel, blok, kant = kantstreep).
- Hoekstukken (`*_hoek`, `hoek_buiten`) hebben iets aan de voor- én
  rechterkant.

Gebouwen bouwen
---------------
Stijlen: `klassiek_rood`, `klassiek_donker`, `klassiek_geel`, `modern_wit`,
`modern_donker`, `modern_hout`, `kantoor_glas`, `kantoor_beton`.

Onderdelen per stijl:
- `bg_*` begane grond (deur, raam, winkel, winkel met luifel, poort, garage, entree)
- `verd_*` verdiepingen (ramen, luiken, balkon, erker, vliesgevel, ...)
- `*_hoek` hoekblok met gevel aan voor- én rechterkant
- `blok_dicht` blok zonder ramen (binnenhoeken, zijkanten)
- Platte daken: `dak_plat_midden / rand / hoek / tegenover / eind / los`
  (dakrand aan 0, 1, 2 of meer kanten), plus varianten met zonnepanelen,
  lichtkoepel, dakterras en installaties.
- Schuine daken (klassiek):
  - `dak_schuin`: halve kap met goot aan de voorkant en nok achter. Twee rijen
    met de ruggen tegen elkaar = zadeldak over een blok van 2 tiles diep.
  - `dak_schuin_hoek_buiten`: hoekkeper, voor de buitenhoek van een bouwblok
    (of een schildeind).
  - `dak_schuin_hoek_binnen`: kilkeper, voor de binnenhoek van een bouwblok.
  - Varianten: dakkapel, schoorsteen, dakraam, zonnepanelen, dakterras
    (kap deels opengebroken) en `half_plat` (helft schuin, helft plat).
  - `dak_zadel*`: complete kap over een blok van 1 tile diep, met `schild`
    (eind), `hoek` (L-hoek) en `t` (T-splitsing).
- Grachtengevels: `gevel_trap`, `gevel_klok`, `gevel_hals`, `gevel_tuit` als
  bovenste laag van een grachtenpand (met zadeldak naar achteren).

Zo loopt een kap om de hoek van een bouwblok (ring van 2 tiles diep):
buitenhoek = `dak_schuin_hoek_buiten`, de tegels ernaast = `dak_schuin` (goot
naar de straat), binnenhoek = `dak_schuin_hoek_binnen`, en de rij aan de
binnenhof = `dak_schuin` met de goot naar de binnenhof. Bekijk het bouwblok in
`scenes/wereld.tscn` als voorbeeld.

Tiles aanpassen in MagicaVoxel
------------------------------
Alle tiles staan in `assets/tiles/<categorie>/<groep>/<naam>.vox`.
1. Open een `.vox` in MagicaVoxel, pas aan, sla op (Ctrl+S).
2. Ga terug naar Godot: de tile wordt automatisch opnieuw geïmporteerd en de
   bibliotheek (palet, previews en collision) wordt bijgewerkt.

Belangrijk bij het bewerken:
- Houd de modelgrootte (Size) gelijk; het draaipunt is het midden-onder van
  het model. Grond-tiles 32x32, gebouwblokken 48x48 (blok in het midden, 8
  voxels rand voor balkons en luifels).
- De voorkant is de kant met de laagste Y in MagicaVoxel.
- Materialen komen uit MagicaVoxel: metaal (`_metal`), glas (`_glass`) en
  licht (`_emit`) worden in Godot automatisch metaal, doorzichtig glas en
  lichtgevend. Paletkleuren 225-232 zijn gereserveerd voor water.
- Eén model per bestand (het eerste model wordt gebruikt).

Nieuwe tile toevoegen: zet een nieuw `.vox` bestand in de juiste map onder
`assets/tiles/`. Hij verschijnt vanzelf in het palet van de juiste GridMap.
Bestaande item-ID's blijven gelijk, dus je kaarten breken niet.

Tiles (opnieuw) genereren
-------------------------
De tiles worden gemaakt door een Python-generator (alleen standaard Python 3):

    python3 tools/voxgen/generate.py              # alleen ontbrekende tiles maken
    python3 tools/voxgen/generate.py --list       # lijst van alle tiles
    python3 tools/voxgen/generate.py --only weg   # alleen tiles met 'weg' in het pad
    python3 tools/voxgen/generate.py --force --only klassiek_rood   # overschrijven

LET OP: `--force` overschrijft bestaande bestanden, dus ook je eigen
aanpassingen in MagicaVoxel. Zonder `--force` blijven bestaande tiles staan.
Wil je een tile helemaal opnieuw laten genereren: verwijder het `.vox` bestand
en draai de generator.

Generator-bestanden (`tools/voxgen/`):
- `palette.py`   gedeeld kleurenpalet + materiaaltypes
- `vox.py`       voxelmodel, tekenfuncties, .vox schrijver
- `ground.py`    grond-tiles (wegen, stoep, plein, natuur, water, spoor, tram, bruggen, hellingen)
- `buildings.py` gebouwstijlen, gevels en daken
- `details.py`   gevel-onderdelen
- `props.py`     straatmeubilair, borden, bomen, planten, hekken, spoor, water

Godot-tools (handig na het genereren, vanuit de projectmap):

    # alle tiles importeren
    /Applications/Godot.app/Contents/MacOS/Godot --headless --import
    # bibliotheken bouwen (zonder previews; de editor maakt die bij openen)
    /Applications/Godot.app/Contents/MacOS/Godot --headless --script tools/build_libraries.gd
    # voorbeeldstad opnieuw bouwen (overschrijft scenes/wereld.tscn!)
    /Applications/Godot.app/Contents/MacOS/Godot --headless --script tools/bouw_voorbeeldstad.gd

In de editor staat ook: Project > Tools > "Vox Tiles: bibliotheken volledig
herbouwen" (maakt collision en previews opnieuw).

Hoe het werkt (techniek)
------------------------
- `addons/vox_tiles/vox_import_plugin.gd`: importer voor `.vox`. Leest het
  model (`vox_parser.gd`) en maakt een mesh (`vox_mesher.gd`) met greedy
  meshing, vertex-kleuren en ingebakken ambient occlusion. Per materiaaltype
  een aparte surface met een eigen shader (`materials/`).
- `addons/vox_tiles/library_builder.gd`: bouwt per map onder `assets/tiles/`
  een MeshLibrary in `assets/libraries/` (grond, gebouwen, details, props),
  met previews en collision (trimesh voor grond/gebouwen, doos voor props).
- `addons/vox_tiles/plugin.gd`: houdt de bibliotheken automatisch bij als er
  tiles bijkomen, verdwijnen of opnieuw geïmporteerd worden.
- `scripts/vrije_camera.gd`: vliegcamera voor het bekijken van je kaart.
- `tools/bouw_voorbeeldstad.gd`: bouwt de voorbeeldstad via code; handig om te
  zien hoe je tiles combineert (helpers G/B/Pr/D voor de vier lagen).
- `tools/shot.gd` / `tools/shot_scene.gd`: maken screenshots van tiles of
  scenes (voor controle).

Materialen bijstellen: `addons/vox_tiles/materials/*.tres` (ruwheid, metaal,
glas-doorzichtigheid, lichtsterkte, golven op het water).
