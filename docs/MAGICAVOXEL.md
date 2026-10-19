# Tiles maken en aanpassen in MagicaVoxel

Elke tile in Zwervr is een los MagicaVoxel-bestand (`.vox`). Godot importeert die
bestanden zelf en zet ze in de GridMap-bibliotheken. Dit document legt uit hoe je een
tile maakt, welke kleuren je gebruikt, hoe materialen werken en wat er in de
metadata (`.tile.json`) staat.


## 1. Waar staan de tiles?

```
assets/tiles/<laag>/<groep>/<naam>.vox
```

De eerste map bepaalt in welke laag (GridMap) de tile terechtkomt:

| map        | laag in Godot | cel           | modelmaat (voxels)                     |
|------------|---------------|---------------|----------------------------------------|
| `grond`    | Grond         | 4 x 1 x 4 m   | 32 x 32, 8 hoog per meter (mag hoger)  |
| `gebouwen` | Gebouwen      | 4 x 3 x 4 m   | 48 x 48 x 24: blok van 32 x 32 in het midden, 8 voxels rand voor balkons en luifels |
| `details`  | Details       | 0,5 x 0,5 x 0,5 m | vrij                               |
| `props`    | Props         | 0,5 x 0,5 x 0,5 m | vrij                               |

De groep (de tweede map) kies je zelf. De naam van de tile in het palet is
`<groep>/<naam>`, bijvoorbeeld `weg/rijstrook_kant`.

Maten: **1 voxel = 12,5 cm.** Een persoon van 1,80 m is 14 à 15 voxels hoog. Een
verdieping is 3 m (24 voxels).


## 2. Een nieuwe tile maken

1. Open een sjabloon uit `tools/voxgen/paletten/` in MagicaVoxel:
   `palet_straat.vox` (wegen, stoepen, natuur, straatmeubilair) of
   `palet_gebouwen.vox` (gevels, daken, kozijnen). Daarin staan het juiste palet en
   de juiste materialen; het model is een kleurenkaart die je weggooit.
2. Zet de modelmaat (Size) goed (zie de tabel hierboven) en teken je model.
3. Sla op als nieuw bestand op de goede plek, bijvoorbeeld
   `assets/tiles/props/straat/mijn_bankje.vox`.
4. Ga terug naar Godot. De tile wordt geïmporteerd, krijgt een vaste ID en staat
   binnen een paar seconden in het palet van de juiste GridMap.
5. Wil je asfalt, steen, baksteen, grind of gelakt metaal gebruiken? Draai dan
   `python3 tools/voxgen/generate.py --meta`. Dat schrijft de metadata
   (materialen) voor alle tiles, ook voor de tiles die je zelf hebt gemaakt.

Een bestaande tile aanpassen gaat net zo: openen, aanpassen, opslaan. Godot ziet de
wijziging en importeert de tile opnieuw.

### Regels voor het model

- **Draaipunt:** het midden van het model in x/y, de onderkant in z. Houd de modelmaat
  van een bestaande tile gelijk, anders verschuift hij.
- **Voorkant:** de kant met de laagste Y in MagicaVoxel. In Godot wijst die naar +Z
  (naar de camera). Stoepranden, gevels en oevers horen aan die kant.
- **Eén model per bestand.** Godot gebruikt alleen het eerste model.
- **Ambient occlusion** (donkere hoekjes) rekent de importer zelf uit. Teken die niet in.
- **Gelijkende kleuren** worden bij het importeren samengevoegd tot grotere vlakken
  (minder driehoeken). De shader legt de variatie per voxel er weer overheen, dus
  kleine kleurverschillen blijven zichtbaar.
- **Gebouwen** zijn van binnen leeg, zodat je er later in kunt lopen. Een dicht blok
  krijgt een botsdoos van 4 x 3 x 4 m; holle tiles een exacte vorm.


## 3. Het palet

Een `.vox` heeft één palet van **255 kleuren**. Elke voxel onthoudt alleen het
**nummer** van zijn kleur (1 t/m 255). Er staan geen namen in het bestand.

Twee stukken van het palet zijn gereserveerd:

| paletnummers | betekenis in Godot                    |
|--------------|---------------------------------------|
| 225 – 232    | **water** (golvend, spiegelend), mits het materiaal glass is |
| 233 – 248    | **vlag** (wappert in de wind)         |

Daardoor passen er 224 gewone kleuren in één bestand. Het totale palet van Zwervr is
groter, daarom zijn er twee sjablonen ("straat" en "gebouwen"). Allebei hebben ze de
water- en vlagkleuren op de goede plekken.

Bij elk sjabloon hoort een overzicht met per paletnummer de kleur, de naam en het
materiaal: `tools/voxgen/paletten/palet_straat.md` en `palet_gebouwen.md`. Daar staat
ook een `.png` van het palet, als je alleen het palet in een ander bestand wilt laden.

De kleurnamen (`asfalt1`, `baksteen3`, `amsterdamgroen`, …) bestaan alleen in de
generator (`tools/voxgen/palette.py`). Gebruik je de kleuren uit het sjabloon, dan
herkent `generate.py --meta` ze en krijgen ze vanzelf het goede materiaal.

**Let op bij eigen kleuren:** een kleur die niet in het palet van Zwervr staat, wordt
een gewone, matte kleur. Wil je er een ander materiaal op, zet dat dan zelf in de
metadata (zie hoofdstuk 5).


## 4. Materialen

Een materiaal bepaalt hoe een kleur eruitziet in Godot: mat, glanzend, doorzichtig,
lichtgevend, enzovoort. Er zijn twee bronnen:

**Uit MagicaVoxel** (het Matter-paneel, per kleur in te stellen):

| MagicaVoxel            | in Godot        | voorbeeld                         |
|------------------------|-----------------|-----------------------------------|
| diffuse                | `opaque`        | alles wat mat is                  |
| metal                  | `metal`         | lantaarnkap, vangrail, kabels     |
| metal met roughness < 0,15 | `panel`     | zonnepanelen (spiegelend)         |
| glass / blend          | `glass`         | ramen                             |
| glass op 225 – 232     | `water`         | grachten, vijvers                 |
| emit                   | `emit`          | lampen, verlichte ramen ('s nachts) |

**Alleen via de metadata** (MagicaVoxel kent deze niet; in MagicaVoxel zijn ze diffuse):

| materiaal  | effect in Godot                                                  |
|------------|------------------------------------------------------------------|
| `asphalt`  | steenkorrel, slijtplekken en een lichte glans op liggende vlakken |
| `stone`    | tegels, keien, natuursteen en beton: lichte korrel en reliëf     |
| `brick`    | metselwerk                                                       |
| `gravel`   | grind: kleine ronde steentjes                                    |
| `painted`  | gelakt metaal: halfglanzend met een lichte metaalglans (lantaarnpalen, verkeersborden) |
| `flag`     | wappert (ook buiten de vaste vlagplekken, als je dat in de metadata zet) |

Kleuren uit de sjablonen krijgen deze materialen automatisch via `generate.py --meta`
(zie het overzicht bij het sjabloon, kolom "materiaal").


## 5. Metadata: `<naam>.tile.json`

Naast elke `.vox` staat een `.tile.json` met wat MagicaVoxel niet kan opslaan:

```json
{
	"id": 336,
	"animation": "float",
	"materials": {
		"1": "asphalt",
		"#3a3a3e": "asphalt",
		"225": "water"
	}
}
```

- **`id`**: het vaste nummer van de tile in de MeshLibrary. Kaarten slaan dit nummer
  op, dus het moet hetzelfde blijven. Nieuwe tiles krijgen het automatisch. Wil je zelf
  een nummer kiezen, verander het hier. Cellen in kaarten die het oude nummer
  gebruiken, worden dan leeg. Is het nummer al bezet, dan krijg je een waarschuwing en
  blijft de tile op zijn oude nummer.
- **`animation`**: `none`, `wind` (bomen, planten, riet: bewegen in de wind) of
  `float` (boten, boeien, waterlelies: dobberen op het water). Laat je hem weg, dan
  raadt de importer het aan de bestandsnaam.
- **`materials`**: per kleur een materiaal uit de tabellen hierboven. De sleutel is
  - een **paletnummer** (`"1"`): precies die plek in het palet van dit bestand, zoals
    MagicaVoxel hem toont als je over de kleur gaat. Verschuif je kleuren in het palet,
    dan kan het nummer naar een andere kleur wijzen;
  - of een **kleur** (`"#3a3a3e"`): elke plek met precies die kleur. Blijft kloppen als
    je het palet herschikt, niet als je de kleur verandert.

  Kleuren die er niet in staan, houden het materiaal uit MagicaVoxel.

De metadata wordt geschreven door `python3 tools/voxgen/generate.py --meta`. Dat leest
het palet uit het `.vox`-bestand zelf, dus draai het na het aanpassen van kleuren
opnieuw. Een `id` die al in het bestand staat, blijft behouden.

Sla je een `.tile.json` op terwijl de Godot-editor open is, dan wordt de tile vanzelf
opnieuw geïmporteerd.


## 6. Een eigen grove versie: `<naam>.lod.vox`

Als je ver uitzoomt, gebruikt Godot grove versies van de tiles: eerst met
samengevoegde kleuren, daarna op halve resolutie. Die maakt de importer zelf.

Wil je zelf bepalen hoe een tile er van ver uitziet, maak dan naast `huis.vox` een
`huis.lod.vox`. Die wordt gebruikt voor beide grove niveaus en komt niet als losse tile
in het palet. Hij mag een lagere resolutie hebben (bijvoorbeeld 16 x 16 in plaats van
32 x 32); de voxels worden dan groter, zodat hij even groot blijft. Een eigen
`huis.lod.tile.json` mag; zonder gelden de materialen van `huis.tile.json`.


## 7. Handige commando's

```sh
# metadata (materialen, ID's, animatie) van alle tiles opnieuw schrijven
python3 tools/voxgen/generate.py --meta

# sjablonen en paletoverzichten opnieuw maken (na het aanpassen van palette.py)
python3 tools/voxgen/generate.py --palettes

# bibliotheken bouwen zonder editor (ook na een verse checkout)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/build_libraries.gd

# controleren of alle tiles in de voorbeeldkaart staan
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/coverage.gd
```

Gegenereerde tiles worden door `generate.py` gemaakt. Zonder `--force` worden
bestaande bestanden **niet** overschreven, dus je eigen aanpassingen in MagicaVoxel
blijven bewaard. Geef een eigen tile een naam die de generator niet gebruikt.
