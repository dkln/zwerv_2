extends RefCounted
## The setting how the view turns (user://instellingen.cfg, MainMenu.SETTINGS_PATH, section
## "besturing"): automatically round buildings and to the street (the follow camera chooses,
## follow_camera.gd), or by the player only ("zelf": Z / X on the keyboard, the right stick of a
## controller, a quarter turn each, so four views; C or pressing the right stick back to the
## usual one: FollowCamera.turn_by, turn_back). Set in the settings of the main
## menu and in the pause menu (GameHud); the follow camera reads it (set_manual_turning).
##   const CameraTurning = preload("res://scripts/camera/camera_turning.gd")
##   if CameraTurning.is_manual(): ...

const SECTION := "besturing"
const KEY := "camera_zelf_draaien"
## The keys that turn the view (left, right, back to the usual view) when it is turned by hand;
## on a controller the right stick and pressing it (R3), pad_keys.gd.
const KEY_LEFT_TURN := KEY_Z
const KEY_RIGHT_TURN := KEY_X
const KEY_TURN_BACK := KEY_C
## Zooming when the view is turned by hand (FollowCamera.zoom_by): + and - (also on the number
## pad); the right stick up and down comes as these too (pad_keys.gd).
const KEYS_ZOOM_IN := [KEY_EQUAL, KEY_PLUS, KEY_KP_ADD]
const KEYS_ZOOM_OUT := [KEY_MINUS, KEY_KP_SUBTRACT]


static func is_manual() -> bool:
	var config := ConfigFile.new()
	config.load(MainMenu.SETTINGS_PATH)
	return bool(config.get_value(SECTION, KEY, false))


static func set_manual(manual: bool) -> void:
	var config := ConfigFile.new()
	config.load(MainMenu.SETTINGS_PATH)
	config.set_value(SECTION, KEY, manual)
	config.save(MainMenu.SETTINGS_PATH)


## How the setting reads in a menu.
static func label() -> String:
	return "CAMERA: " + ("ZELF DRAAIEN" if is_manual() else "AUTOMATISCH")
