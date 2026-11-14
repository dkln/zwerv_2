extends Node
## The body of someone talking (Conversations: the passer-by you talk to) moving with their
## mood, the arms and legs left alone: "boos" shakes, "blij" hops up and down quickly,
## "opgewonden" hops higher and faster, "verdrietig" leans forward and sags, "neutraal"
## nods now and then. A child of the person that moves its figure (`figure`: Pedestrian.figure,
## the rider of a chair too), going on while the game stands still (the story box pauses it);
## stop() puts the figure back as it was.
## Behaviour (docs/CODE_LAGEN.md); how the body stands in each mood: emote_rules.gd.
##   Emote.start(person, person.figure, "boos")
##   Emote.stop(person)

const EmoteRules = preload("res://scripts/world/people/emote_rules.gd")
const NODE_NAME := "Emotie"
const BLEND_RATE := EmoteRules.BLEND_RATE
const MOODS := EmoteRules.MOODS
const ANGRY_SHAKE := EmoteRules.ANGRY_SHAKE
const ANGRY_TWIST := EmoteRules.ANGRY_TWIST
const HAPPY_HOPS := EmoteRules.HAPPY_HOPS
const EXCITED_HOPS := EmoteRules.EXCITED_HOPS
const SAD_BREATH := EmoteRules.SAD_BREATH
const NEUTRAL_NODS := EmoteRules.NEUTRAL_NODS

var mood := EmoteRules.DEFAULT_MOOD
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
	_weight = EmoteRules.weight_after(_weight, delta)
	figure.transform = EmoteRules.figure_transform(_rest, pose_of(mood, _clock), _weight)


## The body in `mood_name` at `time` seconds into it (EmoteRules.pose_of).
static func pose_of(mood_name: String, time: float) -> Dictionary:
	return EmoteRules.pose_of(mood_name, time)
