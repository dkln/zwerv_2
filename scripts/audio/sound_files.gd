extends RefCounted
## Where a sound of assets/audio/geluiden/ is: every sound in a folder of its category, by its
## name (CATEGORIES: the first prefix that fits; the babble per voice), so the folder stays
## tidy and the code only ever names a sound. The generators (tools/megadrive/categorieen.py)
## put a sound in the same folder.
##   brabbel/<stem>/   brabbel_<stem>_<mood>_<n>  the babble of conversations, per voice
##   mensen/           pain, blows, jumping, a splash, throwing up
##   voertuigen/       cars, buses, trams, trains, mopeds, bicycles, sirens, the helicopter
##   ov/               gates, checking in and out, the conductor's whistle, the station's gong
##   binnen/           doors, the lift, the till, the shop alarm
##   effecten/         explosions, fire
##   overig/           what fits none of them
##   const SoundFiles = preload("res://scripts/audio/sound_files.gd")
##   var stream := load(SoundFiles.path_of("tram_bel"))

const ROOT := "res://assets/audio/geluiden/"
## The first prefix (or whole name) of a sound that fits says its folder.
const CATEGORIES := [
	["pijn_", "mensen"], ["lichaam_klap", "mensen"], ["klap", "mensen"], ["schop", "mensen"], ["springen", "mensen"],
	["plons", "mensen"], ["overgeven", "mensen"],
	["ov_", "ov"], ["poortje_", "ov"], ["conducteur_", "ov"], ["omroep_", "ov"],
	["deur_", "binnen"], ["lift_", "binnen"], ["kassa_", "binnen"], ["winkel_", "binnen"],
	["explosie", "effecten"], ["brand_loop", "effecten"],
	["ambulance_", "voertuigen"], ["auto_", "voertuigen"], ["brommer_", "voertuigen"], ["bus_", "voertuigen"],
	["fiets_", "voertuigen"], ["helikopter_", "voertuigen"], ["politie_", "voertuigen"], ["brandweer_", "voertuigen"],
	["scootmobiel_", "voertuigen"], ["sirene_", "voertuigen"], ["tram_", "voertuigen"], ["trein_", "voertuigen"],
]
const VOICES := ["oude_man", "rasperig", "vrouw", "man"]


## The folder of `sound_name` under ROOT (see the top), without a slash at the end.
static func category_of(sound_name: String) -> String:
	if sound_name.begins_with("brabbel_"):
		for voice: String in VOICES:
			if sound_name.begins_with("brabbel_" + voice + "_"):
				return "brabbel/" + voice
		return "brabbel"
	for entry: Array in CATEGORIES:
		if sound_name.begins_with(String(entry[0])):
			return String(entry[1])
	return "overig"


## The path of `sound_name` (no ".ogg"): res://assets/audio/geluiden/<category>/<name>.ogg.
static func path_of(sound_name: String) -> String:
	return ROOT + category_of(sound_name) + "/" + sound_name + ".ogg"


## Every sound file there is (the names, without ".ogg"), in all the folders.
static func all_names() -> Array[String]:
	var names: Array[String] = []
	_collect(ROOT, names)
	names.sort()
	return names


static func _collect(folder: String, names: Array[String]) -> void:
	for file_name in DirAccess.get_files_at(folder):
		if file_name.ends_with(".ogg"):
			names.append(file_name.trim_suffix(".ogg"))
	for sub_folder in DirAccess.get_directories_at(folder):
		_collect(folder.path_join(sub_folder), names)
