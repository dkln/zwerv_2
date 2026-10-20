@tool
extends RefCounted
## Light "editor view" for a high frame rate while editing the map, owned by plugin.gd.
## On while the edited scene is a Vox Tiles scene (is_marked: metadata SCENE_META on the
## scene root, switched with the checkbox in the Build dock) and the dock's view switch
## is on "Editor" (game_view false); "Game" shows the scene with all effects, as in the
## game. The game itself (F5/F6 and exports) never uses the editor view.
## LOD and merging (scripts/level_of_detail.gd) only run in the game, in neither view.
##
## The 3D views of the editor:
## - render the voxel shaders matte, without costly detail, animation or reflections
##   (global shader parameter zwervr_editor, see materials/voxel_editor.gdshaderinc);
## - use a copy of the scene's Environment without SSAO, SSIL, SSR, SDFGI, glow, fog,
##   volumetric fog, colour adjustment and sky reflections, and an empty Compositor (no
##   motion blur), set on the editor cameras, so the scene's WorldEnvironment and
##   Compositor stay untouched;
## - render the lights of the edited scene without shadows: their shadow_enabled is
##   switched off and switched on again before the scene is saved or run
##   (restore_for_save, from plugin.gd _apply_changes), so it never ends up in the scene;
## - hide generated particles (the smoke plumes, which are not saved in the scene);
## - look orthogonally (set once when the editor view switches on or another scene is
##   opened, on the next tick because Godot restores the scene's own view state;
##   perspective again when it switches off; you can change it yourself in between).
## Every second the settings are applied again: the editor resets the shader globals
## to their project settings, saving switches the shadows back on, and the 3D views
## can get other cameras (preview, split view).

## Godot has at most four 3D views.
const VIEWPORTS := 4
## Item ids in the view menu of a 3D view (Node3DEditorViewport, Godot 4.7).
const MENU_PERSPECTIVE := 10
const MENU_ORTHOGONAL := 12
## Metadata on the scene root that marks a scene as a Vox Tiles scene.
const SCENE_META := "vox_tiles"

var _env: Environment
var _env_source: Environment     # scene Environment _env was copied from
var _compositor := Compositor.new()
var _scene: Node                 # edited scene root the settings were applied to
var _cameras: Array[Camera3D] = []
var _shadows := {}               # Light3D whose shadow was switched off -> true
var _on := false                 # editor view currently applied
var _ortho_pending := false      # switch the 3D views to orthogonal on the next refresh
## Show the scene as in the game (all effects) instead of the editor view.
var game_view := false


func _init() -> void:
	refresh()
	_tick()


## True if `root` (an edited scene root) is marked as a Vox Tiles scene.
static func is_marked(root: Node) -> bool:
	return root != null and is_instance_valid(root) and bool(root.get_meta(SCENE_META, false))


## Undoes everything; called when the plugin unloads.
func cleanup() -> void:
	_switch_off()


## Switches the shadows of the lights back on, just before the scene is saved or run.
## The next refresh switches them off again.
func restore_for_save() -> void:
	for light in _shadows:
		if is_instance_valid(light):
			light.shadow_enabled = true
	_shadows.clear()


## (Re)applies the editor view to the edited scene; called when the scene changes.
func refresh(_arg = null) -> void:
	var root := EditorInterface.get_edited_scene_root()
	if not is_marked(root) or game_view:
		_switch_off()
		return
	if _ortho_pending:
		_ortho_pending = false
		_set_projection(MENU_ORTHOGONAL)
	if not _on:
		_on = true
		_ortho_pending = true
	# the editor sets the shader globals back to their project setting (0) now and then
	if RenderingServer.global_shader_parameter_get("zwervr_editor") != 1.0:
		RenderingServer.global_shader_parameter_set("zwervr_editor", 1.0)
	if root != _scene:
		_restore_scene()
		_scene = root
		_ortho_pending = true
	var source := _scene_environment(_scene)
	if source != _env_source:
		_env_source = source
		_env = _light_environment(source)
	for i in VIEWPORTS:
		var cam := _editor_camera(i)
		if cam:
			if cam.environment != _env:
				cam.environment = _env
			if cam.compositor != _compositor:
				cam.compositor = _compositor
			if not cam in _cameras:
				_cameras.append(cam)
	if _scene:
		for n in _scene.find_children("*", "", true, false):
			if n is Light3D and (n as Light3D).shadow_enabled:
				_shadows[n] = true
				(n as Light3D).shadow_enabled = false
			elif n is GPUParticles3D and n.owner == null and (n as GPUParticles3D).visible:
				(n as GPUParticles3D).visible = false


## Applies the settings again every second while the plugin lives.
func _tick() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var ref := weakref(self)
	tree.create_timer(1.0).timeout.connect(func() -> void:
		var view = ref.get_ref()
		if view:
			view.refresh()
			view._tick())


## Camera of 3D view `i`, or null when it previews a camera of the scene (that one
## must not be changed, it is saved with the scene).
func _editor_camera(i: int) -> Camera3D:
	var cam := EditorInterface.get_editor_viewport_3d(i).get_camera_3d()
	if cam == null or cam.owner != null or (_scene and is_instance_valid(_scene) and _scene.is_ancestor_of(cam)):
		return null
	return cam


## Normal editor view: cameras, shadows, particles and shaders back as they were.
func _switch_off() -> void:
	if _on:
		_on = false
		_set_projection(MENU_PERSPECTIVE)
	for cam in _cameras:
		if is_instance_valid(cam):
			cam.environment = null
			cam.compositor = null
	_cameras.clear()
	_restore_scene()
	_scene = null
	if RenderingServer.global_shader_parameter_get("zwervr_editor") != 0.0:
		RenderingServer.global_shader_parameter_set("zwervr_editor", 0.0)


## Chooses perspective or orthogonal (menu item id) in every 3D view, through the
## view menu of the 3D view (there is no API for it).
func _set_projection(item_id: int) -> void:
	for i in VIEWPORTS:
		var n: Node = EditorInterface.get_editor_viewport_3d(i)
		while n and n.get_class() != "Node3DEditorViewport":
			n = n.get_parent()
		if n == null:
			continue
		for mb in n.find_children("*", "MenuButton", true, false):
			var popup: PopupMenu = (mb as MenuButton).get_popup()
			var index := popup.get_item_index(item_id)
			if index >= 0 and popup.is_item_radio_checkable(index):
				if not popup.is_item_checked(index):
					popup.id_pressed.emit(item_id)
				break


## Shadows and particles of the previously edited scene back as they were.
func _restore_scene() -> void:
	restore_for_save()
	if _scene == null or not is_instance_valid(_scene):
		return
	for n in _scene.find_children("*", "GPUParticles3D", true, false):
		if n.owner == null:
			(n as GPUParticles3D).visible = true


## Environment of the first WorldEnvironment in the scene, or null.
func _scene_environment(root: Node) -> Environment:
	if root == null or not is_instance_valid(root):
		return null
	if root is WorldEnvironment:
		return (root as WorldEnvironment).environment
	for n in root.find_children("*", "WorldEnvironment", true, false):
		return (n as WorldEnvironment).environment
	return null


## Copy of `source` (sky, ambient light and tonemapping as in the game) with the
## screen-space and volume effects and the sky reflections switched off.
## Without a source: null, so the editor keeps its own preview environment.
func _light_environment(source: Environment) -> Environment:
	if source == null:
		return null
	var env: Environment = source.duplicate()
	env.ssao_enabled = false
	env.ssil_enabled = false
	env.ssr_enabled = false
	env.sdfgi_enabled = false
	env.glow_enabled = false
	env.fog_enabled = false
	env.volumetric_fog_enabled = false
	env.adjustment_enabled = false
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	return env
