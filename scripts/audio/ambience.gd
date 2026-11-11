extends Node
## The background sound of where the player is (assets/audio/omgeving/, free recordings made
## into loops by tools/megadrive/omgeving.py): softly under everything, the murmur of the
## street outside, the hall of Den Haag Centraal, a shop. Going somewhere else crossfades from
## the one to the other in FADE_SECONDS (equal power). Interiors tells it where (set_place).
##   var ambience := Ambience.new()
##   add_child(ambience)
##   ambience.set_place("straat")

const FOLDER := "res://assets/audio/omgeving/"
## Per place: its loop and how loud it plays (dB: soft, the sounds of the game over it).
const PLACES := {
	"straat": {"file": "straat_loop.ogg", "volume_db": -22.0},
	"station": {"file": "station_loop.ogg", "volume_db": -19.0},
	"winkel": {"file": "winkel_loop.ogg", "volume_db": -21.0},
}
const FADE_SECONDS := 2.0
const SILENT_DB := -60.0

var place := ""
var _player: AudioStreamPlayer      # what plays now
var _fading_out: AudioStreamPlayer  # what plays no more, fading


## Where the player is now ("straat", "station", "winkel"; "" none): crossfades to its sound.
func set_place(new_place: String) -> void:
	if new_place == place:
		return
	place = new_place
	if _fading_out and is_instance_valid(_fading_out):
		_fading_out.queue_free()
	_fading_out = _player
	_player = null
	if _fading_out:
		var out := create_tween()
		out.tween_property(_fading_out, "volume_db", SILENT_DB, FADE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		out.tween_callback(_fading_out.queue_free)
	var settings: Dictionary = PLACES.get(new_place, {})
	var stream := _loop(String(settings.get("file", "")))
	if stream == null:
		return
	_player = AudioStreamPlayer.new()
	_player.name = "Omgeving_" + new_place
	_player.stream = stream
	_player.volume_db = SILENT_DB
	add_child(_player)
	_player.play(randf() * stream.get_length())
	var fade_in := create_tween()
	fade_in.tween_property(_player, "volume_db", float(settings.volume_db), FADE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## The loop of `file` (imported by the editor, or straight from the file before that).
static func _loop(file: String) -> AudioStream:
	if file == "":
		return null
	var path := FOLDER + file
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path)
	elif FileAccess.file_exists(path):
		stream = AudioStreamOggVorbis.load_from_file(path)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	return stream
