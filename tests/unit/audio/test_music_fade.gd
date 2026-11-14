extends RefCounted
## Unit tests of music running into the next piece (scripts/audio/music_fade.gd, the
## behaviour): what fading in and out do to a player at once (the fade itself runs on a
## tween; its volumes are the rules': tests/unit/audio/test_music_fade_rules.gd). That it
## sounds in the game: tests/integration/ui/test_music_fade.gd.
##   tests/run_unit_tests.sh music_fade

const MusicFade = preload("res://scripts/audio/music_fade.gd")
const MUSIC := "res://assets/audio/muziek/spel_loop.ogg"

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


func _player(parent: Node) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = load(MUSIC)
	player.volume_db = -4.0
	parent.add_child(player)
	return player


func test_fade_in_starts_silent_and_playing(test) -> void:
	var player := _player(tree.root)
	MusicFade.fade_in(player, -4.0)
	test.check(player.volume_db == MusicFade.SILENT_DB, "begint stil")
	test.check(player.playing, "en speelt")
	MusicFade.fade_in(null, -4.0)
	test.check(is_instance_valid(player), "zonder speler gebeurt er niets")
	player.free()


func test_fade_out_of_what_does_not_play_frees_it(test) -> void:
	var player := _player(tree.root)
	MusicFade.fade_out(player)
	test.check(player.is_queued_for_deletion(), "wat niet speelt gaat meteen weg")
	var loose := AudioStreamPlayer.new()
	MusicFade.fade_out(loose)
	test.check(loose.is_queued_for_deletion(), "wat niet in de boom staat ook")
	MusicFade.fade_out(null)
	test.check(true, "zonder speler gebeurt er niets")
	player.free()
	loose.free()


func test_fade_out_moves_the_player_to_the_root(test) -> void:
	var tweens_before := tree.get_processed_tweens()
	var scene := Node.new()
	tree.root.add_child(scene)
	var player := _player(scene)
	player.play()
	MusicFade.fade_out(player, 0.5)
	test.check(player.get_parent() == tree.root, "de speler hangt nu aan de wortel (hij klinkt door als zijn scène gaat)")
	test.check(player.playing and not player.is_queued_for_deletion(), "en speelt nog terwijl hij wegzakt")
	test.check(is_equal_approx(player.volume_db, -4.0), "vanaf waar hij was")
	scene.free()
	test.check(is_instance_valid(player), "ook als zijn scène weg is")
	# the fade runs on the root: stop it before its player goes
	for tween: Tween in tree.get_processed_tweens():
		if not tween in tweens_before:
			tween.kill()
	player.free()
