extends Control
## What the minimap of the HUD looks like (graphics; docs/CODE_LAGEN.md): a frame, in it
## the picture of the map (north up) with the shroud of the story over it, the marks (the
## places of the followed quest, the ways out of an interior, the marker set on the map)
## and the player arrow in the middle, and the N of north. It paints the pictures from the
## plain data minimap.gd hands it (map_image, shroud_image) and shows what it is told
## (show_map, place_map, show_shroud, turn_arrow, show_..._marks); it decides nothing. Its
## sizes come from minimap_layout.gd, its colours from map_look.gd.
##   const MinimapView = preload("res://scripts/ui/hud/minimap_view.gd")

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const MapLook = preload("res://scripts/ui/hud/map_look.gd")
const Layout = preload("res://scripts/ui/hud/minimap_layout.gd")
const PlayerArrow = preload("res://scripts/ui/widgets/player_arrow.gd")
const QuestMarks = preload("res://scripts/ui/widgets/quest_marks.gd")

var _map: TextureRect
var _shroud: TextureRect            # over the map: what the story has not opened yet
var _shroud_texture: ImageTexture
var _arrow: PlayerArrow
var _quest_marks: QuestMarks
var _exit_marks: QuestMarks
var _waypoint_marks: QuestMarks


func _init() -> void:
	name = "Beeld"
	size = Layout.frame_size()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := UiStyle.shadowed_panel(Layout.frame_size(), UiStyle.BORDER, Layout.BORDER)
	add_child(frame)
	var map_rect := Layout.map_rect()
	var clip := Control.new()
	clip.position = map_rect.position
	clip.size = map_rect.size
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(clip)
	_map = _picture()
	clip.add_child(_map)
	_shroud = _picture()
	_shroud.name = "Sluier"
	clip.add_child(_shroud)
	_quest_marks = _marks(QuestMarks.COLOUR, map_rect.size)
	clip.add_child(_quest_marks)
	_exit_marks = _marks(MapLook.EXIT_MARK_COLOUR, map_rect.size)
	clip.add_child(_exit_marks)
	_waypoint_marks = _marks(MapLook.WAYPOINT_COLOUR, map_rect.size)
	clip.add_child(_waypoint_marks)
	_arrow = PlayerArrow.new()
	_arrow.position = Layout.centre()
	clip.add_child(_arrow)
	var north := UiStyle.label("N", UiStyle.fonts().pixel_bold, 12, UiStyle.TEXT, 1)
	north.position = Layout.NORTH_POSITION
	frame.add_child(north)


## The picture of a map of `size` pixels: every pixel of `pixel_kinds` (Vector2i -> kind,
## MinimapRules.pixel_kinds) in the colour of its kind, the rest empty.
static func map_image(size: Vector2i, pixel_kinds: Dictionary) -> Image:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGB8)
	image.fill(MapLook.EMPTY)
	for pixel: Vector2i in pixel_kinds:
		image.set_pixelv(pixel, MapLook.GROUND_COLOURS[pixel_kinds[pixel]])
	return image


## The shroud over a map of `size` pixels: the `hidden` pixels (Vector2i each) in the
## colour of the empty map (opaque), the rest clear; null when nothing is hidden.
static func shroud_image(size: Vector2i, hidden: Array) -> Image:
	if hidden.is_empty():
		return null
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var colour := Color(MapLook.EMPTY, 1.0)
	for pixel: Vector2i in hidden:
		image.set_pixelv(pixel, colour)
	return image


## The picture of the map (the town, or the floor plan of an interior).
func show_map(texture: Texture2D) -> void:
	_map.texture = texture


func map_texture() -> Texture2D:
	return _map.texture


## The map drawn `map_size` big with its corner at `at`, the shroud with it.
func place_map(at: Vector2, map_size: Vector2) -> void:
	_map.size = map_size
	_map.position = at
	_shroud.size = map_size
	_shroud.position = at


## Where the map is drawn and how big.
func map_rect() -> Rect2:
	return Rect2(_map.position, _map.size)


## The shroud of the story (shroud_image; null: none).
func show_shroud(image: Image) -> void:
	if image == null:
		_shroud_texture = null
	elif _shroud_texture and Vector2i(_shroud_texture.get_size()) == image.get_size():
		_shroud_texture.update(image)
	else:
		_shroud_texture = ImageTexture.create_from_image(image)
	_shroud.texture = _shroud_texture


## The shroud over the map, or not (inside a building, or nothing shrouded).
func show_shroud_over_map(on: bool) -> void:
	_shroud.visible = on


func is_shroud_over_map() -> bool:
	return _shroud.visible and _shroud.texture != null


## Turns the player arrow (radians, 0 = north).
func turn_arrow(angle: float) -> void:
	_arrow.rotation = angle


func arrow_angle() -> float:
	return _arrow.rotation


## The places of the followed quest, in the pixels of the map.
func show_quest_marks(points: Array) -> void:
	_quest_marks.points = points


func quest_marks() -> Array:
	return _quest_marks.points


## The ways out of an interior.
func show_exit_marks(points: Array) -> void:
	_exit_marks.points = points


func exit_marks() -> Array:
	return _exit_marks.points


## The marker set on the map (none: an empty list).
func show_waypoint_marks(points: Array) -> void:
	_waypoint_marks.points = points


func waypoint_marks() -> Array:
	return _waypoint_marks.points


func _picture() -> TextureRect:
	var picture := TextureRect.new()
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return picture


func _marks(colour: Color, marks_size: Vector2) -> QuestMarks:
	var marks := QuestMarks.new()
	marks.colour = colour
	marks.size = marks_size
	return marks
