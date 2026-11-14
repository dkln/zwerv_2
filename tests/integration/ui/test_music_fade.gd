extends "res://tests/integration/support/town_test.gd"
## Music running into the next piece (scripts/audio/music_fade.gd): the one going out and the
## one coming in cross over the same seconds at equal power (together as loud all the way, no
## two pieces at full strength over each other); the one going out ends up freed.
##   tests/run_integration_tests.sh music_fade

const MusicFade = preload("res://scripts/audio/music_fade.gd")


static func world_options() -> Dictionary:
	return {"town": false}


func _player(volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = AudioStreamGenerator.new()
	player.volume_db = volume_db
	add_to_root(player)
	return player


func test_crossfade_at_equal_power(test) -> void:
	var going := _player(0.0)
	going.play()
	var coming := _player(0.0)
	MusicFade.fade_out(going, 1.0)
	MusicFade.fade_in(coming, 0.0, 1.0)
	var louder_than_both := false
	var lowest_power := 2.0
	var started := Time.get_ticks_msec()
	while is_instance_valid(going) and Time.get_ticks_msec() - started < 5000:
		await tree.process_frame
		if not is_instance_valid(going):
			break
		var power := pow(db_to_linear(going.volume_db), 2.0) + pow(db_to_linear(coming.volume_db), 2.0)
		lowest_power = minf(lowest_power, power)
		if db_to_linear(going.volume_db) > 0.9 and db_to_linear(coming.volume_db) > 0.9:
			louder_than_both = true
	test.check(not louder_than_both, "nooit allebei op vol")
	test.check(lowest_power > 0.85, "samen even hard, geen gat halverwege (laagste %.2f)" % lowest_power)
	test.check(not is_instance_valid(going), "wat uitging is weg")
	test.check(coming.playing and absf(coming.volume_db) < 0.5, "wat inkwam speelt op zijn sterkte (%.1f dB)" % coming.volume_db)
	coming.queue_free()
