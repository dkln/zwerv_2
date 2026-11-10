extends OmniLight3D
## A soft warm light over the player (the node "Nachtlicht" on Speler), so the figure can be
## made out in the dark: it comes up as the day cycle's night does (DayCycle.night, from the
## node `day_cycle_path`) and is off by day. It lights the figure and a small round of street
## round it, without shadows (it would be the only light casting the figure's shadow up).

## The day cycle (Dagcyclus) whose `night` (0 = day .. 1 = night) it follows.
@export var day_cycle_path := NodePath("../../Dagcyclus")
## Brightest (at full night) and the share of it from dusk on (night > 0).
@export var brightest := 1.1
## Metres above the feet (over the head, so the face and shoulders catch it).
@export var height := 2.4

var _day_cycle: Node


func _ready() -> void:
	_day_cycle = get_node_or_null(day_cycle_path)
	position = Vector3.UP * height
	light_color = Color(1.0, 0.86, 0.68)
	omni_range = 4.5
	omni_attenuation = 1.4
	shadow_enabled = false
	light_specular = 0.2
	_follow_night()


func _process(_delta: float) -> void:
	_follow_night()


func _follow_night() -> void:
	var night := float(_day_cycle.get("night")) if _day_cycle else 0.0
	light_energy = brightest * smoothstep(0.0, 1.0, clampf(night, 0.0, 1.0))
	visible = light_energy > 0.01
