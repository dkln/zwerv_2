extends SceneTree
## Takes isometric screenshots of all tour stops in the example map (tour_data.gd),
## with the same caption as the tour in the image, plus docs/screenshots/index.json.
## Like the tour it loads the map part of each stop (scripts/world_parts.gd).
## usage: Godot --script tools/screenshots.gd

const Common = preload("res://tools/tool_common.gd")
const WorldParts = preload("res://scripts/world_parts.gd")
const Data = preload("res://scripts/tour_data.gd")
const Caption = preload("res://scripts/caption.gd")
const OUT_DIR := "res://docs/screenshots"


func _init() -> void:
	Common.watchdog(self, 1800.0)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var sc := Common.instantiate(Common.WORLD)
	get_root().add_child(sc)
	Common.render_size(self, Vector2i(1600, 900))
	var caption := Caption.new(get_root())
	await process_frame

	var items := []
	var shown := 0
	for it in Data.stops(sc):
		var p := WorldParts.part_at(sc, it["z"])
		if p != shown:
			shown = p
			WorldParts.show_part(sc, p)
			await Common.wait_for_merge(sc)
		caption.show_stop(it)
		Common.place_iso(sc, Vector3(it["x"], 0, it["z"]), it["size"])
		await Common.wait_frames(self, 10)
		var file_name := "%02d_%s.png" % [items.size() + 1, it["slug"]]
		Common.save_screenshot(self, OUT_DIR.path_join(file_name))
		# index.json keeps its existing (Dutch) keys so the output format stays the same
		items.append({"bestand": file_name, "titel": it["title"], "tekst": it["text"]})
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT_DIR.path_join("index.json")), FileAccess.WRITE)
	f.store_string(JSON.stringify(items, "  "))
	f.close()
	print("screenshots: ", items.size())
	quit()
