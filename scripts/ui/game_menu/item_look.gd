extends RefCounted
## How the items look wherever their pixel icon is shown (the inventory of the game menu,
## the shop screen, the logos of the station's shops): the icon of each item and the colour
## of the HUD's own icons when an item uses one (graphics, only data; docs/CODE_LAGEN.md).
## Which icon an item gets: inventory_tab_rules.gd (`icon_name`); the colour of its rarity:
## Items.RARITY_COLOURS (scripts/player/items.gd).
##   const ItemLook = preload("res://scripts/ui/game_menu/item_look.gd")

## Pixel icons of the items ("#" = coloured; Items.ITEMS "icon"), drawn at 3 x 3 screen pixels
## per pixel in the grid; an icon not here comes from the HUD's PIXEL_ICONS (StatLook), an
## item without one gets the icon of its kind (InventoryTabRules.KIND_ICONS).
const ITEM_ICONS := {
	"ov_chipkaart": {"colour": Color("#4FA3E8"), "rows": ["##########", "#........#", "#.##.....#", "#.##..##.#", "#.....##.#", "#........#", "##########"]},
	"pinpas": {"colour": Color("#F2C230"), "rows": ["##########", "#........#", "#.##.....#", "#.##.....#", "#........#", "#.######.#", "##########"]},
	"kaartje": {"colour": Color("#E8E6F0"), "rows": ["########", "#......#", "#.####.#", "#......#", "#.##.#.#", "#......#", "########"]},
	"brood": {"colour": Color("#D9A55B"), "rows": [".#######.", "#########", "##.##.###", "#########", "#########", ".#######."]},
	"kroket": {"colour": Color("#B8692E"), "rows": [".........", "..#####..", ".#######.", ".#######.", ".#######.", "..#####..", "........."]},
	"patat": {"colour": Color("#F2C440"), "rows": ["..#.#.#..", ".#.#.#.#.", "..#####..", "..#####..", "...###...", "...###...", "....#...."]},
	"frikandel": {"colour": Color("#C0703A"), "rows": ["......##.", ".....###.", "....###..", "...###...", "..###....", ".###.....", ".##......"]},
	"appel": {"colour": Color("#FF5D73"), "rows": ["....#....", "...#.##..", ".###.###.", "#########", "#########", "#########", ".#######.", "..##.##.."]},
	"vis": {"colour": Color("#9AD0F0"), "rows": ["..####...#", ".######.##", "##.#######", "##########", ".######.##", "..####...#"]},
	"fles": {"colour": Color("#6FC3FF"), "rows": ["...###...", "...#.#...", "..#####..", ".#######.", ".#.....#.", ".#.....#.", ".#######.", ".#######."]},
	"blik": {"colour": Color("#E8C547"), "rows": [".#####.", "#######", "##...##", "#######", "##...##", "#######", ".#####."]},
	"kruik": {"colour": Color("#C9A76A"), "rows": ["...###...", "....#....", "..#####..", ".#######.", "#########", "#########", ".#######.", "..#####.."]},
	"shag": {"colour": Color("#7FB0A0"), "rows": ["#########", "#.......#", "#########", "#########", "##.#.#.##", "#########"]},
	"slaapzak": {"colour": Color("#5B8CFF"), "rows": ["..#####..", ".##...##.", "##.###.##", "##.#.#.##", "##.###.##", ".##...##.", "..#####.."]},
	"emmer": {"colour": Color("#6FC3FF"), "rows": ["..#####..", ".#.....#.", "#########", ".#######.", ".##...##.", ".#######.", "..#####.."]},
	"hengel": {"colour": Color("#C9A76A"), "rows": ["........#", ".......#.", "......#.#", ".....#..#", "....#...#", "...#....#", "..#....##", ".#.....##", "#........"]},
	"flessen": {"colour": Color("#6FC3FF"), "rows": ["..#...#..", "..#...#..", ".###.###.", ".###.###.", ".###.###.", ".###.###.", ".###.###."]},
	"hoed": {"colour": Color("#B5823A"), "rows": ["...###...", "..#####..", "..#####..", "#########", ".#######."]},
	"foto": {"colour": Color("#E8E6F0"), "rows": ["#########", "#.......#", "#..##...#", "#.####..#", "#.......#", "#########"]},
	"tas": {"colour": Color("#9AA0C8"), "rows": ["..###..", ".#...#.", "#######", "#######", "#######", "#######"]},
	"sleutel": {"colour": Color("#FFB547"), "rows": [".###......", "#...######", "#...#..#.#", ".###......"]},
	# the goods of the shops of Den Haag Centraal (the shop screen, scripts/ui/shop_screen.gd)
	"beker": {"colour": Color("#C9A76A"), "rows": [".#.#.#...", "..#.#....", "#######..", "#######.#", ".#####.##", ".#####.#.", "..###....", "..###...."]},
	"koek": {"colour": Color("#D9A55B"), "rows": ["..#####..", ".#######.", "####.####", "###...###", "####.####", ".#######.", "..#####.."]},
	"broodje": {"colour": Color("#E0B070"), "rows": ["..#####..", ".#######.", "#########", ".........", "#########", ".#######."]},
	"krant": {"colour": Color("#E8E6F0"), "rows": ["#########", "#.##.##.#", "#.......#", "#.###.#.#", "#.......#", "#.###.#.#", "#########"]},
	"bloem": {"colour": Color("#FF5D73"), "rows": [".#.#.#.", "#######", ".#####.", "..###..", "...#...", "..##...", "...#..."]},
	"boek": {"colour": Color("#5B8CFF"), "rows": ["#######.", "#.....##", "#.###.##", "#.....##", "#.###.##", "#.....##", "########"]},
	"kaart": {"colour": Color("#8BE36B"), "rows": ["##.##.##", "#.#..#.#", "##.##.##", "#.#..#.#", "##.##.##"]},
	"wafel": {"colour": Color("#D9A55B"), "rows": ["..#####..", ".#.#.#.#.", "#.#.#.#.#", "##.#.#.##", "#.#.#.#.#", ".#.#.#.#.", "..#####.."]},
	"snoep": {"colour": Color("#C08BFF"), "rows": ["#.......#", "##.###.##", "#########", "##.###.##", "#.......#"]},
	"reep": {"colour": Color("#8A5A3A"), "rows": ["#########", "##.##.###", "#########", "##.##.###", "#########"]},
}
## Colours of the HUD's own icons when an item uses one.
const HUD_ICON_COLOURS := {"heart": Color("#FF5D73"), "bolt": Color("#8BE36B"), "chomp": Color("#FFB547"), "burst": Color("#C08BFF")}
## How see-through the icon of an item you have not got is in the slot kept for it (the ID card).
const MISSING_ITEM_ALPHA := 0.25
