# Tiles maken en aanpassen in Goxel

Elke tile in Zwervr is een los Goxel-bestand (`.gox`). [Goxel](https://goxel.xyz) is
een open-source voxeleditor (GPL) voor macOS, Windows en Linux. Godot importeert de
bestanden zelf en zet ze in de GridMap-bibliotheken. Dit document legt uit hoe je een
tile maakt, welke kleuren je gebruikt, hoe materialen werken en wat er in de
metadata (`.tile.json`) staat.

## 1. Waar staan de tiles?

```
assets/tiles/<laag>/<groep>/<naam>.gox
```

De eerste map bepaalt in welke laag (GridMap) de tile terechtkomt:

| map        | laag in Godot | cel               | modelmaat (voxels)                                                                  |
| ---------- | ------------- | ----------------- | ----------------------------------------------------------------------------------- |
| `grond`    | Grond         | 4 x 1 x 4 m       | 32 x 32, 8 hoog per meter (mag hoger)                                               |
| `gebouwen` | Gebouwen      | 4 x 3 x 4 m       | 48 x 48 x 24: blok van 32 x 32 in het midden, 8 voxels rand voor balkons en luifels |
| `details`  | Details       | 0,5 x 0,5 x 0,5 m | vrij                                                                                |
| `props`    | Props         | 0,5 x 0,5 x 0,5 m | vrij                                                                                |

De groep (de tweede map) kies je zelf. De naam van de tile in het palet is
`<groep>/<naam>`, bijvoorbeeld `weg/rijstrook_kant`.

Maten: **1 voxel = 12,5 cm.** Een persoon van 1,80 m is 14 à 15 voxels hoog. Een
verdieping is 3 m (24 voxels).

## 2. Goxel klaarzetten

1. Installeer Goxel (goxel.xyz, of de App Store op de Mac).
2. Kopieer het palet `tools/voxgen/paletten/zwervr.gpl` naar de palettenmap van Goxel.
   Goxel toont die map onder **Settings** ("Palettes: …"). Op de Mac is het
   `~/Library/Containers/com.noctuasoftware.goxel/Data/Library/Application Support/Goxel/palettes`
   (maak de map `palettes` aan als hij er niet is).
3. Start Goxel opnieuw en kies in het paneel **Palette** het palet **Zwervr**. Elke
   kleur heeft daar zijn naam, met het materiaal tussen haakjes als het geen gewone,
   matte kleur is (bijvoorbeeld `glas1 (glas)`).

## 3. Een nieuwe tile maken

1. Open een bestaande tile die erop lijkt, of het kleurenoverzicht
   `tools/voxgen/paletten/palet.gox` (één voxel per kleur, één rij per groep).
2. Zet in het paneel **Image** het kader van het model goed (zie hieronder) en teken
   je model met de kleuren uit het palet Zwervr.
3. Sla op als nieuw bestand op de goede plek (**File › Save as**), bijvoorbeeld
   `assets/tiles/props/straat/mijn_bankje.gox`.
4. Ga terug naar Godot. De tile wordt geïmporteerd, krijgt een vaste ID en staat
   binnen een paar seconden in het palet van de juiste GridMap.

Een bestaande tile aanpassen gaat net zo: openen, aanpassen, opslaan (Ctrl+S). Godot
ziet de wijziging en importeert de tile opnieuw.

### Het kader (Image-paneel)

Het kader van de afbeelding is de **modelmaat** van de tile, zoals de Size in
MagicaVoxel. De importer telt de voxelposities vanaf de hoek van het kader, dus het
kader bepaalt waar de tile staat. In het paneel **Image** zie je het als **Origin**
(de hoek) en **Size**. De tiles die de generator maakt, hebben:

| tile                   | Origin (x, y, z) | Size (w, h, d)                 |
| ---------------------- | ---------------- | ------------------------------ |
| grond-tile             | -16, -16, 0      | 32, 32, hoogte                 |
| gebouwblok             | -24, -24, 0      | 48, 48, 24                     |
| detail / prop van 12 x 8 x 20 | -6, -4, 0 | 12, 8, 20                      |

Het midden van het model in x/y ligt dus op de oorsprong van Goxel en de onderkant op
z = 0. Voxels buiten het kader worden overgeslagen (de importer waarschuwt). Heeft een
bestand geen kader, dan neemt de importer de buitenkant van de voxels; dat kan de
tile laten verschuiven, dus zet het kader altijd. **Fit to Content** in het
Image-paneel maakt het kader zo groot als het model; controleer daarna Origin en Size.

### Regels voor het model

- **Draaipunt:** het midden van het kader in x/y, de onderkant in z. Houd het kader
  van een bestaande tile gelijk, anders verschuift hij.
- **Voorkant:** de kant met de laagste Y in Goxel. In Godot wijst die naar +Z (naar de
  camera). Stoepranden, gevels en oevers horen aan die kant.
- **Lagen:** alle zichtbare lagen samen vormen de tile, bovenste laag over de
  onderste (zoals Goxel ze toont). Verborgen lagen tellen niet mee. Kloonlagen
  (Clone) werken; vormlagen (Add: Shape) niet: voeg die eerst samen met een gewone
  laag (**Merge Down** of **Merge Visible**).
- **Doorzichtigheid:** een voxel met een alpha onder 50% telt als leeg. Glas en water
  komen uit het materiaal, niet uit de alpha (zie hoofdstuk 5).
- **Ambient occlusion** (donkere hoekjes) rekent de importer zelf uit. Teken die niet in.
- **Gelijkende kleuren** worden bij het importeren samengevoegd tot grotere vlakken
  (minder driehoeken). De shader legt de variatie per voxel er weer overheen, dus
  kleine kleurverschillen blijven zichtbaar.
- **Gebouwen** zijn van binnen leeg, zodat je er later in kunt lopen. Een dicht blok
  krijgt een botsdoos van 4 x 3 x 4 m; holle tiles een exacte vorm.
- **Maximaal 255 kleuren per tile** en **256 voxels per zijde**. Gebruik je meer
  kleuren, dan vervangt de importer de rest door de dichtstbijzijnde (met een
  waarschuwing).

## 4. Het palet

Een `.gox` slaat per voxel alleen de **kleur** op. Er staan geen namen en geen
paletnummers in het bestand. Het palet van Zwervr staat in de generator
(`tools/voxgen/palette.py`); daaruit komen:

| bestand                              | inhoud                                                       |
| ------------------------------------ | ------------------------------------------------------------ |
| `tools/voxgen/paletten/zwervr.gpl`   | het palet voor Goxel (naam en materiaal per kleur)           |
| `tools/voxgen/paletten/palet.gox`    | kleurenoverzicht: één voxel per kleur, één rij per groep     |
| `tools/voxgen/paletten/palet.md`     | overzicht: kleurcode, naam en materiaal van elke kleur       |
| `assets/tiles/materialen.json`       | de kleurentabel: welk materiaal elke kleur in Godot krijgt   |

De kleurnamen (`asfalt1`, `baksteen3`, `amsterdamgroen`, …) bestaan alleen in de
generator en in het palet. Ze zijn niet nodig om een tile te laten werken.

**Let op bij eigen kleuren:** het materiaal hoort bij de **exacte** kleur. Een kleur die
niet in het palet van Zwervr staat (ook niet als hij er één stapje naast zit), wordt
een gewone, matte kleur. Wil je er een ander materiaal op, gebruik dan een
materiaallaag (hoofdstuk 5) of zet het in de metadata (hoofdstuk 6).

## 5. Materialen

Een materiaal bepaalt hoe een kleur eruitziet in Godot: mat, glanzend, doorzichtig,
lichtgevend, enzovoort.

| materiaal | effect in Godot                                                                                |
| --------- | ---------------------------------------------------------------------------------------------- |
| `opaque`  | gewone, matte kleur                                                                            |
| `metal`   | metaal: lantaarnkap, vangrail, kabels                                                          |
| `panel`   | spiegelend metaal: zonnepanelen                                                                |
| `glass`   | ramen                                                                                          |
| `water`   | grachten en vijvers: golvend en spiegelend                                                     |
| `emit`    | lampen en verlichte ramen, vooral 's nachts                                                    |
| `flag`    | wapperend doek                                                                                 |
| `asphalt` | steenkorrel, slijtplekken, haarscheurtjes, putjes en een lichte glans op liggende vlakken      |
| `stone`   | natuursteen, beton, klinkers: licht reliëf per voxel en wat haarscheurtjes                     |
| `paving`  | stoeptegels: tegels van 3 x 3 voxels met voegen en een afgeronde rand                          |
| `cobble`  | keien: bolle stenen van 2 x 2 voxels                                                           |
| `brick`   | metselwerk: voegen precies op het verband van 3 x 1 voxels (elke laag 2 verspringend), puntjes |
| `plaster` | stucwerk: haarscheurtjes en kleine putjes                                                      |
| `gravel`  | grind: kleine ronde steentjes                                                                  |
| `painted` | gelakt metaal: halfglanzend met een lichte metaalglans (lantaarnpalen, verkeersborden)         |

De importer kiest het materiaal van een voxel zo (de eerste regel die past, wint):

1. **De metadata** van de tile (`"materials"` in de `.tile.json`, hoofdstuk 6).
2. **Een materiaallaag:** een laag in Goxel met de naam van een materiaal
   (`glass`, `water`, `emit`, …), of een laag met een Goxel-materiaal met zo'n naam.
   Alle voxels op die laag krijgen dat materiaal, welke kleur ze ook hebben. Handig
   voor een eigen kleur die moet glimmen of wapperen.
3. **De kleurentabel** `assets/tiles/materialen.json`: elke kleur uit het palet van
   Zwervr heeft één vast materiaal (zie `palet.md`, kolom "materiaal").
4. Anders: `opaque`.

Je hoeft dus meestal niets te doen: teken met de kleuren uit het palet en het
materiaal klopt vanzelf. De materialen van Goxel zelf (Metallic, Roughness, Emission
in het paneel **Materials**) gebruikt de importer niet; alleen de naam van een
materiaal telt (regel 2).

Het reliëf (voegen, randen, scheurtjes) zit in de shader en volgt het voxelraster van
de tile: teken stenen en tegels dus op het raster zoals de generator dat doet
(baksteen 3 x 1, tegels 3 x 3). Van ver vervaagt het vanzelf.

## 6. Metadata: `<naam>.tile.json`

Naast elke `.gox` staat een `.tile.json` met wat het modelbestand niet kan opslaan:

```json
{
  "id": 336,
  "animation": "float",
  "materials": {
    "#3a3a3e": "asphalt"
  }
}
```

- **`id`**: het vaste nummer van de tile in de MeshLibrary. Kaarten slaan dit nummer
  op, dus het moet hetzelfde blijven. Nieuwe tiles krijgen het automatisch. Wil je zelf
  een nummer kiezen, verander het hier. Cellen in kaarten die het oude nummer
  gebruiken, worden dan leeg. Is het nummer al bezet, dan krijg je een waarschuwing en
  blijft de tile op zijn oude nummer.
- **`animation`**: `none`, `wind` (bomen, planten, riet: bewegen in de wind),
  `flowers` (bloemperken: wiegen vlak boven de grond) of `float` (boten, boeien,
  waterlelies: dobberen op het water). Laat je hem weg, dan raadt de importer het aan
  de bestandsnaam.
- **`materials`**: alleen voor uitzonderingen in deze ene tile. Per kleur
  (`"#3a3a3e"`) een materiaal uit de tabel hierboven. Dit gaat voor op materiaallagen
  en de kleurentabel.

De metadata wordt geschreven door `python3 tools/voxgen/generate.py --meta`. Een `id`
en eigen `materials` die al in het bestand staan, blijven behouden.

Sla je een `.tile.json` of de kleurentabel op terwijl de Godot-editor open is, dan
worden de tiles vanzelf opnieuw geïmporteerd.

## 7. Een eigen grove versie: `<naam>.lod.gox`

Als je ver uitzoomt, gebruikt Godot grove versies van de tiles: eerst met
samengevoegde kleuren, daarna op halve resolutie. Die maakt de importer zelf.

Wil je zelf bepalen hoe een tile er van ver uitziet, maak dan naast `huis.gox` een
`huis.lod.gox`. Die wordt gebruikt voor beide grove niveaus en komt niet als losse tile
in het palet. Hij mag een lagere resolutie hebben (bijvoorbeeld 16 x 16 in plaats van
32 x 32); de voxels worden dan groter, zodat hij even groot blijft. Een eigen
`huis.lod.tile.json` mag; zonder geldt de metadata van `huis.tile.json`.

## 8. MagicaVoxel-bestanden

De importer leest ook nog `.vox` (MagicaVoxel). Het materiaal komt dan uit dezelfde
regels, met als laatste stap vóór `opaque` het materiaal uit MagicaVoxel zelf (metal,
glass, emit). Staan `huis.gox` en `huis.vox` naast elkaar, dan telt alleen de `.gox`.
Een `.vox` zet je om met:

```sh
python3 tools/voxgen/convert_vox.py pad/naar/huis.vox
```

Dat schrijft `huis.gox` met dezelfde kleuren en materialen en verwijdert de `.vox`.

## 9. Handige commando's

```sh
# metadata (ID's, animatie) van alle tiles en de kleurentabel opnieuw schrijven
python3 tools/voxgen/generate.py --meta

# palet voor Goxel, kleurenoverzicht en deze handleiding opnieuw maken (na het aanpassen van palette.py)
python3 tools/voxgen/generate.py --palettes

# bibliotheken bouwen zonder editor (ook na een verse checkout)
tools/godot.sh --headless --import
tools/godot.sh --headless --script res://tools/build/build_libraries.gd

# controleren of alle tiles in de voorbeeldkaart staan
tools/godot.sh --headless --script res://tools/check/coverage.gd
```

Gegenereerde tiles worden door `generate.py` gemaakt. Zonder `--force` worden
bestaande bestanden **niet** overschreven, dus je eigen aanpassingen in Goxel blijven
bewaard. Geef een eigen tile een naam die de generator niet gebruikt.
