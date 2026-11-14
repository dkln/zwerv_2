extends RefCounted
## The moods of someone talking, worked out (logic; docs/CODE_LAGEN.md): how the body stands
## in each mood at each moment, how fast a mood takes over, and the transform of the figure
## that gives. The node that moves the figure: emote.gd.
##   const EmoteRules = preload("res://scripts/world/people/emote_rules.gd")

## How fast a new mood takes over (1/s), and the share of it that counts each second.
const BLEND_RATE := 10.0
const BLEND_SHARE := 0.3
## The moods there are (pose_of; any other counts as "neutraal").
const MOODS := ["neutraal", "blij", "opgewonden", "boos", "verdrietig"]
const DEFAULT_MOOD := "neutraal"
## How fast each mood moves (radians a second in its sine): the shake and twist of anger,
## the hops of joy and of excitement, the breath of sadness, the nods of someone neutral.
const ANGRY_SHAKE := 42.0
const ANGRY_TWIST := 31.0
const HAPPY_HOPS := 9.0
const EXCITED_HOPS := 13.0
const SAD_BREATH := 1.6
const NEUTRAL_NODS := 3.0


## The body in `mood_name` at `time` seconds into it: {"lift" (metres up), "lean" (radians
## forward), "sway" (radians to the side), "turn" (radians round)}; each mood a function of
## its own below (MOODS), an unknown one as "neutraal".
static func pose_of(mood_name: String, time: float) -> Dictionary:
	var pose := {"lift": 0.0, "lean": 0.0, "sway": 0.0, "turn": 0.0}
	match mood_name:
		"boos":
			pose.merge(_angry(time), true)
		"blij":
			pose.merge(_happy(time), true)
		"opgewonden":
			pose.merge(_excited(time), true)
		"verdrietig":
			pose.merge(_sad(time), true)
		_:
			pose.merge(_neutral(time), true)
	return pose


## How much of the mood shows (0..1) `delta` seconds later.
static func weight_after(weight: float, delta: float) -> float:
	return minf(weight + delta * BLEND_RATE * BLEND_SHARE, 1.0)


## The transform of a figure that stood as `rest`, in `pose` (pose_of) for `weight` (0..1):
## the turn whole, the lean, the sway and the lift by the weight.
static func figure_transform(rest: Transform3D, pose: Dictionary, weight: float) -> Transform3D:
	var basis := Basis(Vector3.UP, float(pose.turn)) * Basis(Vector3.RIGHT, float(pose.lean) * weight) \
		* Basis(Vector3.BACK, float(pose.sway) * weight)
	return Transform3D(rest.basis * basis, rest.origin + Vector3.UP * float(pose.lift) * weight)


## "boos": shaking with anger, quick and small, leant in a little.
static func _angry(time: float) -> Dictionary:
	return {"sway": sin(time * ANGRY_SHAKE) * deg_to_rad(5.0), "turn": sin(time * ANGRY_TWIST) * deg_to_rad(4.0),
		"lean": deg_to_rad(6.0)}


## "blij": hopping up and down quickly.
static func _happy(time: float) -> Dictionary:
	return {"lift": absf(sin(time * HAPPY_HOPS)) * 0.12}


## "opgewonden": hopping higher and faster, swaying with it.
static func _excited(time: float) -> Dictionary:
	return {"lift": absf(sin(time * EXCITED_HOPS)) * 0.2, "sway": sin(time * EXCITED_HOPS) * deg_to_rad(4.0)}


## "verdrietig": leant forward and sagging, slowly breathing.
static func _sad(time: float) -> Dictionary:
	return {"lean": deg_to_rad(16.0) + sin(time * SAD_BREATH) * deg_to_rad(2.0), "lift": -0.04}


## "neutraal": a nod now and then.
static func _neutral(time: float) -> Dictionary:
	return {"lean": maxf(sin(time * NEUTRAL_NODS), 0.0) * deg_to_rad(6.0)}
