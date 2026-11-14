extends Node3D
## The big arrow bobbing over something you can use (a way in, someone who sells;
## behaviour, docs/CODE_LAGEN.md): a flat "->" arrow pointing down at it, always facing the
## camera (its picture: interaction_mark_view.gd). It shows only when the player is within
## MARK_FROM and bobs between `bottom` and `top` (the height of its point):
## interaction_mark_rules.gd.
##   const InteractionMark = preload("res://scripts/world/things/interaction_mark.gd")
##   var mark := InteractionMark.create(2.5, 3.3)
##   door.add_child(mark)
##   mark.follow(player)        # every frame

const InteractionMark = preload("res://scripts/world/things/interaction_mark.gd")
const InteractionMarkRules = preload("res://scripts/world/things/interaction_mark_rules.gd")
const InteractionMarkView = preload("res://scripts/world/things/interaction_mark_view.gd")

## From how far the arrow shows (metres; the rules').
const MARK_FROM := InteractionMarkRules.MARK_FROM

var bottom := 2.5
var top := 3.3
## Its picture.
var view: Node3D
var _clock := 0.0


## An arrow bobbing between `low` and `high` over its parent (its point at those heights).
static func create(low: float, high: float, through_walls := true) -> InteractionMark:
	var mark := InteractionMark.new()
	mark.name = "Aanwijzer"
	mark.bottom = low
	mark.top = high
	mark.view = InteractionMarkView.create(through_walls)
	mark.add_child(mark.view)
	return mark


## Shows it when `player` is near (and `allowed`), and moves it along: call every frame.
func follow(player: Node3D, allowed := true) -> void:
	var present := player != null and is_inside_tree()
	var distance := player.global_position.distance_to(global_position) if present else INF
	if not InteractionMarkRules.shows(allowed, present, distance):
		view.call("show_hidden")
		return
	_clock += get_process_delta_time()
	view.call("show_at", InteractionMarkRules.height(bottom, top, _clock))
