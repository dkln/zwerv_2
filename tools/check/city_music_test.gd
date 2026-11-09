extends SceneTree
## Checks headless that the city music really plays: the map jingle (KaartDeuntje) starts once
## the map is there, and after it the loop of the neighbourhood (StadMuziek) with a stream;
## going to another neighbourhood crossfades without a dip in loudness, in step with the bar;
## a quick step over a border and back, or outside every neighbourhood, changes nothing.
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


## The power of all city loops together, against the level (1 = one loop at full level).
func _power(hud: Node) -> float:
	var power := 0.0
	for player: AudioStreamPlayer in hud._city_players.values():
		power += pow(db_to_linear(player.volume_db - hud._city_level_db), 2.0)
	return power


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
	var other_wijk := "Binckhorst" if first_file != "stad_industrie_loop.ogg" else "Malieveld"
	# over the border and straight back: nothing changes
	hud._switch_city_music(other_wijk)
	await create_timer(0.5).timeout
	hud._switch_city_music("Centraal Station" if first_file == "stad_torens_loop.ogg" else _wijk_with(hud, first_file))
	await create_timer(hud.CITY_MUSIC_SETTLE + 0.3).timeout
	_check(hud._city_music_file == first_file and hud._city_players.size() == 1, "even over de grens en terug: muziek blijft")
	hud._switch_city_music(hud.NO_WIJK)
	await create_timer(hud.CITY_MUSIC_SETTLE + 0.3).timeout
	_check(hud._city_music_file == first_file, "buiten elke wijk: muziek blijft")
	# a real move: after the settle time it crossfades, the power never dips
	hud._switch_city_music(other_wijk)
	var lowest := 9.0
	var highest := 0.0
	var both_seen := false
	var in_step := true
	started = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < int((hud.CITY_MUSIC_SETTLE + hud.CITY_MUSIC_CROSSFADE + 1.0) * 1000):
		await process_frame
		var power := _power(hud)
		lowest = minf(lowest, power)
		highest = maxf(highest, power)
		if hud._city_players.size() == 2:
			both_seen = true
			var positions: Array = hud._city_players.values().map(func(player): return player.get_playback_position())
			if absf(positions[0] - positions[1]) > 0.15:
				in_step = false
	print("overvloeien %s -> %s: vermogen %.2f..%.2f" % [first_file, hud._city_music_file, lowest, highest])
	_check(hud._city_music_file != first_file, "na %.1f s in een andere wijk: andere muziek" % hud.CITY_MUSIC_SETTLE)
	_check(both_seen, "beide loops klinken tijdens het overvloeien")
	_check(lowest > 0.85 and highest < 1.15, "geen gat of piek tijdens het overvloeien")
	_check(in_step, "nieuwe loop loopt gelijk met de maat")
	_check(hud._city_players.size() == 1, "oude loop is weg na het overvloeien")


func _wijk_with(hud: Node, file: String) -> String:
	for wijk: String in hud.CITY_MUSIC_BY_AREA:
		if hud.CITY_MUSIC_BY_AREA[wijk] == file:
			return wijk
	return "Centrum"
