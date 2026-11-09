extends SceneTree
## The street lights (scripts/world/street_lights.gd): the city has its lamps found, at night
## the ones nearest the view burn (at most MAX_LIGHTS, all within reach), by day none.
## usage: tools/godot.sh --headless --script tools/check/street_lights_test.gd

const Common = preload("res://tools/tool_common.gd")

var _problems := []


func _init() -> void:
	Common.watchdog(self, 300)
	var city := Common.instantiate(Common.CITY)
	var detail_level := city.get_node_or_null("DetailNiveau")
	if detail_level:
		detail_level.set("loading_screen", false)
	get_root().add_child(city)
	await Common.wait_frames(self, 5)
	var street_lights: Node = city.get_node_or_null("Straatverlichting")
	_check(street_lights != null, "straatverlichting gemaakt")
	if street_lights == null:
		_finish()
		return
	print("lantaarnkoppen: ", street_lights.lamp_count())
	_check(street_lights.lamp_count() > 800, "alle lantaarns gevonden")
	var day_cycle: Node = city.get_node("Dagcyclus")
	day_cycle.speed = 0.0
	Common.place_iso(city, Vector3(160.0, 0.0, 250.0), 40.0)
	day_cycle.set_time(1.0)
	await Common.wait_frames(self, 40)
	var lit: int = street_lights.lit_count()
	print("'s nachts aan: ", lit)
	_check(lit > 0 and lit <= street_lights.MAX_LIGHTS, "'s nachts branden de lampen in beeld")
	day_cycle.set_time(13.0)
	await Common.wait_frames(self, 5)
	_check(street_lights.lit_count() == 0, "overdag uit")
	_finish()


func _finish() -> void:
	print("straatverlichting ok" if _problems.is_empty() else "FOUT: %s" % [_problems])
	quit()


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FOUT  ") + what)
	if not ok:
		_problems.append(what)
