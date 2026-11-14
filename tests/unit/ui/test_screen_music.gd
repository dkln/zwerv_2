extends RefCounted
## Unit tests of the music of the screens before the game (scripts/ui/menu/screen_music.gd).
##   tests/run_unit_tests.sh screen_music

const ScreenMusic = preload("res://scripts/ui/menu/screen_music.gd")
const MENU_MUSIC := "res://assets/audio/muziek/nachtstad_menu_loop.ogg"


func test_stream(test) -> void:
	test.check(ScreenMusic.stream("res://bestaat/niet.ogg", true) == null, "geen bestand: niets")
	var piece := ScreenMusic.stream(MENU_MUSIC, true)
	test.check(piece != null, "het stuk van het menu")
	test.check(not (piece is AudioStreamOggVorbis) or (piece as AudioStreamOggVorbis).loop, "in een lus")


func test_player(test) -> void:
	var screen := Node.new()
	var music := ScreenMusic.player(screen, "test", MENU_MUSIC, true)
	test.check(music != null and music.get_parent() == screen and music.name == ScreenMusic.PLAYER_NAME and music.stream != null, "een speler als kind van het scherm")
	test.check(not music.playing, "die nog niet speelt")
	screen.free()
