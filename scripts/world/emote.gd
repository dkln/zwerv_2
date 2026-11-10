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
		emote = (load("res://scripts/world/emote.gd") as GDScript).new()
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
	var lift := 0.0
	var lean := 0.0       # radians forward
	var sway := 0.0       # radians to the side
	var turn := 0.0
	match mood:
		"boos":
			sway = sin(_clock * 42.0) * deg_to_rad(5.0)
			turn = sin(_clock * 31.0) * deg_to_rad(4.0)
			lean = deg_to_rad(6.0)
		"blij":
			lift = absf(sin(_clock * 9.0)) * 0.12
		"opgewonden":
			lift = absf(sin(_clock * 13.0)) * 0.2
			sway = sin(_clock * 13.0) * deg_to_rad(4.0)
		"verdrietig":
			lean = deg_to_rad(16.0) + sin(_clock * 1.6) * deg_to_rad(2.0)
			lift = -0.04
		_:
			lean = maxf(sin(_clock * 3.0), 0.0) * deg_to_rad(6.0)
	var basis := Basis(Vector3.UP, turn) * Basis(Vector3.RIGHT, lean * _weight) * Basis(Vector3.BACK, sway * _weight)
	figure.transform = Transform3D(_rest.basis * basis, _rest.origin + Vector3.UP * lift * _weight)
