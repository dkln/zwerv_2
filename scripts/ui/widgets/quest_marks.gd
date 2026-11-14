extends Control
## The places a quest sends the player to (GameHud.quest_targets: the tracked quest's step
## under way), on the minimap of the HUD: an amber diamond with an ink rim where each one is;
## one off the minimap sits on its edge as an arrow with a tail pointing the way. The big map of the game
## menu draws the same diamond (draw_mark). Graphics (docs/CODE_LAGEN.md): a picture on its
## own, nothing to decide; where the marks stand comes from quest_marks_layout.gd.
##   const QuestMarks = preload("res://scripts/ui/widgets/quest_marks.gd")
##   marks.points = [Vector2(120, 40)]   # in this control's pixels
## `colour` sets another colour (the exits of an interior on the minimap).

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const QuestMarksLayout = preload("res://scripts/ui/widgets/quest_marks_layout.gd")
const PlayerArrowLayout = preload("res://scripts/ui/widgets/player_arrow_layout.gd")
const COLOUR := Color("#FFB830")
## How much of the way to white a mark lights up at the top of its pulse, and how fast it pulses.
const PULSE_LIGHT := 0.35
const PULSE_SPEED := 4.0

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
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * PULSE_SPEED)
	for point: Vector2 in points:
		if QuestMarksLayout.is_on_map(point, size):
			draw_mark(self, point.round(), QuestMarksLayout.MARK_SIZE, pulse, colour)
		elif QuestMarksLayout.has_way(point, size):
			# off the minimap: on its edge, pointing from the middle towards it
			_draw_arrow(QuestMarksLayout.edge_place(point, size), QuestMarksLayout.way_to(point, size), pulse)


## The diamond of a quest place at `at` on `canvas`, `half` px from its middle to a corner;
## `pulse` (0..1) lights it up and down a little.
static func draw_mark(canvas: CanvasItem, at: Vector2, half: float, pulse := 1.0, fill := COLOUR) -> void:
	canvas.draw_colored_polygon(QuestMarksLayout.diamond(at, half + QuestMarksLayout.RIM), UiStyle.INK)
	canvas.draw_colored_polygon(QuestMarksLayout.diamond(at, half), fill.lerp(Color.WHITE, PULSE_LIGHT * pulse))


func _draw_arrow(at: Vector2, way: Vector2, pulse: float) -> void:
	draw_colored_polygon(_arrow(at, way, QuestMarksLayout.ARROW_OUTLINE), UiStyle.INK)
	draw_colored_polygon(_arrow(at, way, QuestMarksLayout.ARROW_INSIDE), colour.lerp(Color.WHITE, PULSE_LIGHT * pulse))


static func _arrow(at: Vector2, way: Vector2, measures: Array) -> PackedVector2Array:
	return PlayerArrowLayout.shape(at + way * measures[0], way, measures[1], measures[2], measures[3], measures[4])
