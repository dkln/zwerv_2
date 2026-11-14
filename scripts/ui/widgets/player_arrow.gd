extends Control
## The player on the minimap: a white arrow with a tail (like "->"), pointing up (north) when
## unturned, with an ink outline, turned round its middle. shape() gives the same arrow to
## the other arrows on the maps (quest_marks.gd: a far place on the minimap's edge). Graphics
## (docs/CODE_LAGEN.md): a picture on its own, nothing to decide; its shape comes from
## player_arrow_layout.gd.
##   const PlayerArrow = preload("res://scripts/ui/widgets/player_arrow.gd")

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const PlayerArrowLayout = preload("res://scripts/ui/widgets/player_arrow_layout.gd")


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw_colored_polygon(PlayerArrowLayout.upward(PlayerArrowLayout.OUTLINE), UiStyle.INK)
	draw_colored_polygon(PlayerArrowLayout.upward(PlayerArrowLayout.INSIDE), Color.WHITE)


## An arrow with a tail (PlayerArrowLayout.shape): its tip at `tip` pointing `way`.
static func shape(tip: Vector2, way: Vector2, length: float, head_length: float, head_half: float, tail_half: float) -> PackedVector2Array:
	return PlayerArrowLayout.shape(tip, way, length, head_length, head_half, tail_half)
