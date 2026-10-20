@tool
extends RefCounted
## Surroundings for map parts in the editor, owned by plugin.gd. A part of a map that is
## stored in parts (scripts/world_parts.gd) holds only the four GridMap layers; the
## environment, sun, fill light, tint map (with its tint areas), ground map and smoke live in the
## tour scene named by the part's PREVIEW_META metadata. While such a part is edited,
## copies of those nodes are added to it without owner: they are rendered and work as
## in the tour scene (tint, smoke and the editor/game view of editor_view.gd), but are
## never saved in the part and don't show in the scene tree. Edit them in the tour scene.

## Metadata on a part root: path of the scene whose surroundings it is shown with.
const PREVIEW_META := "preview_scene"

var _scene: Node            # edited scene root the copies were added to
var _nodes: Array[Node] = []


## Adds the surroundings to the edited scene, or removes them when another scene is
## edited; called when the scene changes.
func refresh(_arg = null) -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == _scene and (root == null or _nodes.all(func(n): return is_instance_valid(n))):
		return
	cleanup()
	if root == null or not root.has_meta(PREVIEW_META):
		return
	var path: String = root.get_meta(PREVIEW_META)
	if not ResourceLoader.exists(path):
		return
	_scene = root
	var source := (load(path) as PackedScene).instantiate()
	for n in source.get_children():
		if _wanted(n) and not root.has_node(NodePath(n.name)):
			for k in [n] + n.find_children("*", "", true, false):
				k.owner = null
			source.remove_child(n)
			root.add_child(n)   # no owner: not saved, not in the scene tree dock
			_nodes.append(n)
	source.free()


## Removes the surroundings again (also when the plugin unloads).
func cleanup() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.get_parent().remove_child(n)
			n.queue_free()
	_nodes.clear()
	_scene = null


## Nodes of the tour scene that belong to the surroundings: environment, lights, and
## the tint map and smoke (both @tool, so they work in the editor).
func _wanted(n: Node) -> bool:
	return n is WorldEnvironment or n is DirectionalLight3D or n.name in ["TintKaart", "GrondKaart", "Rook"]
