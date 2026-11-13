extends "res://tests/integration/support/town_test.gd"
## A train in Den Haag Centraal runs into who is on its track (StationTrain._hit_who_is_in_the_way),
## as a vehicle in the town does (hit_by_moving): the player on the rails is knocked over and
## hurt, a traveller fallen onto the rails too (a ragdoll, then taken away); someone on the
## platform beside it is left alone.
##   tests/run_integration_tests.sh station_train_hit

## Metres before where the nose of the train stops that the player is put on the rails.
const AHEAD_OF_THE_STOP := 6.0
## Seconds of game time a train gets to come in and reach who is on its track.
const TRAIN_SECONDS := 20.0


## Into the station, and a train of it made to come in on its track from outside the hall
## (null if the station has no train).
func _train_coming_in() -> StationTrain:
	await enter("centraal")
	await frames(30)
	var station: Node3D = interiors.interior_of("centraal")
	if not await wait_until(func() -> bool: return not station.trains().is_empty(), 10.0):
		return null
	var train: StationTrain = station.trains()[0]
	train.state = "weg"
	train.come_in()
	return train


## A traveller with nowhere to go, put at `at` in the space of `train` (x across its
## track, z along it).
func _traveller_at(train: StationTrain, at: Vector3) -> StationPerson:
	var station: Node3D = interiors.interior_of("centraal")
	var traveller: StationPerson = station.call("_spawn", "reiziger", station.to_local(train.to_global(at)))
	traveller.steps.clear()
	return traveller


## Takes `traveller` out of the station again (if the game has not done so already).
func _take_away(traveller: StationPerson) -> void:
	if is_instance_valid(traveller):
		interiors.interior_of("centraal").station_people().erase(traveller)
		traveller.queue_free()


## Where the player is put on the rails before the nose of a train coming in (z along its track).
func _ahead() -> float:
	return StationTrain.Layout.STOP_NOSE_Z + AHEAD_OF_THE_STOP


## The player standing on the rails before a train coming in is knocked over and hurt.
func test_player_on_the_rails_is_hit_and_hurt(test) -> void:
	var train := await _train_coming_in()
	test.check(train != null, "een trein komt binnen")
	if train == null:
		return
	player.teleport(train.to_global(Vector3(0.0, 0.0, _ahead())), 0.0)
	var health_before: float = player._stats.gezondheid.x
	var player_hit := await wait_until(func() -> bool: return player._ragdoll != null, TRAIN_SECONDS)
	test.check(player_hit, "de speler op het spoor wordt aangereden")
	var health_after: float = player._stats.gezondheid.x
	test.check(health_after < health_before, "en raakt gewond (%.0f naar %.0f)" % [health_before, health_after])


## A traveller on the rails before a train coming in is knocked over too (a ragdoll).
func test_traveller_on_the_rails_is_hit(test) -> void:
	var train := await _train_coming_in()
	test.check(train != null, "een trein komt binnen")
	if train == null:
		return
	var on_rails := _traveller_at(train, Vector3(0.4, 0.0, _ahead() - 3.0))
	var traveller_hit := await wait_until(func() -> bool: return is_instance_valid(on_rails) and on_rails._ragdoll != null, TRAIN_SECONDS)
	test.check(traveller_hit, "een reiziger op het spoor wordt aangereden")
	_take_away(on_rails)


## Someone standing on the platform beside the track is left alone by the train going past.
func test_who_stands_on_the_platform_is_left_alone(test) -> void:
	var train := await _train_coming_in()
	test.check(train != null, "een trein komt binnen")
	if train == null:
		return
	var on_platform := _traveller_at(train, Vector3(train._width * 0.5 + 1.2, 1.375, _ahead()))
	var came_past := await wait_until(func() -> bool: return train.nose_z <= _ahead() - 1.0 or train.state != "binnenkomend", TRAIN_SECONDS)
	await seconds(0.5)
	test.check(came_past, "de trein rijdt langs wie op het perron staat")
	test.check(is_instance_valid(on_platform) and on_platform._ragdoll == null, "wie op het perron staat wordt niet aangereden")
	_take_away(on_platform)
