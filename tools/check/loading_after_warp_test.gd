extends SceneTree
## Into the town out of the wave of a scene change (scripts/world/level_of_detail.gd): while the
## wave (WarpTransition) still settles, the loading screen is already up (its waiting music
## playing) and nothing heavy is started; the merging starts once the wave is gone.
## usage: tools/godot.sh --headless --script tools/check/loading_after_warp_test.gd

const Common = preload("res://tools/tool_common.gd")
const LoadingScreenScript = preload("res://scripts/ui/loading_screen.gd")

var _problems: Array[String] = []


func _init() -> void:
	Common.watchdog(self, 200)
	var warp := WarpTransition.new()
	warp.name = WarpTransition.NODE_NAME
	get_root().add_child(warp)
	var scene := Common.instantiate(Common.CITY, false)
	scene.get_node("Verkeer").vehicle_count = 0
	get_root().add_child(scene)
	var detail: Node = scene.get_node("DetailNiveau")
	for frame_index in 5:
		await process_frame
	_check(LoadingScreenScript.showing(self), "het laadscherm staat er meteen")
	_check(detail.is_merging(), "de stad telt als nog niet klaar")
	_check(detail._busy == 0 and detail._pairs.is_empty(), "het zware werk wacht op de overgang")
	warp._arrive()
	var started := Time.get_ticks_msec()
	while detail._pairs.is_empty() and Time.get_ticks_msec() - started < 5000:
		await process_frame
	_check(not detail._pairs.is_empty(), "na de overgang begint het samenvoegen (na %.1f s)" % ((Time.get_ticks_msec() - started) / 1000.0))
	_check(LoadingScreenScript.showing(self) and detail.get_children().filter(func(child: Node) -> bool: return child is LoadingScreenScript).size() == 1,
		"met hetzelfde ene laadscherm")
	print("laden na de overgang ok" if _problems.is_empty() else "FOUT: %s" % [_problems])
	quit()


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FOUT  ") + what)
	if not ok:
		_problems.append(what)
