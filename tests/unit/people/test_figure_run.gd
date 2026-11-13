extends RefCounted
## Unit tests of townspeople running (scripts/world/people/townsfolk_figure.gd walk with `run`): the
## run of the player (PlayerModel._run_pose) blended into their walk by their speed: the
## knee driven high, the body leant forward and bobbing higher, upright again after it.


func _figure() -> TownsfolkFigure:
	return TownsfolkFigure.create(TownsfolkFigure.look_for(7))


## How far forward (degrees) the thigh of `side` points (0: straight down).
func _thigh_forward(figure: TownsfolkFigure, side: String) -> float:
	var joint: Node3D = figure.get("_joints")["thigh_" + side]
	var down := joint.transform.basis * Vector3.DOWN
	return rad_to_deg(atan2(down.z, -down.y))


## Walking pace is no running, the paces of a conductor or an evictor are, and a running
## stride is longer than a step.
func test_who_runs_and_how_long_a_step_is(test) -> void:
	test.check(TownsfolkFigure.run_share(1.35) == 0.0, "wandelen (1,35 m/s) is geen rennen")
	test.check(TownsfolkFigure.run_share(4.6) == 1.0, "de conducteur erachteraan (4,6 m/s) rent")
	test.check(TownsfolkFigure.run_share(3.6) == 1.0, "wie je eruit komt zetten (3,6 m/s) rent")
	test.check(TownsfolkFigure.stride_at(1.0) > TownsfolkFigure.stride_at(0.0), "een renpas is langer dan een stap")


## Running, a townsperson's knee comes much higher, the body leans forward and bobs
## higher than when walking, and it is upright again after.
func test_the_run_of_the_player_in_their_walk(test) -> void:
	var figure := _figure()
	var walk_most := 0.0
	var run_most := 0.0
	var walk_bob := 0.0
	var run_bob := 0.0
	var body: Node3D = figure.get("_body")
	for step in 32:
		var phase := TAU * step / 32.0
		figure.walk(phase, 1.0, 0.0)
		walk_most = maxf(walk_most, _thigh_forward(figure, "left"))
		walk_bob = maxf(walk_bob, body.position.y)
		figure.walk(phase, 1.0, 1.0)
		run_most = maxf(run_most, _thigh_forward(figure, "left"))
		run_bob = maxf(run_bob, body.transform.origin.y)
	test.check(run_most > walk_most + 20.0, "de knie veel hoger dan bij lopen (%.0f tegen %.0f graden)" % [run_most, walk_most])
	figure.walk(0.5, 1.0, 1.0)
	var leaning := (body.transform.basis * Vector3.UP).z
	test.check(leaning > 0.1, "het lijf voorover (%.2f)" % leaning)
	test.check(run_bob > walk_bob, "en het veert hoger (%.3f tegen %.3f m)" % [run_bob, walk_bob])
	figure.walk(0.5, 1.0, 0.0)
	test.check(body.transform.basis.is_equal_approx(Basis.IDENTITY), "na het rennen weer rechtop")
	figure.walk(0.0, 0.0)
	test.check(absf(_thigh_forward(figure, "left")) < 0.01 and absf(_thigh_forward(figure, "right")) < 0.01, "stilstaan: de benen recht")
	figure.free()
