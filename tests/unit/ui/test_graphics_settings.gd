extends RefCounted
## Unit tests of the graphics settings (scripts/ui/graphics_settings.gd): what is stored, the
## defaults, going round the choices, what apply() puts on the window's viewport, plain_3d.
## The settings file and the viewport are put back as they were after every test.
##   tests/run_unit_tests.sh graphics_settings

const GraphicsSettings = preload("res://scripts/ui/graphics_settings.gd")

const VIEWPORT_PROPERTIES := ["screen_space_aa", "use_taa", "msaa_3d", "scaling_3d_scale", "scaling_3d_mode"]

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


## The settings file and the viewport as they are now, to put back with _restore.
func _remember() -> Dictionary:
	var remembered := {"had_file": FileAccess.file_exists(GraphicsSettings.SETTINGS_PATH), "bytes": PackedByteArray(), "viewport": {}}
	if remembered.had_file:
		remembered.bytes = FileAccess.get_file_as_bytes(GraphicsSettings.SETTINGS_PATH)
	for property: String in VIEWPORT_PROPERTIES:
		remembered.viewport[property] = tree.root.get(property)
	return remembered


func _restore(remembered: Dictionary) -> void:
	if remembered.had_file:
		var file := FileAccess.open(GraphicsSettings.SETTINGS_PATH, FileAccess.WRITE)
		file.store_buffer(remembered.bytes)
		file.close()
	else:
		DirAccess.remove_absolute(GraphicsSettings.SETTINGS_PATH)
	for property: String in VIEWPORT_PROPERTIES:
		tree.root.set(property, remembered.viewport[property])


## Stores `value` (null: takes the key out) in the section of the graphics settings.
static func _store(key: String, value: Variant) -> void:
	var config := ConfigFile.new()
	config.load(GraphicsSettings.SETTINGS_PATH)
	config.set_value("beeld", key, value)
	config.save(GraphicsSettings.SETTINGS_PATH)


func test_defaults_and_stored_values(test) -> void:
	var remembered := _remember()
	_store("anti_aliasing", null)
	_store("renderschaal", null)
	test.check(GraphicsSettings.anti_aliasing() == GraphicsSettings.DEFAULT_ANTI_ALIASING, "niets opgeslagen: MSAA 2X")
	test.check(GraphicsSettings.render_scale() == GraphicsSettings.DEFAULT_RENDER_SCALE and GraphicsSettings.render_scale_text() == "100%", "en volle maat")
	test.check(GraphicsSettings.ANTI_ALIASING.has(GraphicsSettings.DEFAULT_ANTI_ALIASING) and GraphicsSettings.RENDER_SCALES.has(GraphicsSettings.DEFAULT_RENDER_SCALE), "de standaarden zijn keuzes van het menu")
	_store("anti_aliasing", "TAA")
	_store("renderschaal", 0.67)
	test.check(GraphicsSettings.anti_aliasing() == "TAA", "wat opgeslagen is")
	test.check(is_equal_approx(GraphicsSettings.render_scale(), 0.67) and GraphicsSettings.render_scale_text() == "67%", "ook de renderschaal, als procenten")
	_store("anti_aliasing", "ONZIN")
	test.check(GraphicsSettings.anti_aliasing() == GraphicsSettings.DEFAULT_ANTI_ALIASING, "een onbekende waarde: de standaard")
	_restore(remembered)


func test_next_anti_aliasing_goes_round(test) -> void:
	var remembered := _remember()
	_store("anti_aliasing", GraphicsSettings.ANTI_ALIASING[0])
	var seen := [GraphicsSettings.anti_aliasing()]
	for step in GraphicsSettings.ANTI_ALIASING.size() - 1:
		GraphicsSettings.next_anti_aliasing(tree)
		seen.append(GraphicsSettings.anti_aliasing())
	test.check(seen == GraphicsSettings.ANTI_ALIASING, "alle keuzes op volgorde (%s)" % [seen])
	GraphicsSettings.next_anti_aliasing(tree)
	test.check(GraphicsSettings.anti_aliasing() == GraphicsSettings.ANTI_ALIASING[0], "na de laatste weer de eerste")
	_restore(remembered)


func test_next_render_scale_goes_round(test) -> void:
	var remembered := _remember()
	_store("renderschaal", GraphicsSettings.RENDER_SCALES[0])
	var seen := [GraphicsSettings.render_scale()]
	for step in GraphicsSettings.RENDER_SCALES.size() - 1:
		GraphicsSettings.next_render_scale(tree)
		seen.append(GraphicsSettings.render_scale())
	test.check(seen == GraphicsSettings.RENDER_SCALES, "alle schalen op volgorde (%s)" % [seen])
	test.check(is_equal_approx(tree.root.scaling_3d_scale, 1.0), "en meteen op het beeld gezet")
	GraphicsSettings.next_render_scale(tree)
	test.check(is_equal_approx(GraphicsSettings.render_scale(), GraphicsSettings.RENDER_SCALES[0]) and GraphicsSettings.render_scale_text() == "50%", "na de laatste weer de eerste")
	test.check(is_equal_approx(tree.root.scaling_3d_scale, 0.5), "ook die meteen op het beeld")
	_store("renderschaal", 0.6)
	GraphicsSettings.next_render_scale(tree)
	test.check(is_equal_approx(GraphicsSettings.render_scale(), GraphicsSettings.RENDER_SCALES[1]), "een schaal die geen keuze is: verder vanaf de eerste")
	_restore(remembered)


func test_apply_sets_the_anti_aliasing_on_the_viewport(test) -> void:
	var remembered := _remember()
	var viewport := tree.root
	_store("renderschaal", 1.0)
	_store("anti_aliasing", "FXAA")
	GraphicsSettings.apply(tree)
	test.check(viewport.screen_space_aa == Viewport.SCREEN_SPACE_AA_FXAA and viewport.msaa_3d == Viewport.MSAA_DISABLED and not viewport.use_taa, "FXAA: alleen dat")
	for pair: Array in [["MSAA 2X", Viewport.MSAA_2X], ["MSAA 4X", Viewport.MSAA_4X], ["MSAA 8X", Viewport.MSAA_8X]]:
		_store("anti_aliasing", pair[0])
		GraphicsSettings.apply(tree)
		test.check(viewport.msaa_3d == pair[1] and viewport.screen_space_aa == Viewport.SCREEN_SPACE_AA_DISABLED and not viewport.use_taa, "%s: alleen dat" % pair[0])
	_store("anti_aliasing", "TAA")
	GraphicsSettings.apply(tree)
	test.check(viewport.use_taa and viewport.msaa_3d == Viewport.MSAA_DISABLED and viewport.screen_space_aa == Viewport.SCREEN_SPACE_AA_DISABLED, "TAA: alleen dat")
	_store("anti_aliasing", "UIT")
	GraphicsSettings.apply(tree)
	test.check(not viewport.use_taa and viewport.msaa_3d == Viewport.MSAA_DISABLED and viewport.screen_space_aa == Viewport.SCREEN_SPACE_AA_DISABLED, "UIT: niets")
	_restore(remembered)


func test_apply_sets_the_render_scale_and_its_upscaler(test) -> void:
	var remembered := _remember()
	var viewport := tree.root
	_store("anti_aliasing", "MSAA 4X")
	_store("renderschaal", 1.0)
	GraphicsSettings.apply(tree)
	test.check(is_equal_approx(viewport.scaling_3d_scale, 1.0) and viewport.scaling_3d_mode == Viewport.SCALING_3D_MODE_BILINEAR, "volle maat: zonder upscaler")
	_store("renderschaal", 0.75)
	GraphicsSettings.apply(tree)
	test.check(is_equal_approx(viewport.scaling_3d_scale, 0.75) and viewport.scaling_3d_mode == Viewport.SCALING_3D_MODE_FSR, "kleiner met MSAA: FSR 1")
	_store("anti_aliasing", "TAA")
	GraphicsSettings.apply(tree)
	var project_mode := int(ProjectSettings.get_setting_with_override("rendering/scaling_3d/mode"))
	test.check(viewport.scaling_3d_mode == project_mode, "kleiner zonder MSAA: de upscaler van het project (%d)" % viewport.scaling_3d_mode)
	var temporal := project_mode in [Viewport.SCALING_3D_MODE_FSR2, Viewport.SCALING_3D_MODE_METALFX_TEMPORAL]
	test.check(viewport.use_taa == (not temporal), "TAA alleen als de upscaler het niet zelf doet")
	_store("renderschaal", 0.1)
	GraphicsSettings.apply(tree)
	test.check(is_equal_approx(viewport.scaling_3d_scale, 0.25), "nooit kleiner dan een kwart")
	_store("renderschaal", 3.0)
	GraphicsSettings.apply(tree)
	test.check(is_equal_approx(viewport.scaling_3d_scale, 1.0) and viewport.scaling_3d_mode == Viewport.SCALING_3D_MODE_BILINEAR, "en nooit groter dan volle maat")
	_restore(remembered)


func test_plain_3d_keeps_a_picture_at_full_size(test) -> void:
	var viewport := SubViewport.new()
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
	viewport.scaling_3d_scale = 0.5
	viewport.use_taa = true
	GraphicsSettings.plain_3d(viewport)
	test.check(viewport.scaling_3d_mode == Viewport.SCALING_3D_MODE_BILINEAR and viewport.scaling_3d_scale == 1.0, "volle maat, zonder upscaler")
	test.check(not viewport.use_taa, "en zonder TAA")
	viewport.free()
