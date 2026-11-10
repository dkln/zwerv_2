extends Decal
## A soft dark patch on the ground right under a figure (the player, the pedestrians), so it
## stands apart from the street round it from every side: unlike a line round it, it looks the
## same however the figure turns. A Decal (it follows kerbs and steps) with a round soft
## gradient; it darkens what lies under it, so it is as strong by night as by day. It does not
## fall on the figures themselves: they are drawn on FIGURE_LAYER, which it leaves out.

## The visual layer (bit value) the figures are drawn on.
const FIGURE_LAYER := 2
## Width across (m), how dark in its middle, how far it reaches up and down from the feet.
const WIDTH := 1.0
const DARKNESS := 0.55
const REACH := 0.45

static var _texture: GradientTexture2D


func _init() -> void:
	name = "Grondschaduw"
	size = Vector3(WIDTH, REACH * 2.0, WIDTH)
	texture_albedo = _soft_round()
	modulate = Color(1.0, 1.0, 1.0, DARKNESS)
	albedo_mix = 1.0
	upper_fade = 0.3
	lower_fade = 0.3
	cull_mask = 0xFFFFF & ~FIGURE_LAYER
	distance_fade_enabled = true
	distance_fade_begin = 120.0
	distance_fade_length = 40.0


static func _soft_round() -> GradientTexture2D:
	if _texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(0.02, 0.02, 0.04, 1.0))
		gradient.set_color(1, Color(0.02, 0.02, 0.04, 0.0))
		gradient.add_point(0.45, Color(0.02, 0.02, 0.04, 0.6))
		_texture = GradientTexture2D.new()
		_texture.gradient = gradient
		_texture.fill = GradientTexture2D.FILL_RADIAL
		_texture.fill_from = Vector2(0.5, 0.5)
		_texture.fill_to = Vector2(1.0, 0.5)
		_texture.width = 64
		_texture.height = 64
	return _texture
