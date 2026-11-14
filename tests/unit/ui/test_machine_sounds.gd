extends RefCounted
## Unit tests of the sounds of the machines (scripts/ui/machines/machine_sounds.gd): every
## sound made once and kept, the samples as a 16-bit stream, and playing one on a node in
## the tree. How the sounds are made: test_machine_sounds_rules.gd.
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


func test_stream_of_makes_a_mono_16_bit_stream(test) -> void:
	var stream := MachineSounds.stream_of(PackedFloat32Array([0.0, 1.0, -1.0, 5.0]))
	test.check(stream.format == AudioStreamWAV.FORMAT_16_BITS and stream.mix_rate == MachineSounds.MIX_RATE and not stream.stereo, "mono, 16 bits, op de mixfrequentie")
	test.check(stream.data.size() == 8 and stream.data.decode_s16(2) == 26000, "elke sample twee bytes")
	test.check(MachineSounds.stream_of(PackedFloat32Array()).data.is_empty(), "zonder samples: een leeg geluid")


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
