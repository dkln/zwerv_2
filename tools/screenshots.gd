extends SceneTree
## Maakt isometrische screenshots van alle situaties in de voorbeeldkaart,
## met titel en uitleg in het beeld, plus docs/screenshots/index.json.
## gebruik: Godot --script tools/screenshots.gd

const UIT := "res://docs/screenshots"

const Data = preload("res://scripts/rondleiding_data.gd")

var _items := []


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(UIT))
	var sc: Node = load("res://scenes/wereld.tscn").instantiate()
	var cam: Camera3D = sc.get_node("Camera")
	cam.set_script(null)
	if sc.has_node("Rondleiding"):
		sc.get_node("Rondleiding").set("actief", false)
	get_root().add_child(sc)
	get_root().size = Vector2i(1600, 900)
	var laag := CanvasLayer.new()
	get_root().add_child(laag)
	var paneel := PanelContainer.new()
	var stijl := StyleBoxFlat.new()
	stijl.bg_color = Color(0.08, 0.1, 0.13, 0.78)
	stijl.set_corner_radius_all(10)
	stijl.content_margin_left = 22
	stijl.content_margin_right = 22
	stijl.content_margin_top = 14
	stijl.content_margin_bottom = 16
	paneel.add_theme_stylebox_override("panel", stijl)
	paneel.position = Vector2(28, 28)
	paneel.custom_minimum_size = Vector2(620, 0)
	laag.add_child(paneel)
	var vb := VBoxContainer.new()
	paneel.add_child(vb)
	var titel := Label.new()
	titel.add_theme_font_size_override("font_size", 34)
	var vet := FontVariation.new()
	vet.base_font = load("res://assets/fonts/Rubik.ttf")
	vet.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 650}
	titel.add_theme_font_override("font", vet)
	titel.add_theme_color_override("font_color", Color(1, 1, 1))
	vb.add_child(titel)
	var tekst := Label.new()
	tekst.add_theme_font_size_override("font_size", 19)
	tekst.add_theme_color_override("font_color", Color(0.86, 0.9, 0.95))
	tekst.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tekst.custom_minimum_size = Vector2(620, 0)
	vb.add_child(tekst)
	await process_frame

	var lijst := Data.stops(sc)

	var nr := 1
	for it in lijst:
		titel.text = it["titel"]
		tekst.text = it["tekst"]
		var focus := Vector3(it["x"], 0, it["z"])
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = it["grootte"]
		cam.near = 1.0
		cam.far = 4000.0
		cam.rotation_degrees = Vector3(-35.264, 45, 0)
		cam.global_position = focus + Vector3(1, 1, 1).normalized() * 300.0
		for i in 10:
			await process_frame
		var bestand := "%02d_%s.png" % [nr, it["slug"]]
		get_root().get_texture().get_image().save_png(ProjectSettings.globalize_path(UIT.path_join(bestand)))
		_items.append({"bestand": bestand, "titel": it["titel"], "tekst": it["tekst"]})
		nr += 1
	var f := FileAccess.open(ProjectSettings.globalize_path(UIT.path_join("index.json")), FileAccess.WRITE)
	f.store_string(JSON.stringify(_items, "  "))
	f.close()
	print("screenshots: ", _items.size())
	quit()
