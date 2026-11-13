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
## Room: every kind of item takes one slot ("vakje", however many of it; not the cans and
## bottles in the plastic bag, "bag", nor the clothes worn, "worn": takes_slot), and a zwerver has
## only BASE_SLOTS of them in his pockets; a rucksack picked up in the town
## (scripts/world/things/backpacks.gd) adds BACKPACK_SLOTS. Nobody starts with a rucksack.
const BASE_SLOTS := 4
## An effect of this much fills the stat to its maximum, whatever that is for the character
## (the kroket: your stomach full again); shown as "VOL".
const FULL := 999
const BACKPACK_SLOTS := 8

const ITEMS := {
	"brood": {"name": "Oud brood", "kind": "eten", "rarity": "gewoon", "icon": "brood",
		"text": "Een zak met korsten van gisteren. Of eergisteren.",
		"effect": {"honger": 25}, "action": "ETEN"},
	"frikandel": {"name": "Koude frikandel", "kind": "eten", "rarity": "bijzonder", "icon": "frikandel",
		"text": "Uit de bak achter de snackbar. Nog warm van binnen, bijna.",
		"effect": {"honger": 40, "gezondheid": -2}, "action": "ETEN"},
	"kroket": {"name": "Warme kroket", "kind": "eten", "rarity": "bijzonder", "icon": "kroket",
		"text": "Knapperig, gloeiend heet van binnen. Uit de muur of over de toonbank: een Haagse kroket.",
		"effect": {"honger": FULL, "overprikkeldheid": -5}, "action": "ETEN"},
	"patat": {"name": "Patatje met", "kind": "eten", "rarity": "bijzonder", "icon": "patat",
		"text": "Een puntzak patat met mayonaise. Vet, zout en warm: precies goed.",
		"effect": {"honger": 50, "gezondheid": -1}, "action": "ETEN"},
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
	"emmer": {"name": "Emmer en zeem", "kind": "spullen", "rarity": "episch", "icon": "emmer",
		"text": "Dertig jaar wc's gepoetst. De emmer lekt, de zeem glimt nog."},
	"hengel": {"name": "Hengel", "kind": "spullen", "rarity": "zeldzaam", "icon": "hengel",
		"text": "Van de kotter meegenomen. Het enige dat hij nog van de zee heeft."},
	"pleister": {"name": "Pleisters", "kind": "spullen", "rarity": "gewoon", "icon": "heart",
		"text": "Een doosje uit de apotheek. Betaald, deze keer.",
		"effect": {"gezondheid": 15}, "action": "GEBRUIKEN"},
	"statiegeld": {"name": "Statiegeldflessen", "kind": "spullen", "rarity": "gewoon", "icon": "flessen",
		"text": "Vijftien cent per stuk bij de Albert Heijn.", "bag": true},
	"hoed": {"name": "Cowboyhoed", "kind": "sleutel", "rarity": "legendarisch", "icon": "hoed",
		"text": "Van de rodeo in het Zuiderpark. Ook een kussen."},
	"foto": {"name": "Oude foto", "kind": "sleutel", "rarity": "legendarisch", "icon": "foto",
		"text": "Een vrouw, een kotter en de haven van Scheveningen."},
	# from the shops of Den Haag Centraal (data/gesprekken/winkels.json, the shop screen)
	"koffie": {"name": "Bekertje koffie", "kind": "drinken", "rarity": "gewoon", "icon": "beker",
		"text": "Zwart en heet, in een kartonnen beker. Het eerste dat warm is vandaag.",
		"effect": {"uithoudingsvermogen": 30, "overprikkeldheid": 5}, "action": "DRINKEN"},
	"cappuccino": {"name": "Cappuccino", "kind": "drinken", "rarity": "bijzonder", "icon": "beker",
		"text": "Met een schuimkraag en cacao erop. Duwus Bertus weet hoe het moet.",
		"effect": {"uithoudingsvermogen": 30, "honger": 5, "overprikkeldheid": -5}, "action": "DRINKEN"},
	"gevulde_koek": {"name": "Gevulde koek", "kind": "eten", "rarity": "gewoon", "icon": "koek",
		"text": "Met amandelspijs en een half amandeltje bovenop. Plakt aan je vingers.",
		"effect": {"honger": 20}, "action": "ETEN"},
	"broodje_kaas": {"name": "Broodje kaas", "kind": "eten", "rarity": "gewoon", "icon": "broodje",
		"text": "Een witte bol met jonge kaas. Niet spannend, wel eerlijk.",
		"effect": {"honger": 35}, "action": "ETEN"},
	"broodje_kroket": {"name": "Broodje kroket", "kind": "eten", "rarity": "bijzonder", "icon": "broodje",
		"text": "Een kroket geplet tussen een zacht bolletje, met mosterd. Haagser wordt het niet.",
		"effect": {"honger": 50, "overprikkeldheid": -5}, "action": "ETEN"},
	"krentenbol": {"name": "Krentenbol", "kind": "eten", "rarity": "gewoon", "icon": "brood",
		"text": "Meer krenten dan bol. Goed voor onderweg.",
		"effect": {"honger": 18}, "action": "ETEN"},
	"mineraalwater": {"name": "Flesje bronwater", "kind": "drinken", "rarity": "gewoon", "icon": "fles",
		"text": "Gekocht, niet bijgevuld. Koud uit de koeling van de kiosk.",
		"effect": {"uithoudingsvermogen": 30, "gezondheid": 2}, "action": "DRINKEN"},
	"krant": {"name": "Krant van vandaag", "kind": "spullen", "rarity": "gewoon", "icon": "krant",
		"text": "Het nieuws van vandaag, vanavond een deken.",
		"effect": {"overprikkeldheid": -8}, "action": "LEZEN"},
	"kauwgom": {"name": "Pakje kauwgom", "kind": "eten", "rarity": "gewoon", "icon": "snoep",
		"text": "Pepermunt. Voor een frisse adem in de spits.",
		"effect": {"overprikkeldheid": -6}, "action": "KAUWEN"},
	"tulpen": {"name": "Bos tulpen", "kind": "spullen", "rarity": "bijzonder", "icon": "bloem",
		"text": "Rood en geel, vers van de veiling. Voor wie eigenlijk?",
		"effect": {"overprikkeldheid": -15}, "action": "RUIKEN"},
	"roos": {"name": "Losse roos", "kind": "spullen", "rarity": "gewoon", "icon": "bloem",
		"text": "Eén rode roos in cellofaan. Romantisch, op een perron.",
		"effect": {"overprikkeldheid": -8}, "action": "RUIKEN"},
	"puzzelboek": {"name": "Puzzelboekje", "kind": "spullen", "rarity": "gewoon", "icon": "boek",
		"text": "Zweedse puzzels en een paar sudoku's. Het potloodje zit er al bij.",
		"effect": {"overprikkeldheid": -12}, "action": "PUZZELEN"},
	"stadskaart": {"name": "Kaart van Den Haag", "kind": "spullen", "rarity": "bijzonder", "icon": "kaart",
		"text": "Van Kijkduin tot Ypenburg, gevouwen zoals niemand hem ooit terugvouwt."},
	"pocketboek": {"name": "Pocketboek", "kind": "spullen", "rarity": "zeldzaam", "icon": "boek",
		"text": "Een detective die zich afspeelt in Scheveningen. De moordenaar is altijd de visboer.",
		"effect": {"overprikkeldheid": -25}, "action": "LEZEN"},
	"stroopwafel": {"name": "Verse stroopwafel", "kind": "eten", "rarity": "bijzonder", "icon": "wafel",
		"text": "Warm van het ijzer, de stroop loopt eruit. Gouda zou trots zijn.",
		"effect": {"honger": 22, "overprikkeldheid": -5}, "action": "ETEN"},
	"pak_stroopwafels": {"name": "Pak stroopwafels", "kind": "eten", "rarity": "gewoon", "icon": "wafel",
		"text": "Tien stuks in plastic. Voor bij de koffie, of als avondeten.",
		"effect": {"honger": 35}, "action": "ETEN"},
	"drop": {"name": "Zak drop", "kind": "eten", "rarity": "gewoon", "icon": "snoep",
		"text": "Zoute muntjes en salmiakruitjes. Hollandser kan niet.",
		"effect": {"honger": 8, "overprikkeldheid": -8}, "action": "ETEN"},
	"winegums": {"name": "Zak winegums", "kind": "eten", "rarity": "gewoon", "icon": "snoep",
		"text": "Er zit geen wijn in. Wel suiker, heel veel suiker.",
		"effect": {"honger": 10, "uithoudingsvermogen": 10}, "action": "ETEN"},
	"chocoladereep": {"name": "Chocoladereep", "kind": "eten", "rarity": "gewoon", "icon": "reep",
		"text": "Melkchocolade met hazelnoot. Een beetje gesmolten in je zak.",
		"effect": {"honger": 15, "overprikkeldheid": -5}, "action": "ETEN"},
	# from the supermarkets, DERREK and ALFRED STEYHN (data/gesprekken/supermarkten.json)
	"crackers": {"name": "Pak crackers", "kind": "eten", "rarity": "gewoon", "icon": "koek",
		"text": "Droog, knapperig en ze kruimelen overal. Maar ze vullen.",
		"effect": {"honger": 22}, "action": "ETEN"},
	"ontbijtkoek": {"name": "Ontbijtkoek", "kind": "eten", "rarity": "gewoon", "icon": "brood",
		"text": "Een hele koek, kruidig en taai. Ontbijt, lunch en avondeten in één.",
		"effect": {"honger": 32}, "action": "ETEN"},
	"zak_chips": {"name": "Zak chips", "kind": "eten", "rarity": "gewoon", "icon": "snoep",
		"text": "Naturel, de grote zak. Half lucht, half chips.",
		"effect": {"honger": 15, "overprikkeldheid": -6}, "action": "ETEN"},
	"blik_soep": {"name": "Blik soep", "kind": "eten", "rarity": "gewoon", "icon": "blik",
		"text": "Erwtensoep met worst. Koud uit het blik is ook soep.",
		"effect": {"honger": 38, "gezondheid": 2}, "action": "ETEN"},
	"pak_melk": {"name": "Pak melk", "kind": "drinken", "rarity": "gewoon", "icon": "fles",
		"text": "Halfvol, een liter. Goed voor de botten, zegt de reclame.",
		"effect": {"uithoudingsvermogen": 18, "honger": 10}, "action": "DRINKEN"},
	"ijsje": {"name": "Waterijsje", "kind": "eten", "rarity": "gewoon", "icon": "snoep",
		"text": "Een raketje uit de diepvries. Smelt sneller dan je denkt.",
		"effect": {"overprikkeldheid": -12, "uithoudingsvermogen": 8}, "action": "ETEN"},
	"vers_brood": {"name": "Vers brood", "kind": "eten", "rarity": "bijzonder", "icon": "brood",
		"text": "Een heel volkoren, nog lauw. Eens geen korsten van gisteren.",
		"effect": {"honger": 45}, "action": "ETEN"},
	"croissant": {"name": "Croissant", "kind": "eten", "rarity": "gewoon", "icon": "koek",
		"text": "Boterig, uit de bakkerij van de supermarkt. Bladert in je jas.",
		"effect": {"honger": 18, "overprikkeldheid": -4}, "action": "ETEN"},
	"banaan": {"name": "Banaan", "kind": "eten", "rarity": "gewoon", "icon": "appel",
		"text": "Geel met bruine stipjes: precies goed.",
		"effect": {"honger": 14, "gezondheid": 3}, "action": "ETEN"},
	# from the machines in Den Haag Centraal (scripts/world/station/station.gd): opens the OV gates
	"ov_chipkaart": {"name": "OV-chipkaart", "kind": "sleutel", "rarity": "bijzonder", "icon": "ov_chipkaart",
		"text": "Anoniem, blauw, € 7,50 uit de automaat (met € 2,50 reissaldo). Piep bij binnenkomst, piep-piep bij vertrek."},
	# from the OV-chipkaart machines (scripts/ui/machines/ov_machine_screen.gd): one ride,
	# taken in at the gate where you check out
	"los_kaartje": {"name": "Los kaartje", "kind": "spullen", "rarity": "gewoon", "icon": "kaartje",
		"text": "Eén enkele reis, wegwerp. Bij het uitchecken houdt het poortje hem."},
	# from the waste bins in the town (scripts/world/things/litter_bins.gd): statiegeld at the
	# machine in every supermarket (scripts/world/things/deposit_return.gd)
	"blikje": {"name": "Leeg blikje", "kind": "spullen", "rarity": "gewoon", "icon": "blik",
		"text": "Uit een prullenbak gevist. Veertig cent statiegeld bij de automaat in de supermarkt.", "bag": true},
	# lost bank cards (scripts/world/things/lost_bank_cards.gd): every card its own account and PIN,
	# kept on the player (scripts/player/bank_cards.gd); the menu adds each card's riddle to
	# this text (BankCards.description)
	"pinpas": {"name": "Gevonden pinpas", "kind": "sleutel", "rarity": "zeldzaam", "icon": "pinpas",
		"text": "Iemand is zijn pinpas kwijt. Op de achterkant staat met balpen een raadsel gekrabbeld."},
	# your own identity card: stolen in your sleep at the start of the game (the first mission);
	# the inventory always keeps a slot for it, empty while you have not got it (GameMenu)
	"id_kaart": {"name": "ID-kaart", "kind": "sleutel", "rarity": "legendarisch", "icon": "pinpas",
		"text": "Je eigen ID-kaart. Zonder ben je niemand: geen postadres, geen uitkering, geen kamer.",
		"missing_text": "Gestolen terwijl je sliep. Iemand loopt nu rond met jouw gezicht in zijn zak."},
	# from Ome Wim (the second mission): worn as soon as you have it ("worn": the player keeps
	# warmer, hunger runs out slower: PlayerController.WORN_HUNGER_FACTOR)
	"oude_jas": {"name": "Oude jas", "kind": "spullen", "rarity": "zeldzaam", "icon": "",
		"text": "Van Ome Wim. De voering is kapot, maar hij houdt de wind tegen. Ruikt naar sigaren en natte hond.",
		"worn": true},
}

const START_ITEMS := {
	"jos": {"jenever": 1, "brood": 2, "hoed": 1},
	"martin": {"energiedrank": 3, "slaapzak": 1, "water": 1},
	"ufo_piloot": {"brood": 1, "sigaretten": 1, "water": 2},
	"willem": {"statiegeld": 6, "brood": 1, "pleister": 1, "bier": 1},
	"sjaan": {"emmer": 1, "sigaretten": 1, "appel": 2},
	"gerrit": {"hengel": 1, "vis": 1, "bier": 2, "foto": 1},
}


static func item(item_id: String) -> Dictionary:
	return ITEMS.get(item_id, {})


## The colour of an item's rarity (as the inventory shows it, GameMenu.RARITIES).
const RARITY_COLOURS := {
	"gewoon": Color("#9AA0C8"), "bijzonder": Color("#8BE36B"), "zeldzaam": Color("#5B8CFF"),
	"episch": Color("#C08BFF"), "legendarisch": Color("#FFB547"),
}


static func rarity_colour(item_id: String) -> Color:
	return RARITY_COLOURS.get(String(item(item_id).get("rarity", "gewoon")), RARITY_COLOURS.gewoon)


static func can_use(item_id: String) -> bool:
	return ITEMS.get(item_id, {}).has("effect")


## Whether an item takes a slot ("vakje") of the pockets: not what goes in the plastic bag
## everyone carries for the statiegeld ("bag": cans and bottles), nor the clothes you wear
## ("worn"). The first mission has you collect cans before you can drop anything.
static func takes_slot(item_id: String) -> bool:
	var entry: Dictionary = ITEMS.get(item_id, {})
	return not bool(entry.get("bag", false)) and not bool(entry.get("worn", false))


## The item whose slot the inventory always keeps, empty while you have not got it.
const ALWAYS_SHOWN := "id_kaart"


## Whether an item is worn as soon as you have it (clothes: "worn").
static func is_worn(item_id: String) -> bool:
	return bool(ITEMS.get(item_id, {}).get("worn", false))
