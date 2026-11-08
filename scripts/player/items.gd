extends RefCounted
## The things a zwerver can carry (the inventory of the player, scripts/player/player_controller.gd,
## shown in the game menu, scripts/ui/game_menu.gd). Each item:
## - "name": shown in the menu; "kind": "eten", "drinken", "spullen" or "sleutel" (the category
##   tabs of the inventory); "rarity": "gewoon", "bijzonder", "zeldzaam", "episch", "legendarisch";
## - "icon": the name of a pixel icon (GameMenu.ITEM_ICONS in scripts/ui/game_menu.gd, or the HUD's
##   PIXEL_ICONS) or "" (the menu shows the icon of its kind);
## - "text": a short line about it (Dutch, in the voice of the game);
## - "effect": what using it does to the stats ({"honger": 30} fills the hunger meter by 30,
##   "gezondheid" heals, "uithoudingsvermogen" gives stamina back, "overprikkeldheid" calms
##   with a negative number); no "effect" = it cannot be used;
## - "action": the verb on the menu's button when it can be used ("ETEN", "DRINKEN", "GEBRUIKEN").
## What each archetype starts with: START_ITEMS (id -> count).

const ITEMS := {
	"brood": {"name": "Oud brood", "kind": "eten", "rarity": "gewoon", "icon": "brood",
		"text": "Een zak met korsten van gisteren. Of eergisteren.",
		"effect": {"honger": 25}, "action": "ETEN"},
	"frikandel": {"name": "Koude frikandel", "kind": "eten", "rarity": "bijzonder", "icon": "frikandel",
		"text": "Uit de bak achter de snackbar. Nog warm van binnen, bijna.",
		"effect": {"honger": 40, "gezondheid": -2}, "action": "ETEN"},
	"appel": {"name": "Gekneusde appel", "kind": "eten", "rarity": "gewoon", "icon": "appel",
		"text": "Van de markt, onder de kraam gerold.",
		"effect": {"honger": 12, "gezondheid": 3}, "action": "ETEN"},
	"vis": {"name": "Verse vis", "kind": "eten", "rarity": "bijzonder", "icon": "vis",
		"text": "Uit de Hofvijver. Vraag niet welke.",
		"effect": {"honger": 45}, "action": "ETEN"},
	"water": {"name": "Fles kraanwater", "kind": "drinken", "rarity": "gewoon", "icon": "fles",
		"text": "Bijgevuld op het toilet van het station.",
		"effect": {"uithoudingsvermogen": 25}, "action": "DRINKEN"},
	"energiedrank": {"name": "Energiedrank", "kind": "drinken", "rarity": "bijzonder", "icon": "bolt",
		"text": "Een blik van de goedkoopste soort. Je hart hoort het eerder dan jij.",
		"effect": {"uithoudingsvermogen": 60, "overprikkeldheid": 15}, "action": "DRINKEN"},
	"jenever": {"name": "Kruik jenever", "kind": "drinken", "rarity": "zeldzaam", "icon": "kruik",
		"text": "Steen, koud, en halfvol. Of halfleeg, als je Jos vraagt.",
		"effect": {"overprikkeldheid": -30, "uithoudingsvermogen": -10}, "action": "DRINKEN"},
	"bier": {"name": "Blikje bier", "kind": "drinken", "rarity": "gewoon", "icon": "blik",
		"text": "Lauw. Het beste bier is het bier dat je hebt.",
		"effect": {"overprikkeldheid": -15, "honger": 5}, "action": "DRINKEN"},
	"sigaretten": {"name": "Pakje shag", "kind": "spullen", "rarity": "gewoon", "icon": "shag",
		"text": "Nog genoeg voor een paar vloeitjes.",
		"effect": {"overprikkeldheid": -20, "gezondheid": -3}, "action": "ROKEN"},
	"slaapzak": {"name": "Slaapzak", "kind": "spullen", "rarity": "bijzonder", "icon": "slaapzak",
		"text": "Ruikt naar alle portieken van Den Haag."},
	"accordeon": {"name": "Accordeon", "kind": "spullen", "rarity": "episch", "icon": "accordeon",
		"text": "Dertig jaar Grote Markt. Mist een knop, niemand hoort het."},
	"hengel": {"name": "Hengel", "kind": "spullen", "rarity": "zeldzaam", "icon": "hengel",
		"text": "Van de kotter meegenomen. Het enige dat hij nog van de zee heeft."},
	"pleister": {"name": "Pleisters", "kind": "spullen", "rarity": "gewoon", "icon": "heart",
		"text": "Een doosje uit de apotheek. Betaald, deze keer.",
		"effect": {"gezondheid": 15}, "action": "GEBRUIKEN"},
	"statiegeld": {"name": "Statiegeldflessen", "kind": "spullen", "rarity": "gewoon", "icon": "flessen",
		"text": "Vijftien cent per stuk bij de Albert Heijn."},
	"hoed": {"name": "Cowboyhoed", "kind": "sleutel", "rarity": "legendarisch", "icon": "hoed",
		"text": "Van de rodeo in het Zuiderpark. Ook een kussen."},
	"foto": {"name": "Oude foto", "kind": "sleutel", "rarity": "legendarisch", "icon": "foto",
		"text": "Een vrouw, een kotter en de haven van Scheveningen."},
}

const START_ITEMS := {
	"jos": {"jenever": 1, "brood": 2, "hoed": 1},
	"martin": {"energiedrank": 3, "slaapzak": 1, "water": 1},
	"ufo_piloot": {"brood": 1, "sigaretten": 1, "water": 2},
	"willem": {"statiegeld": 6, "brood": 1, "pleister": 1, "bier": 1},
	"sjaan": {"accordeon": 1, "sigaretten": 1, "appel": 2},
	"gerrit": {"hengel": 1, "vis": 1, "bier": 2, "foto": 1},
}


static func item(item_id: String) -> Dictionary:
	return ITEMS.get(item_id, {})


static func can_use(item_id: String) -> bool:
	return ITEMS.get(item_id, {}).has("effect")
