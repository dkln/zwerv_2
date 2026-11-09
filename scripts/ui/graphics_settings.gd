extends RefCounted
## The graphics settings of the settings menu (main menu, INSTELLINGEN), kept in the settings
## file of the main menu (MainMenu.SETTINGS_PATH, section "beeld") and put on the window's
## viewport, where they hold for every scene after (apply() at the start: intro, main menu).
## - anti-aliasing (ANTI_ALIASING): UIT, FXAA (cheap, a little soft), MSAA 2x/4x/8x (sharp
##   edges, costs more the higher), TAA (smooth, a little soft when moving);
## - render scale (RENDER_SCALES): the share of the window's pixels the 3D world is drawn at
##   and scaled up (lower = faster, softer); at 100 % it is drawn at full size, below that with
##   the project's upscaler (FSR 2, on a Mac MetalFX), or FSR 1 with MSAA (the temporal
##   upscalers do their own anti-aliasing and do not go with MSAA).
## The interface is not touched by either: it is always drawn at full size.

const SETTINGS_PATH := "user://instellingen.cfg"
const ANTI_ALIASING := ["UIT", "FXAA", "MSAA 2X", "MSAA 4X", "MSAA 8X", "TAA"]
## By default sharp: MSAA (FXAA and TAA soften the whole picture a little), at full size.
const DEFAULT_ANTI_ALIASING := "MSAA 2X"
const RENDER_SCALES := [0.5, 0.67, 0.75, 0.85, 1.0]
const DEFAULT_RENDER_SCALE := 1.0


static func anti_aliasing() -> String:
	var value := String(_config().get_value("beeld", "anti_aliasing", DEFAULT_ANTI_ALIASING))
	return value if value in ANTI_ALIASING else DEFAULT_ANTI_ALIASING


static func render_scale() -> float:
	return float(_config().get_value("beeld", "renderschaal", DEFAULT_RENDER_SCALE))


## The next anti-aliasing setting (going round), stored and applied.
static func next_anti_aliasing(tree: SceneTree) -> void:
	var index := ANTI_ALIASING.find(anti_aliasing())
	_store("anti_aliasing", ANTI_ALIASING[(index + 1) % ANTI_ALIASING.size()])
	apply(tree)


## The next render scale (going round), stored and applied.
static func next_render_scale(tree: SceneTree) -> void:
	var index := 0
	for scale_index in RENDER_SCALES.size():
		if absf(RENDER_SCALES[scale_index] - render_scale()) < 0.01:
			index = scale_index
	_store("renderschaal", RENDER_SCALES[(index + 1) % RENDER_SCALES.size()])
	apply(tree)


## "RENDERSCHAAL: 85%".
static func render_scale_text() -> String:
	return "%d%%" % roundi(render_scale() * 100.0)


## Puts the stored settings on the window's viewport.
static func apply(tree: SceneTree) -> void:
	var viewport := tree.root
	var mode := anti_aliasing()
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if mode == "FXAA" else Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.use_taa = mode == "TAA"
	match mode:
		"MSAA 2X":
			viewport.msaa_3d = Viewport.MSAA_2X
		"MSAA 4X":
			viewport.msaa_3d = Viewport.MSAA_4X
		"MSAA 8X":
			viewport.msaa_3d = Viewport.MSAA_8X
		_:
			viewport.msaa_3d = Viewport.MSAA_DISABLED
	var scale := clampf(render_scale(), 0.25, 1.0)
	viewport.scaling_3d_scale = scale
	if scale >= 0.999:
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	elif mode.begins_with("MSAA"):
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
	else:
		viewport.scaling_3d_mode = int(ProjectSettings.get_setting_with_override("rendering/scaling_3d/mode")) as Viewport.Scaling3DMode


static func _config() -> ConfigFile:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	return config


static func _store(key: String, value: Variant) -> void:
	var config := _config()
	config.set_value("beeld", key, value)
	config.save(SETTINGS_PATH)
