extends "res://tests/integration/support/town_test.gd"
## What the crowd round the player costs on the CPU (headless): the town at the morning rush
## (08:00, the most vehicles and people: Traffic, Pedestrians, data/drukte.json), measured as
## the real time a frame takes (wall clock) over FRAMES frames after it filled up. It must stay
## under FRAME_BUDGET_MS, and the town must really be full (most of the vehicles and people
## wanted are there), so a slow spawner or a lookup over every vehicle shows up here.
## (The monitors TIME_PROCESS / TIME_PHYSICS_PROCESS are not used: headless they are no
## measure of what a frame costs.) A measurement on the clock of the whole town as the game
## starts it (nothing left out but the story), so a run of its own.
##   tests/run_integration_tests.sh traffic_cost [-- <hour, default 8>]

const FRAMES := 300
const FRAME_BUDGET_MS := 16.0
const DEFAULT_HOUR := "8"


static func world_options() -> Dictionary:
	return {"own_process": true, "character": "jos", "traffic": true, "wake": false, "without": ["Verhaal"],
		"settings": {
			"Verkeer": {"unseen_without_camera": true},
			"Voetgangers": {"unseen_without_camera": true},
			"Dagcyclus": {"speed": 0.0, "time_of_day": float(Common.arg(1, DEFAULT_HOUR))}}}


## `count` frames on, nothing holding the town still meanwhile.
func _unpaused_frames(count: int) -> void:
	for frame_index in count:
		tree.paused = false
		await tree.process_frame


## The town at the hour asked, filled up: most of the vehicles and people wanted are there
## and a frame stays within the budget (wall clock, averaged over FRAMES frames).
func test_full_town_stays_within_the_frame_budget(test) -> void:
	var hour := float(argument(0, DEFAULT_HOUR))
	var traffic: Traffic = scene.get_node("Verkeer")
	var walkers: Pedestrians = scene.get_node("Voetgangers")
	for frame_index in 900:
		await _unpaused_frames(1)
		if frame_index > 120 and player._placed:
			break
	await _unpaused_frames(240)
	var started := Time.get_ticks_usec()
	await _unpaused_frames(FRAMES)
	var frame_ms := (Time.get_ticks_usec() - started) / 1000.0 / FRAMES
	var wanted: Vector2i = traffic.wanted_counts()
	print("%02.0f:00: %d voertuigen (gewenst %d + %d), %d voetgangers (gewenst %d), een beeld %.1f ms" % [hour,
			traffic._town.size(), wanted.x, wanted.y, walkers.people().size(), walkers.wanted_count(), frame_ms])
	test.check(traffic._town.size() >= wanted.x * 0.8, "de stad vol verkeer (%d van %d)" % [traffic._town.size(), wanted.x])
	test.check(walkers.people().size() >= walkers.wanted_count() * 0.8, "en vol mensen (%d van %d)" % [walkers.people().size(), walkers.wanted_count()])
	test.check(frame_ms < FRAME_BUDGET_MS, "een beeld binnen %.0f ms (%.1f ms)" % [FRAME_BUDGET_MS, frame_ms])
