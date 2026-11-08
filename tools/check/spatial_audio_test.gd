extends SceneTree
## Loads scenes/stad.tscn with its traffic and the spatial sound (scripts/audio/spatial_audio.gd,
## autoload RuimtelijkGeluid; added here when the autoload is not there), headless, and checks:
## it switches on with the player, vehicles near the ear get engine sound, a point behind a
## building is occluded and an open one is not, and the survey of the surroundings sets the echo
## and reverb of the traffic bus.
## usage: tools/godot.sh --headless --script tools/check/spatial_audio_test.gd

const Common = preload("res://tools/tool_common.gd")
const SPATIAL_AUDIO = preload("res://scripts/audio/spatial_audio.gd")

var _problems := []


func _init() -> void:
	Common.watchdog(self, 300)
	var spatial: Node = get_root().get_node_or_null("RuimtelijkGeluid")
	if spatial == null:
		spatial = SPATIAL_AUDIO.new()
		spatial.name = "RuimtelijkGeluid"
		get_root().add_child(spatial)
	await process_frame
	var scene := Common.instantiate(Common.CITY)
	for node_name in ["DetailNiveau", "Rook", "Grassprieten"]:
		if scene.has_node(node_name):
			scene.get_node(node_name).free()
	get_root().add_child(scene)
	for frame_index in 240:
		await process_frame

	_check(spatial._active, "aan zodra de speler er is")
	_check(AudioServer.get_bus_index(spatial.BUS_NAME) != -1, "bus %s gemaakt" % spatial.BUS_NAME)
	print("voertuigen gevonden: %d, met geluid: %d" % [spatial._vehicles.size(), spatial._emitters.size()])
	for entry in spatial.emitter_report():
		print("  %-10s %5.1f m  afgeschermd %.2f  toon %.2f%s" % [entry.kind, entry.distance, entry.occlusion,
			entry.pitch, "  sirene" if entry.siren else ""])
	_check(spatial._vehicles.size() > 0, "voertuigen gevonden")
	_check(spatial._emitters.size() > 0, "voertuigen dichtbij hebben geluid")

	# occlusion: a point behind the first building a ray finds, and a point in the open
	var ear: Vector3 = spatial._ear
	var space := get_root().world_3d.direct_space_state
	var behind := Vector3.INF
	var open := Vector3.INF
	for ray_index in 36:
		var angle := TAU * ray_index / 36.0
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var query := PhysicsRayQueryParameters3D.create(ear + direction * 1.2, ear + direction * 80.0, 1)
		var hit := space.intersect_ray(query)
		if not hit.is_empty() and behind == Vector3.INF and ear.distance_to(hit.position) > 6.0:
			behind = (hit.position as Vector3) + direction * 25.0
		var short := PhysicsRayQueryParameters3D.create(ear + direction * 1.2, ear + direction * 12.0, 1)
		if space.intersect_ray(short).is_empty() and open == Vector3.INF:
			open = ear + direction * 10.0
	if behind != Vector3.INF:
		var occluded: float = spatial._occlusion_of(behind)
		print("achter een gebouw: afgeschermd %.2f" % occluded)
		_check(occluded > 0.3, "achter een gebouw klinkt het gedempt")
	else:
		print("geen gebouw rondom gevonden (afscherming niet getest)")
	if open != Vector3.INF:
		var clear: float = spatial._occlusion_of(open)
		print("vrij zicht: afgeschermd %.2f" % clear)
		_check(clear < 0.34, "met vrij zicht klinkt het helder")

	var survey: Dictionary = spatial.survey
	print("omgeving: ingesloten %.2f, gemiddeld %.1f m, links %.1f m, rechts %.1f m, overdekt %s" % [
		survey.enclosure, survey.mean_distance, survey.left, survey.right, survey.covered])
	var bus := AudioServer.get_bus_index(spatial.BUS_NAME)
	var delay := AudioServer.get_bus_effect(bus, 0) as AudioEffectDelay
	var reverb := AudioServer.get_bus_effect(bus, 1) as AudioEffectReverb
	_check(delay != null and reverb != null, "echo en galm op de bus")
	if delay != null and reverb != null:
		print("galm: nat %.2f, kamer %.2f, voorvertraging %.0f ms; echo links %.0f ms %.0f dB, rechts %.0f ms %.0f dB, flutter %.0f ms %.0f dB" % [
			reverb.wet, reverb.room_size, reverb.predelay_msec, delay.tap1_delay_ms, delay.tap1_level_db,
			delay.tap2_delay_ms, delay.tap2_level_db, delay.feedback_delay_ms, delay.feedback_level_db])
	print("ruimtelijk geluid ok" if _problems.is_empty() else "problemen: " + str(_problems))
	quit(0 if _problems.is_empty() else 1)


func _check(condition: bool, label: String) -> void:
	print(("ok   " if condition else "FOUT ") + label)
	if not condition:
		_problems.append(label)
