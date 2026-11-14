extends RefCounted
## Music that runs into the next piece instead of over it: the one going fades out and the one
## coming fades in over the same seconds, equal power (the amplitudes along a quarter cosine and
## sine, so the two together stay as loud and there is no dip and no bump halfway). A fade in dB
## along a straight line (as before) stays loud almost to the end, so two pieces sounded at
## full strength over each other. Used by every screen with music of its own: the intro, the
## main menu, the character choice, the loading screen (the city does the same itself:
## GameHud, the indoor music).
## The music going out is moved to the root of the tree, so it fades on when its scene goes.
## Tweens run while the game is paused too.
## This is the behaviour layer: the players and the tweens. The volume along a fade is the
## rules layer (music_fade_rules.gd); sound has no view and no layout.
##   const MusicFade = preload("res://scripts/audio/music_fade.gd")
##   MusicFade.fade_in(player, -4.0)        # from silence to -4 dB, playing
##   MusicFade.fade_out(player)             # to silence, then freed

const MusicFadeRules = preload("res://scripts/audio/music_fade_rules.gd")
## The seconds of a crossfade and silence are the rules' (MusicFadeRules); here under their
## old names for the screens that use them.
const SECONDS := MusicFadeRules.SECONDS
const SILENT_DB := MusicFadeRules.SILENT_DB


## `player` from silence to `volume_db` (playing it), over `seconds`.
static func fade_in(player: AudioStreamPlayer, volume_db: float, seconds := SECONDS) -> void:
	if player == null:
		return
	player.volume_db = SILENT_DB
	if not player.playing:
		player.play()
	var tween := player.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(func(share: float) -> void:
		player.volume_db = MusicFadeRules.fade_in_db(volume_db, share), 0.0, 1.0, seconds)


## `player` from where it is to silence over `seconds`, then stopped and freed. It is moved to
## the root first (so it fades on when its scene is left).
static func fade_out(player: AudioStreamPlayer, seconds := SECONDS) -> void:
	if player == null or not is_instance_valid(player):
		return
	if not player.playing or not player.is_inside_tree():
		player.queue_free()
		return
	var root := player.get_tree().root
	if player.get_parent() != root:
		player.reparent(root)
	var from_db := player.volume_db
	var tween := root.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(func(share: float) -> void:
		if is_instance_valid(player):
			player.volume_db = MusicFadeRules.fade_out_db(from_db, share), 0.0, 1.0, seconds)
	tween.tween_callback(func() -> void:
		if is_instance_valid(player):
			player.queue_free())
