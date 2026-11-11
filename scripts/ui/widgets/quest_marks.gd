extends Control
## The places a quest sends the player to (GameHud.quest_targets: the tracked quest's step
## under way), on the minimap of the HUD: an amber diamond with an ink rim where each one is;
## one off the minimap sits on its edge as an arrow with a tail pointing the way. The big map of the game
## menu draws the same diamond (draw_mark).
##   marks.points = [Vector2(120, 40)]   # in this control's pixels
## `colour` sets another colour (the exits of an interior on the minimap).

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const PlayerArrow = preload("res://scripts/ui/widgets/player_arrow.gd")
const COLOUR := Color("#FFB830")
## Half the size of the diamond, and how far from the edge an arrow for a far place sits (px).
const MARK_SIZE := 6.0
const EDGE_INSET := 9.0

var colour := COLOUR

## Where the places are, in this control's pixels (any of them may be outside it).
var points: Array = []:
	set(value):
		points = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if not points.is_empty():
		queue_redraw()   # the pulse


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 4.0)
	var middle := size * 0.5
	var inner := Rect2(Vector2.ONE * EDGE_INSET, size - Vector2.ONE * EDGE_INSET * 2.0)
	for point: Vector2 in points:
		if inner.has_point(point):
			draw_mark(self, point.round(), MARK_SIZE, pulse, colour)
			continue
		# off the minimap: on its edge, pointing from the middle towards it
		var way := (point - middle)
		if way.length_squared() < 0.0001:
			continue
		var reach := minf(absf(inner.size.x * 0.5 / way.x) if way.x != 0.0 else INF,
				absf(inner.size.y * 0.5 / way.y) if way.y != 0.0 else INF)
		var at := (middle + way * reach).round()
		_draw_arrow(at, way.normalized(), pulse)


## The diamond of a quest place at `at` on `canvas`, `half` px from its middle to a corner;
## `pulse` (0..1) lights it up and down a little.
static func draw_mark(canvas: CanvasItem, at: Vector2, half: float, pulse := 1.0, fill := COLOUR) -> void:
	var rim := half + 3.0
	canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -rim), at + Vector2(rim, 0), at + Vector2(0, rim), at + Vector2(-rim, 0)]), UiStyle.INK)
	var lit := fill.lerp(Color.WHITE, 0.35 * pulse)
	canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -half), at + Vector2(half, 0), at + Vector2(0, half), at + Vector2(-half, 0)]), lit)


func _draw_arrow(at: Vector2, way: Vector2, pulse: float) -> void:
	var lit := colour.lerp(Color.WHITE, 0.35 * pulse)
	draw_colored_polygon(PlayerArrow.shape(at + way * 9.0, way, 19.0, 12.0, 9.0, 4.0), UiStyle.INK)
	draw_colored_polygon(PlayerArrow.shape(at + way * 6.0, way, 14.0, 8.0, 6.0, 2.0), lit)
