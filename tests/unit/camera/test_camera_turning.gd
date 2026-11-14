extends RefCounted
## Unit tests of the setting how the view turns (scripts/camera/camera_turning.gd). The
## settings file of the player is put back as it was.
##   tests/run_unit_tests.sh camera_turning

const CameraTurning = preload("res://scripts/camera/camera_turning.gd")


func test_the_keys_do_not_clash(test) -> void:
	var keys: Array = [CameraTurning.KEY_LEFT_TURN, CameraTurning.KEY_RIGHT_TURN, CameraTurning.KEY_TURN_BACK]
	keys.append_array(CameraTurning.KEYS_ZOOM_IN)
	keys.append_array(CameraTurning.KEYS_ZOOM_OUT)
	var unique := {}
	for keycode: Key in keys:
		unique[keycode] = true
	test.check(unique.size() == keys.size(), "geen toets dubbel (%d toetsen)" % keys.size())
	test.check(CameraTurning.KEY_LEFT_TURN == KEY_Z and CameraTurning.KEY_RIGHT_TURN == KEY_X and CameraTurning.KEY_TURN_BACK == KEY_C, "Z / X draaien, C terug")


func test_label_for_reads_as_the_menu_shows_it(test) -> void:
	test.check(CameraTurning.label_for(true) == "CAMERA: ZELF DRAAIEN", "zelf draaien")
	test.check(CameraTurning.label_for(false) == "CAMERA: AUTOMATISCH", "automatisch")


func test_the_setting_is_kept_in_the_settings_file(test) -> void:
	var existed := FileAccess.file_exists(MainMenu.SETTINGS_PATH)
	var before := FileAccess.get_file_as_bytes(MainMenu.SETTINGS_PATH) if existed else PackedByteArray()
	CameraTurning.set_manual(true)
	test.check(CameraTurning.is_manual() and CameraTurning.label() == "CAMERA: ZELF DRAAIEN", "zelf draaien onthouden")
	CameraTurning.set_manual(false)
	test.check(not CameraTurning.is_manual() and CameraTurning.label() == "CAMERA: AUTOMATISCH", "en weer automatisch")
	var config := ConfigFile.new()
	config.load(MainMenu.SETTINGS_PATH)
	test.check(config.has_section_key(CameraTurning.SECTION, CameraTurning.KEY), "onder besturing in het instellingenbestand")
	# the player's settings as they were
	if existed:
		var file := FileAccess.open(MainMenu.SETTINGS_PATH, FileAccess.WRITE)
		file.store_buffer(before)
		file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(MainMenu.SETTINGS_PATH))
	test.check(FileAccess.file_exists(MainMenu.SETTINGS_PATH) == existed, "het instellingenbestand is terug zoals het was")
