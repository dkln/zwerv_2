# De vier lagen van de code

Elk onderdeel van het spel (een scherm, een stuk HUD, een binnenruimte) wordt in vier lagen
verdeeld. Elke laag is een eigen script; het achtervoegsel zegt welke laag het is. Zo is van
elk script meteen duidelijk wat erin hoort en wat niet, en is de logica zonder beeld te testen.

| Laag | Bestand | Wat erin hoort | Wat er niet in hoort |
|---|---|---|---|
| **Logica** | `<naam>_rules.gd` | Pure functies en vaste gegevens: rekenen, kiezen, teksten samenstellen, toestanden bepalen. `extends RefCounted`, alles `static`. | Nodes, de scene tree, invoer, tijd, kleuren, pixels. |
| **Layout** | `<naam>_layout.gd` | Waar iets staat en hoe groot het is: maten, marges, posities, als constanten en pure functies (`extends RefCounted`, `static`). | Nodes maken, kleuren, lettertypen, beslissingen over het spel. |
| **Graphics** | `<naam>_view.gd` | Hoe het eruitziet: de nodes bouwen, kleuren, lettertypen, tekenen (`_draw`), en functies om te tonen wat het gedrag aanreikt (`show_...`). Maten komen uit de layout. | Beslissingen (wat er getoond wordt), invoer, de toestand van het spel. |
| **Gedrag** | `<naam>.gd` | Het onderdeel waar de rest van het spel mee praat: houdt de toestand bij, verwerkt invoer en tijd, geeft signalen af, vraagt de logica wat er moet gebeuren en zegt de view wat die moet tonen. | Rekenwerk dat in de logica kan, nodes opbouwen, kleuren. |

Regels:

- **Afhankelijkheden lopen één kant op.** Gedrag kent logica, layout en view. De view kent de
  layout (en vaste uiterlijke gegevens). Logica en layout kennen niemand.
- **Logica en layout hebben geen toestand en geen nodes**: elke functie is `static` en geeft
  met dezelfde invoer dezelfde uitkomst. Toestand (wat er nu geselecteerd is, wat er wacht)
  staat in het gedrag.
- **De view beslist niets.** Hij krijgt kant-en-klare waarden ("vul de balk voor 0,44",
  "schrijf 35/80") en vraagt niets aan het spel.
- **Elk script zijn eigen unit-test**: `tests/unit/<categorie>/test_<script>.gd`. De logica en
  de layout worden volledig getest zonder scene tree; de view op wat hij opbouwt en toont;
  het gedrag op wat het met invoer en tijd doet.
- **Niet elke laag is altijd nodig.** Geluid heeft geen view en geen layout. Een heel klein
  onderdeel zonder eigen maten heeft geen layout-bestand; een onderdeel zonder rekenwerk geen
  rules-bestand. Maar wat er is, staat in de goede laag: geen rekenfunctie in een view, geen
  kleur in het gedrag.
- **Gedeelde uiterlijke gegevens** (kleuren en iconen die meerdere onderdelen gebruiken)
  staan in een eigen script zonder functies die rekenen, bijvoorbeeld `stat_look.gd`.
- De indeling van een binnenruimte (`supermarket_layout.gd`, `station_layout.gd`) is dezelfde
  laag: waar dingen staan, als pure functies.

Buiten de UI geldt hetzelfde (voertuigen, mensen, binnenruimtes, dingen in de stad):

- **Logica** (`_rules`): beslissingen en rekenwerk. Hoe hard een voertuig mag, welke afslag,
  wat iets kost, wie voorrang heeft, wanneer iemand omkeert, welke regel iemand zegt.
- **Layout** (`_layout`): waar dingen staan. De plattegrond van een winkel, de plek van de
  wielen onder een auto, de zitplaatsen in een tram, de punten van een route.
- **Graphics** (`_view`): wat je ziet en hoort. Het model en zijn onderdelen, materialen,
  lichten, animaties, deeltjes, en de geluiden die erbij horen. De view krijgt te horen wat hij
  moet laten zien ("stuur zo ver in", "knipper links", "toon dit gezicht") en beslist niets.
- **Gedrag** (`<naam>.gd`): de node in de wereld. Toestand, `_physics_process`, botsingen,
  timers, signalen; vraagt de logica wat er moet gebeuren en zegt de view wat die moet tonen.

Een script dat alleen gegevens of alleen pure functies bevat en door meerdere onderdelen wordt
gebruikt (`random_pick.gd`, `money_text.gd`, `way_choice.gd`) is logica en hoeft niet hernoemd
te worden zolang het aan de regels van die laag voldoet.

Voorbeeld, het spelerskader van de HUD (`scripts/ui/hud/`):

    stat_rules.gd            logica: een stat binnen zijn maximum, "35/80", het aandeel van de balk
    stat_look.gd             uiterlijk: kleur, icoon en balk per stat
    player_frame_layout.gd   layout: maat van het portret, breedte van de icoonkolom
    player_frame_view.gd     graphics: portret, naam, balken en getallen opbouwen en tonen
    player_frame.gd          gedrag: set_stat, set_xp, set_player; beslist wanneer een getal oplicht

Meten welke publieke functies een unit-test hebben: `python3 tools/check/unit_coverage.py scripts/ui --missing`.

Controleren of alles in de goede laag staat: `python3 tools/check/code_layers.py` (de mappen die al
in lagen zijn verdeeld staan in `LAYERED_FOLDERS` in dat script; een map of bestand meegeven kan ook).
Het script leest de tekst van de scripts: een `var` of een niet-statische functie in een `_rules`- of
`_layout`-bestand, werk met nodes daar, kleuren of lettertypen in het gedrag, invoer of de logica in
een view, en een script zonder eigen unit-test worden gemeld (exitcode 1).
