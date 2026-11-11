extends SceneTree
## Checks headless that the city music really plays: the map jingle (KaartDeuntje) starts once
## the map is there, and after it the loop of the neighbourhood (StadMuziek) with a stream;
## one loop everywhere (spel_loop.ogg); into a building with its own music (the merchant's) and
## out again crossfades there and back.
## usage: tools/godot.sh --headless --script tools/check/city_music_test.gd

const Common = preload("res://tools/tool_common.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")

var _problems: Array[String] = []


func _init() -> void:
	Common.watchdog(self, 300)
	PlayerCharacter.choose("jos")
	var scene := Common.instantiate(Common.CITY, false)
	scene.get_node("Verkeer").vehicle_count = 0
	get_root().add_child(scene)
	var hud: Node = scene.get_node("HUD")
	var jingle_seen := false
	var music: AudioStreamPlayer = null
	var started_msec := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started_msec < 60000:
		await process_frame
		var jingle := hud.get_node_or_null("KaartDeuntje") as AudioStreamPlayer
		if jingle and not jingle_seen:
			jingle_seen = true
			print("deuntje speelt: %s, %.1f s" % [jingle.playing, jingle.stream.get_length()])
		music = hud.get_node_or_null("StadMuziek") as AudioStreamPlayer
		if music:
			break
	_check(jingle_seen, "kaartdeuntje start")
	_check(music != null, "stadsmuziek start na het deuntje")
	if music:
		print("stadsmuziek: %s (%s), speelt %s, %.1f dB" % [hud._city_music_file,
				music.stream.resource_path if music.stream.resource_path != "" else "los bestand",
				music.playing, music.volume_db])
		_check(music.stream != null and music.stream.get_length() > 10.0, "stadsmuziek heeft een stream")
		_check(music.playing, "stadsmuziek speelt")
	if music:
		await _check_crossfade(hud)
	print("muziek ok" if _problems.is_empty() else "%d problemen: %s" % [_problems.size(), _problems])
	quit(0 if _problems.is_empty() else 1)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_problems.append(what)
		print("FOUT: " + what)


func _check_crossfade(hud: Node) -> void:
	# wait for the fade-in
	var started := Time.get_ticks_msec()
	while hud._city_weights.get(hud._city_music_file, 0.0) < 1.0 and Time.get_ticks_msec() - started < 8000:
		await process_frame
	var first_file: String = hud._city_music_file
	print("niveau stadsmuziek: %.1f dB" % hud._city_level_db)
	# the prologue in the story box pauses the game: then the paused level
	var expected: float = hud.CITY_MUSIC_PAUSED_DB if paused else hud.CITY_MUSIC_VOLUME_DB
	_check(absf(hud._city_level_db - expected) < 0.5, "stadsmuziek op %.0f dB (%s)" % [expected, "gepauzeerd" if paused else "spelend"])
	_check(first_file == hud.CITY_MUSIC, "de spelmuziek (%s) speelt" % hud.CITY_MUSIC)
	# into a building with music of its own (the merchant's) and out: crossfades and back
	hud.set_indoor_music("handelaar_loop.ogg")
	await create_timer(hud.INDOOR_MUSIC_FADE + 0.5).timeout
	_check(hud._city_music_file == "handelaar_loop.ogg", "binnen: de muziek van de handelaar")
	hud.set_indoor_music("")
	await create_timer(hud.INDOOR_MUSIC_FADE + 0.5).timeout
	_check(hud._city_music_file == first_file and hud._city_players.size() == 1, "weer buiten: de spelmuziek, één speler")
	var still := hud._city_players.get(first_file) as AudioStreamPlayer
	_check(still != null and still.playing, "de spelmuziek speelt door")
