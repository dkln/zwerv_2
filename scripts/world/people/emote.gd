extends Node
## The body of someone talking (Conversations: the passer-by you talk to) moving with their
## mood, the arms and legs left alone: "boos" shakes, "blij" hops up and down quickly,
## "opgewonden" hops higher and faster, "verdrietig" leans forward and sags, "neutraal"
## nods now and then. A child of the person that moves its figure (`figure`: Pedestrian.figure,
## the rider of a chair too), going on while the game stands still (the story box pauses it);
## stop() puts the figure back as it was.
##   Emote.start(person, person.figure, "boos")
##   Emote.stop(person)

const NODE_NAME := "Emotie"
## How fast a new mood takes over (1/s).
const BLEND_RATE := 10.0
## The moods there are (pose_of; any other counts as "neutraal").
const MOODS := ["neutraal", "blij", "opgewonden", "boos", "verdrietig"]
## How fast each mood moves (radians a second in its sine): the shake and twist of anger,
## the hops of joy and of excitement, the breath of sadness, the nods of someone neutral.
const ANGRY_SHAKE := 42.0
const ANGRY_TWIST := 31.0
const HAPPY_HOPS := 9.0
const EXCITED_HOPS := 13.0
const SAD_BREATH := 1.6
const NEUTRAL_NODS := 3.0

var mood := "neutraal"
var figure: Node3D
var _rest := Transform3D.IDENTITY   # the figure's transform before
var _clock := 0.0
var _weight := 0.0


## Starts (or changes) the mood of `person`, moving `figure`.
static func start(person: Node, figure_node: Node3D, new_mood: String) -> void:
	if person == null or figure_node == null:
		return
	var emote := person.get_node_or_null(NODE_NAME) as Node
	if emote == null:
		emote = (load("res://scripts/world/people/emote.gd") as GDScript).new()
		emote.name = NODE_NAME
		emote.process_mode = Node.PROCESS_MODE_ALWAYS
		emote.figure = figure_node
		emote._rest = figure_node.transform
		person.add_child(emote)
	if emote.mood != new_mood:
		emote.mood = new_mood
		emote._clock = 0.0


## Ends it: the figure as it was.
static func stop(person: Node) -> void:
	var emote := person.get_node_or_null(NODE_NAME) if person else null
	if emote == null:
		return
	if is_instance_valid(emote.figure):
		emote.figure.transform = emote._rest
	emote.queue_free()


func _process(delta: float) -> void:
	if not is_instance_valid(figure):
		queue_free()
		return
	_clock += delta
	_weight = minf(_weight + delta * BLEND_RATE * 0.3, 1.0)
	var pose := pose_of(mood, _clock)
	var basis := Basis(Vector3.UP, float(pose.turn)) * Basis(Vector3.RIGHT, float(pose.lean) * _weight) \
		* Basis(Vector3.BACK, float(pose.sway) * _weight)
	figure.transform = Transform3D(_rest.basis * basis, _rest.origin + Vector3.UP * float(pose.lift) * _weight)


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
