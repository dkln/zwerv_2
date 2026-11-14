extends RefCounted
## The logic of the close-up of a machine (the rules layer of
## scripts/ui/machines/machine_screen.gd, which is the behaviour; machine_screen_layout.gd
## has the sizes, machine_screen_view.gd builds and shows it): the tones a text can have,
## what the panel and the key line say, which tiles of the town stand behind the machine,
## where the cursor goes next, and where a point of the window is on the machine (on the
## picture of its screen, the bulge of its glass taken into account, or on one of its
## parts). Plain functions, without nodes: the behaviour hands in what the view measured.
##   const MachineScreenRules = preload("res://scripts/ui/machines/machine_screen_rules.gd")

const MoneyText = preload("res://scripts/common/money_text.gd")

## The tones of a text (the view has a colour for each): the machine's own screen colour,
## plain, a heading, less important, accepted, a warning, refused, and the paper of a bon.
const TONE_SCREEN := ""
const TONE_TEXT := "tekst"
const TONE_ACCENT := "accent"
const TONE_MUTED := "gedempt"
const TONE_GOOD := "goed"
const TONE_WARNING := "waarschuwing"
const TONE_REFUSED := "geweigerd"
const TONE_PAPER := "papier"
const TONES := [TONE_SCREEN, TONE_TEXT, TONE_ACCENT, TONE_MUTED, TONE_GOOD, TONE_WARNING, TONE_REFUSED, TONE_PAPER]
## The line with the keys along the bottom: with a keyboard and with a controller.
const KEY_HINTS := "[ESC] WEG"
const PAD_HINTS := "[D-PAD] KIES   [A] GEBRUIK   [B] WEG"
## The headings of the panel bottom left.
const TRAY_HEADING := "Uit de automaat"
const POCKETS_HEADING := "Je zakken"
## You as you stand at the machine when the player does not say: how big, with a coat.
const STAND_IN_SCALE := 0.78
const STAND_IN_COAT := true
## The backdrop when a machine names none (or one that is not there).
const DEFAULT_BACKDROP := "straat"
## The tiles of the town each backdrop is made of (the library, the item): the wall behind
## the machine and the ground before it; "derrek" becomes "alfred_steyhn" in an ALFRED
## STEYHN (backdrop_tiles).
const BACKDROP_TILES := {
	"straat": {"wall": ["gebouwen", "klassiek_rood/klassiek_rood_blok_dicht"], "ground": ["grond", "stoep/stoep_vol"]},
	"supermarkt": {"wall": ["binnen", "supermarkt/muur_derrek"], "ground": ["binnen", "supermarkt/vloer_derrek"]},
	"station": {"wall": ["binnen", "station/wand"], "ground": ["binnen", "station/vloer"]},
}
## A point that is not on the picture of the screen.
const OFF_PICTURE := Vector2(-1, -1)
## The cursor goes on only to what is at least this far that way (metres).
const LEAST_ALONG := 0.001
## Going on, a step to the side counts this much more than a step straight on.
const ASIDE_WEIGHT := 2.0


# ------------------------------------------------------------------ what it says

## The heading of the tray: with the place the machine stands in, when it has one.
static func tray_heading(place_name: String) -> String:
	return TRAY_HEADING + ("  ·  " + place_name if place_name != "" else "")


## The line of your money in the panel.
static func money_line(money: float) -> String:
	return "GELD  " + MoneyText.euros(money)


## What the panel lists of your pockets at a plain machine: [text, tone] each.
static func pocket_lines(money: float) -> Array:
	return [[money_line(money), TONE_TEXT]]


## The line along the bottom: `pad_hints` with a controller connected, else `key_hints`.
static func hints(pad_connected: bool, key_hints: String, pad_hints: String) -> String:
	return pad_hints if pad_connected else key_hints


## Whether the tray shows: something came out (a title or lines).
static func tray_shows(title: String, lines: Array) -> bool:
	return title != "" or not lines.is_empty()


## Whether something slides out of the slot in the scene: only with a title.
static func slip_shows(title: String) -> bool:
	return title != ""


## The lines of the display as its one text.
static func display_text(lines: Array) -> String:
	return "\n".join(lines)


# ------------------------------------------------------------------ the backdrop

## The backdrop there is for `backdrop`: itself, or the street when it is not known.
static func known_backdrop(backdrop: String) -> String:
	return backdrop if BACKDROP_TILES.has(backdrop) else DEFAULT_BACKDROP


## The tiles behind a machine in `place_name` with `backdrop`: {"wall": [library, item],
## "ground": [library, item]}; in an ALFRED STEYHN the tiles of that chain.
static func backdrop_tiles(backdrop: String, place_name: String) -> Dictionary:
	var tiles: Dictionary = BACKDROP_TILES[known_backdrop(backdrop)]
	var chosen := {}
	for part: String in tiles:
		var item_name := String(tiles[part][1])
		if place_name.to_upper().contains("ALFRED"):
			item_name = item_name.replace("derrek", "alfred_steyhn")
		chosen[part] = [String(tiles[part][0]), item_name]
	return chosen


# ------------------------------------------------------------------ the cursor

## The spot of the point `uv` (0..1, y down) of the screen's picture in the plane of the
## machine's front (metres, y up), `screen` being the screen on that front.
static func screen_spot(uv: Vector2, screen: Rect2) -> Vector2:
	return Vector2(screen.position.x + uv.x * screen.size.x, screen.position.y + screen.size.y - uv.y * screen.size.y)


## What the cursor can be on: every button (`buttons`: {"button", "uv": its middle in the
## picture, 0..1} each) and every part (`hotspots`: {"name", "rect"} each), each with its
## spot "at" in the plane of the machine's front (metres, y up); the buttons first.
static func cursor_targets(buttons: Array, hotspots: Array, screen: Rect2) -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	for found: Dictionary in buttons:
		targets.append({"button": found.button, "at": screen_spot(found.uv, screen)})
	for hotspot: Dictionary in hotspots:
		targets.append({"hotspot": String(hotspot.name), "at": (hotspot.rect as Rect2).get_center()})
	return targets


## The target (cursor_targets: each with its spot "at" in the plane of the front, y up) nearest
## to `from` in `direction` (as on the screen: Vector2.DOWN is down); {} when there is none
## that way.
static func nearest_target(targets: Array[Dictionary], from: Vector2, direction: Vector2) -> Dictionary:
	var way := Vector2(direction.x, -direction.y)   # the plane of the front has y up
	var best := {}
	var best_score := INF
	for target in targets:
		var offset: Vector2 = (target.at as Vector2) - from
		var along := offset.dot(way)
		if along <= LEAST_ALONG:
			continue
		# straight on counts more than to the side
		var score := along + ASIDE_WEIGHT * absf(offset.dot(Vector2(-way.y, way.x)))
		if score < best_score:
			best_score = score
			best = target
	return best


## The target closest to `from` whatever the way (the first of equals); {} without targets.
static func closest_target(targets: Array[Dictionary], from: Vector2) -> Dictionary:
	if targets.is_empty():
		return {}
	var closest: Dictionary = targets[0]
	for target in targets:
		if (target.at as Vector2).distance_to(from) < (closest.at as Vector2).distance_to(from):
			closest = target
	return closest


## The one of `targets` the cursor is on (`cursor`: {"button": ...} or {"hotspot": name}): the
## same button, or the part of that name; {} when it is on none of them (or hidden).
static func matching_target(targets: Array[Dictionary], cursor: Dictionary) -> Dictionary:
	if cursor.is_empty():
		return {}
	for target in targets:
		if (target.has("button") and cursor.has("button") and target.button == cursor.button) \
				or (target.has("hotspot") and String(target.hotspot) == String(cursor.get("hotspot", ""))):
			return target
	return {}


# ------------------------------------------------------------------ the mouse

## Where the ray from `origin` going `way` meets the plane at `z`; null when it does not
## (along the plane, or the plane behind it).
static func ray_to_plane(origin: Vector3, way: Vector3, z: float) -> Variant:
	if absf(way.z) < 0.0001:
		return null
	var along := (z - origin.z) / way.z
	return origin + way * along if along > 0.0 else null


## Where the point `local` (the model's space, metres) is on the glass of `screen` (0..1, y
## down; outside that: beside the screen).
static func screen_uv(local: Vector3, screen: Rect2) -> Vector2:
	return Vector2((local.x - screen.position.x) / screen.size.x, (screen.position.y + screen.size.y - local.y) / screen.size.y)


## Where the point `uv` of the screen's glass (0..1) is in its picture (0..1), with the bulge
## of the glass (`curvature`, as machine_display.gdshader bends it): the middle stays, the
## edges move outwards (outside 0..1: off the picture).
static func bulged_uv(uv: Vector2, curvature: float) -> Vector2:
	var centred := uv * 2.0 - Vector2.ONE
	var bent := centred * (Vector2.ONE + curvature * Vector2(centred.y * centred.y, centred.x * centred.x))
	return bent * 0.5 + Vector2(0.5, 0.5)


## Whether `uv` is on the screen (0..1 both ways).
static func on_picture(uv: Vector2) -> bool:
	return uv.x >= 0.0 and uv.y >= 0.0 and uv.x <= 1.0 and uv.y <= 1.0


## The pixel of the screen's picture (`picture_size` px) under the point `local` of the
## model's space, the bulge of its glass taken into account; OFF_PICTURE when it is not on it.
static func picture_point(local: Vector3, screen: Rect2, curvature: float, picture_size: Vector2) -> Vector2:
	var uv := screen_uv(local, screen)
	if not on_picture(uv):
		return OFF_PICTURE
	var picture_uv := bulged_uv(uv, curvature)
	if not on_picture(picture_uv):
		return OFF_PICTURE
	return picture_uv * picture_size


## The name of the part of the machine (`hotspots`: {"name", "rect"} each) at `point` on
## its front (metres), or "".
static func hotspot_at(hotspots: Array, point: Vector2) -> String:
	for hotspot: Dictionary in hotspots:
		if (hotspot.rect as Rect2).has_point(point):
			return String(hotspot.name)
	return ""


## The rectangle of the part called `hotspot_name` on the machine's front; null: no such part.
static func hotspot_rect(hotspots: Array, hotspot_name: String) -> Variant:
	for hotspot: Dictionary in hotspots:
		if String(hotspot.name) == hotspot_name:
			return hotspot.rect as Rect2
	return null


## Whether the mouse shows a hand: over the screen when it has buttons, or over a part.
static func shows_hand(on_screen: bool, has_controls: bool, hotspot: String) -> bool:
	return (on_screen and has_controls) or hotspot != ""


# ------------------------------------------------------------------ the options

## Whether option `index` can be chosen: there is such a choice and a button showing it.
static func option_usable(index: int, choice_count: int, button_count: int) -> bool:
	return index >= 0 and index < choice_count and index < button_count
