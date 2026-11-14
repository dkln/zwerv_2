extends RefCounted
## The music of a screen before the game (the intro, the main menu, the character
## creation): the piece read (imported by the editor; if it has not been imported yet,
## straight from the file) and the player that plays it. The screens start and fade it
## themselves (scripts/audio/music_fade.gd).
##   const ScreenMusic = preload("res://scripts/ui/menu/screen_music.gd")

## The name of the player's node.
const PLAYER_NAME := "Muziek"


## The piece at `path` (`looped`: seamless over the whole file); null when it is not there.
static func stream(path: String, looped: bool) -> AudioStream:
	var piece: AudioStream = null
	if ResourceLoader.exists(path):
		piece = load(path)
	elif FileAccess.file_exists(path):
		piece = AudioStreamOggVorbis.load_from_file(path)
	if looped and piece is AudioStreamOggVorbis:
		(piece as AudioStreamOggVorbis).loop = true
		(piece as AudioStreamOggVorbis).loop_offset = 0.0
	return piece


## A player for the piece at `path` as a child of `screen`, not playing yet; null (and a
## warning that names `screen_name`) when the piece is not there.
static func player(screen: Node, screen_name: String, path: String, looped: bool) -> AudioStreamPlayer:
	var piece := stream(path, looped)
	if piece == null:
		push_warning("%s: no music at %s" % [screen_name, path])
		return null
	var music := AudioStreamPlayer.new()
	music.name = PLAYER_NAME
	music.stream = piece
	screen.add_child(music)
	return music
