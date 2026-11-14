extends RefCounted
## Unit tests of the sound effects of the menus (scripts/ui/ui_sounds.gd): play() makes a
## player that frees itself, at the level of its sound; the sounds are made once, each as
## long as its notes; nothing without a node in the tree or for an unknown name.
##   tests/run_unit_tests.sh ui_sounds

const UiSounds = preload("res://scripts/ui/ui_sounds.gd")
const SoundVariation = preload("res://scripts/audio/sound_variation.gd")

const NAMES := ["kies", "doe", "terug", "plop", "tekst", "munt", "item"]

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


## The players under the root that are not in `before`.
func _new_players(before: Array) -> Array:
	return tree.root.get_children().filter(func(child: Node) -> bool: return child is AudioStreamPlayer and not before.has(child))


func _players_now() -> Array:
	return _new_players([])


## Plays `sound_name` from a node in the tree and gives its player (null if none came).
func _play(sound_name: String, softer_db := 0.0, pitch_scale := 1.0) -> AudioStreamPlayer:
	var before := _players_now()
	var owner := Node.new()
	tree.root.add_child(owner)
	UiSounds.play(owner, sound_name, softer_db, pitch_scale)
	owner.free()
	var made := _new_players(before)
	return made[0] if made.size() == 1 else null


## Stops and frees a player made by play() (the test has no frames in which it frees itself).
static func _discard(player: AudioStreamPlayer) -> void:
	if player:
		player.stop()
		player.free()


func test_play_makes_a_player_at_the_level_of_the_sound(test) -> void:
	var player := _play("kies")
	test.check(player != null, "een speler onder de root")
	if player == null:
		return
	test.check(player.stream is AudioStreamWAV and player.playing, "die het geluid speelt")
	test.check(is_equal_approx(player.volume_db, UiSounds.VOLUME_DB + UiSounds.LEVEL_TRIM_DB["kies"]), "op het niveau van dat geluid (%s dB)" % player.volume_db)
	test.check(absf(player.pitch_scale - 1.0) <= SoundVariation.UI_SPREAD + 0.0001, "bijna op zijn eigen toonhoogte (%s)" % player.pitch_scale)
	test.check(player.process_mode == Node.PROCESS_MODE_ALWAYS, "ook als het spel stilstaat")
	test.check(player.finished.is_connected(player.queue_free), "en ruimt zichzelf op")
	_discard(player)


func test_softer_and_pitch_are_passed_on(test) -> void:
	var player := _play("tekst", -11.0, 2.0)
	test.check(player != null, "een speler")
	if player == null:
		return
	test.check(is_equal_approx(player.volume_db, UiSounds.VOLUME_DB - 11.0), "zachter gevraagd: zachter (tekst heeft geen eigen correctie)")
	test.check(absf(player.pitch_scale - 2.0) <= 2.0 * SoundVariation.UI_SPREAD + 0.0001, "hoger gevraagd: hoger (%s)" % player.pitch_scale)
	_discard(player)


func test_nothing_without_a_node_in_the_tree_or_for_an_unknown_sound(test) -> void:
	var before := _players_now()
	UiSounds.play(null, "kies")
	var loose := Node.new()
	UiSounds.play(loose, "kies")
	loose.free()
	test.check(_new_players(before).is_empty(), "geen node, of een node buiten de boom: niets")
	test.check(_play("bestaat_niet") == null and _new_players(before).is_empty(), "een onbekend geluid: niets")


func test_every_sound_is_made_once(test) -> void:
	var streams := {}
	for sound_name: String in NAMES:
		var player := _play(sound_name)
		test.check(player != null and player.stream is AudioStreamWAV, "%s bestaat" % sound_name)
		if player == null:
			continue
		var stream := player.stream as AudioStreamWAV
		test.check(stream.format == AudioStreamWAV.FORMAT_16_BITS and stream.mix_rate == UiSounds.MIX_RATE and not stream.stereo, "%s: 16 bits mono op 22 kHz" % sound_name)
		test.check(stream.data.size() > 0 and stream.get_length() < 0.5, "%s: een kort geluid (%.3f s)" % [sound_name, stream.get_length()])
		streams[sound_name] = stream
		_discard(player)
		var again := _play(sound_name)
		test.check(again != null and again.stream == stream, "%s: de tweede keer hetzelfde geluid" % sound_name)
		_discard(again)
	var different := {}
	for sound_name: String in streams:
		different[(streams[sound_name] as AudioStreamWAV).data] = true
	test.check(different.size() == NAMES.size(), "elk geluid is een ander (%d)" % different.size())
	test.check(UiSounds.LEVEL_TRIM_DB.keys().all(func(sound_name: String) -> bool: return NAMES.has(sound_name)), "elke correctie hoort bij een geluid dat er is")


func test_a_sound_is_as_long_as_its_notes(test) -> void:
	var select := _play("kies")
	var plop := _play("plop")
	var blip := _play("tekst")
	if select == null or plop == null or blip == null:
		test.check(false, "de geluiden bestaan")
		return
	# two bytes a sample; "kies": notes of 0.035 and 0.07 s
	test.check((select.stream as AudioStreamWAV).data.size() == 2 * (int(0.035 * UiSounds.MIX_RATE) + int(0.07 * UiSounds.MIX_RATE)), "kies: twee noten achter elkaar")
	test.check((plop.stream as AudioStreamWAV).data.size() == 2 * int(0.12 * UiSounds.MIX_RATE), "plop: 0,12 s")
	test.check((blip.stream as AudioStreamWAV).data.size() == 2 * int(0.038 * UiSounds.MIX_RATE), "tekst: 38 ms")
	var blip_data := (blip.stream as AudioStreamWAV).data
	var loudest := 0
	for sample_index in blip_data.size() / 2:
		loudest = maxi(loudest, absi(blip_data.decode_s16(sample_index * 2)))
	test.check(loudest > 10000 and loudest <= 15000, "de blip op halve sterkte (%d)" % loudest)
	test.check(absi(blip_data.decode_s16(blip_data.size() - 2)) == 0, "en uitgestorven aan het eind")
	_discard(select)
	_discard(plop)
	_discard(blip)
