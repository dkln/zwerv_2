@tool
class_name TintKaart
extends Node3D
## Kleur/tint van tiles aanpassen zonder de .vox te wijzigen.
##
## Zet TintVlak-nodes als kind van deze node en schuif ze over gebouwen of grond:
## alles binnen het vlak krijgt die tint (werkt live in de editor).
## "variatie" geeft elke 4x4 m cel automatisch een iets andere kleur.

@export var gebied_start := Vector2(0, 0)            ## wereldpositie (x, z) van de hoek van de kaart
@export var gebied_cellen := Vector2i(96, 80)        ## aantal cellen van 4 m
@export_range(0.0, 1.0) var variatie := 0.25:
	set(v):
		variatie = v
		_dirty = true

var _dirty := true
var _tijd := 0.0
var _tex: ImageTexture


func _ready() -> void:
	_bake()


func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	_tijd += delta
	if _tijd > 0.25 or _dirty:
		_tijd = 0.0
		_dirty = false
		_bake()


func _bake() -> void:
	var w := maxi(1, gebied_cellen.x)
	var h := maxi(1, gebied_cellen.y)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.5, 0.5, 0.0))
	for c in get_children():
		if c is TintVlak and c.visible:
			var vlak: TintVlak = c
			var p := vlak.global_position
			var half := Vector2(vlak.grootte) * 2.0
			var col := Color(clampf(vlak.kleur.r * vlak.helderheid * 0.5, 0, 1),
				clampf(vlak.kleur.g * vlak.helderheid * 0.5, 0, 1),
				clampf(vlak.kleur.b * vlak.helderheid * 0.5, 0, 1), vlak.sterkte)
			for x in w:
				for z in h:
					var cx := gebied_start.x + (x + 0.5) * 4.0
					var cz := gebied_start.y + (z + 0.5) * 4.0
					if absf(cx - p.x) <= half.x and absf(cz - p.z) <= half.y:
						img.set_pixel(x, z, col)
	if _tex == null:
		_tex = ImageTexture.create_from_image(img)
	else:
		_tex.update(img)
	RenderingServer.global_shader_parameter_set("zwervr_tint_kaart", _tex)
	RenderingServer.global_shader_parameter_set("zwervr_tint_gebied", Vector4(gebied_start.x, gebied_start.y, w * 4.0, h * 4.0))
	RenderingServer.global_shader_parameter_set("zwervr_variatie", variatie)
