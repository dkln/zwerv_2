extends SceneTree
## How long the town takes to start as in the game (with the merged meshes of DetailNiveau,
## behind its loading screen), and where the time goes: reading the scene, adding it to the
## tree, every "merged in" of the layers, the frames that took long, until the loading
## screen is gone. Run it with a window for the real thing (the GPU uploads count):
##   tools/godot.sh --script tools/check/game_load_profile.gd
const Common = preload("res://tools/tool_common.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")


func _init() -> void:
	Common.watchdog(self, 200)
	PlayerCharacter.choose("martin")
	await process_frame
	var started := Time.get_ticks_msec()
	var packed: PackedScene = load(Common.CITY)
	print("lezen        %5d ms" % (Time.get_ticks_msec() - started))
	var mark := Time.get_ticks_msec()
	var scene := packed.instantiate()
	get_root().add_child(scene)
	print("in de boom   %5d ms" % (Time.get_ticks_msec() - mark))
	var detail := scene.get_node_or_null("DetailNiveau")
	var slow: Array[String] = []
	var frames := 0
	var calm := 0
	while calm < 60 and Time.get_ticks_msec() - started < 150000:
		var before := Time.get_ticks_msec()
		await process_frame
		frames += 1
		var took := Time.get_ticks_msec() - before
		if took > 100:
			slow.append("%d ms op %.1f s" % [took, (before - started) / 1000.0])
		var busy: bool = detail != null and (detail.is_merging() or detail.screen_is_up())
		calm = 0 if busy else calm + 1
	print("klaar na     %5d ms (%d frames)" % [Time.get_ticks_msec() - started, frames])
	print("trage frames: ", slow)
	Common.finish(self, 0)
