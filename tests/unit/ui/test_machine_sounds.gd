extends RefCounted
## Unit tests of the sounds of the machines (scripts/ui/machines/machine_sounds.gd): every
## sound made once and kept, the waves they are made of (square, sweep, noise, silence), the
## samples as a 16-bit stream, and playing one on a node in the tree.
##   tests/run_unit_tests.sh machine_sounds

const MachineSounds = preload("res://scripts/ui/machines/machine_sounds.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


func test_every_machine_sound_is_made_once(test) -> void:
	for sound_name: String in ["toets", "goed", "fout", "blik", "band", "printer", "geld", "kaart", "inslikken"]:
		var stream := MachineSounds.sound(sound_name)
		test.check(stream != null and stream.mix_rate == MachineSounds.MIX_RATE and stream.format == AudioStreamWAV.FORMAT_16_BITS
			and not stream.stereo and stream.data.size() > 0, "%s: een mono 16-bits geluid" % sound_name)
		test.check(MachineSounds.sound(sound_name) == stream, "%s: de tweede keer hetzelfde geluid" % sound_name)
	test.check(MachineSounds.sound("bestaat_niet") == null, "een onbekend geluid: niets")
	test.check(MachineSounds.sound("toets").data.size() == int(0.05 * MachineSounds.MIX_RATE) * 2, "de toets duurt 0,05 s")
	test.check(MachineSounds.sound("inslikken").data.size() > MachineSounds.sound("kaart").data.size(), "inslikken duurt langer dan de kaart")
	for sound_name: String in MachineSounds.LEVEL_TRIM_DB:
		test.check(MachineSounds.sound(sound_name) != null, "%s (bijgesteld in volume) bestaat" % sound_name)


func test_the_waves_of_the_machine_sounds(test) -> void:
	var square := MachineSounds._square(441.0, 0.1, 0.5)
	test.check(square.size() == int(0.1 * MachineSounds.MIX_RATE), "een blokgolf: zoveel samples als hij duurt")
	var loudest := 0.0
	var high_samples := 0
	for sample in square:
		loudest = maxf(loudest, absf(sample))
		if sample > 0.0:
			high_samples += 1
	test.check(loudest <= 0.5 and loudest > 0.45, "niet harder dan gevraagd (%.2f)" % loudest)
	test.check(absf(float(high_samples) / square.size() - 0.25) < 0.02, "een kwart van de tijd hoog (%.3f)" % (float(high_samples) / square.size()))
	test.check(absf(square[square.size() - 1]) < absf(square[0]), "het volume zakt weg")
	var sweep := MachineSounds._sweep(200.0, 400.0, 0.2, 0.4)
	test.check(sweep.size() == int(0.2 * MachineSounds.MIX_RATE) and sweep[0] == 0.0, "een glijdende toon: begint zacht")
	var noise := MachineSounds._noise(0.1, 0.6, 4)
	test.check(noise == MachineSounds._noise(0.1, 0.6, 4), "ruis is elke keer dezelfde")
	test.check(noise[0] == noise[3] and is_equal_approx(absf(noise[0]), 0.6), "en houdt zijn niveau `hold` samples vast")
	test.check(MachineSounds._noise(0.01, 0.5, 0).size() == int(0.01 * MachineSounds.MIX_RATE), "hold 0 telt als 1")
	var silence := MachineSounds._silence(0.05)
	test.check(silence.size() == int(0.05 * MachineSounds.MIX_RATE) and silence[0] == 0.0 and silence[silence.size() - 1] == 0.0, "stilte is stil")
	var stream := MachineSounds._stream(PackedFloat32Array([0.0, 1.0, -1.0, 5.0]))
	test.check(stream.data.size() == 8 and stream.data.decode_s16(0) == 0 and stream.data.decode_s16(2) == 26000
		and stream.data.decode_s16(4) == -26000 and stream.data.decode_s16(6) == 26000, "samples naar 16 bits, afgekapt op vol")


func test_play_needs_a_node_in_the_tree(test) -> void:
	var players_before := _sound_players().size()
	MachineSounds.play(null, "toets")
	var loose := Node.new()
	MachineSounds.play(loose, "toets")
	test.check(_sound_players().size() == players_before, "zonder knoop in de boom: geen geluid")
	tree.root.add_child(loose)
	MachineSounds.play(loose, "bestaat_niet")
	test.check(_sound_players().size() == players_before, "een onbekend geluid: ook niet")
	MachineSounds.play(loose, "fout", -3.0)
	var players := _sound_players()
	test.check(players.size() == players_before + 1, "een geluid: een speler onder de root")
	var newest := players.back() as AudioStreamPlayer
	test.check(newest.stream == MachineSounds.sound("fout") and newest.process_mode == Node.PROCESS_MODE_ALWAYS, "het goede geluid, ook als het spel stilstaat")
	test.check(is_equal_approx(newest.volume_db, MachineSounds.VOLUME_DB + float(MachineSounds.LEVEL_TRIM_DB["fout"]) - 3.0), "het volume: de mix, de bijstelling en zachter (%.1f dB)" % newest.volume_db)
	newest.free()
	loose.free()


func _sound_players() -> Array:
	return tree.root.get_children().filter(func(child: Node) -> bool: return child is AudioStreamPlayer)
