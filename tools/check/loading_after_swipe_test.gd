extends SceneTree
## Into the town under the swipe of a scene change (scripts/world/level_of_detail.gd): while the
## swipe (SwipeTransition) still runs, the loading screen is already up (its waiting music
## playing) and nothing heavy is started, and it stays up (also when the interiors are ready
## under it); the merging starts once the swipe is through, under that same screen.
## usage: tools/godot.sh --headless --script tools/check/loading_after_swipe_test.gd

const Common = preload("res://tools/tool_common.gd")
const LoadingScreenScript = preload("res://scripts/ui/loading_screen.gd")
const SwipeTransition = preload("res://scripts/ui/swipe_transition.gd")

var _problems: Array[String] = []


func _init() -> void:
	Common.watchdog(self, 200)
	# a stand-in for the swipe of the scene change (only its node, so it is not through yet)
	var swipe := CanvasLayer.new()
	swipe.name = SwipeTransition.NODE_NAME
	get_root().add_child(swipe)
	var scene := Common.instantiate(Common.CITY, false)
	scene.get_node("Verkeer").vehicle_count = 0
	get_root().add_child(scene)
	var detail: Node = scene.get_node("DetailNiveau")
	# long enough for the interiors to be built and warmed up under the screen (Interiors
	# holds and then releases it): that must not close it while the swipe still runs
	for frame_index in 40:
		await process_frame
	_check(LoadingScreenScript.showing(self) and detail._screen != null, "het laadscherm staat er meteen en blijft staan")
	var first_screen: Node = detail._screen
	_check(detail.is_merging(), "de stad telt als nog niet klaar")
	_check(detail._busy == 0 and detail._pairs.is_empty(), "het zware werk wacht op de overgang")
	swipe.queue_free()
	var started := Time.get_ticks_msec()
	while detail._pairs.is_empty() and Time.get_ticks_msec() - started < 5000:
		await process_frame
	_check(not detail._pairs.is_empty(), "na de overgang begint het samenvoegen (na %.1f s)" % ((Time.get_ticks_msec() - started) / 1000.0))
	_check(LoadingScreenScript.showing(self) and detail._screen == first_screen
			and detail.get_children().filter(func(child: Node) -> bool: return child is LoadingScreenScript).size() == 1,
		"met hetzelfde ene laadscherm (niet dicht en weer open)")
	print("laden na de overgang ok" if _problems.is_empty() else "FOUT: %s" % [_problems])
	quit()


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FOUT  ") + what)
	if not ok:
		_problems.append(what)
