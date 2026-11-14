extends Control
## The player frame of the HUD (the node "Speler", top left; behaviour, docs/CODE_LAGEN.md):
## what the game tells it about the player (set_stat, set_xp, set_player) it keeps, works
## out with stat_rules.gd and hands to its picture (player_frame_view.gd: portrait, name,
## the stat bars, the experience); it decides when the value of a stat lights up (a jump).
##   const PlayerFrame = preload("res://scripts/ui/hud/player_frame.gd")

const StatRules = preload("res://scripts/ui/hud/stat_rules.gd")
const PlayerFrameView = preload("res://scripts/ui/hud/player_frame_view.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")

## Its picture.
var view: PlayerFrameView

var _stat_values := {}       # stat name -> Vector2(value, maximum)


func _init() -> void:
	name = "Speler"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	view = PlayerFrameView.new()
	view.portrait.archetype_id = PlayerCharacter.current_id()
	add_child(view)
	view.show_experience(0.0, StatRules.experience_text(Vector2.ZERO))
	view.show_player("", StatRules.level_text(1))


## Sets a stat (StatLook.STATS): the bar fills to value / maximum; maximum < 0 keeps the
## last one. A jump (StatRules.is_jump) lights its value up; the first time is no change.
func set_stat(stat_name: String, value: float, maximum := -1.0) -> void:
	if not view.has_stat(stat_name):
		push_warning("hud: unknown stat '%s'" % stat_name)
		return
	var known := _stat_values.has(stat_name)
	var previous: Vector2 = _stat_values.get(stat_name, Vector2(0.0, StatRules.DEFAULT_MAXIMUM))
	var stat := StatRules.clamped(value, maximum, previous.y)
	_stat_values[stat_name] = stat
	if known and StatRules.is_jump(previous.x, stat.x):
		view.flash_stat(stat_name, stat.x > previous.x)
	view.show_stat(stat_name, StatRules.fill(stat), StatRules.value_text(stat))


## The value and maximum of a stat (Vector2); zero when it was never set.
func get_stat(stat_name: String) -> Vector2:
	return _stat_values.get(stat_name, Vector2.ZERO)


## The experience: points so far within this level and the points the level takes; the
## bar fills to their share.
func set_xp(points: float, points_for_level: float) -> void:
	var experience := StatRules.experience(points, points_for_level)
	view.show_experience(StatRules.fill(experience), StatRules.experience_text(experience))


## The name of the player and its level on the badge.
func set_player(player_name: String, level: int) -> void:
	view.show_player(player_name, StatRules.level_text(level))
