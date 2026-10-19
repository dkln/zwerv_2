@tool
class_name MotionBlur
extends CompositorEffect
## Motion blur compositor effect (Godot doesn't have this built in).
##
## Runs a compute shader (motion_blur.glsl) after the transparent pass that
## averages each pixel's colour along its motion vector, so a still image stays sharp
## and only movement (mostly the camera flying during the tour) gets streaks.
## Two dispatches per view: pass 0 copies the colour buffer into a helper texture,
## pass 1 blurs from that copy back into the colour buffer.
## Attach it to the Compositor of the WorldEnvironment or the camera (the world scene
## uses the WorldEnvironment's Compositor).

## 1 = the motion of one frame; higher = longer streaks.
@export_range(0.0, 4.0) var strength := 0.5
## Maximum streak length as a fraction of the image width (prevents smears on camera jumps).
@export_range(0.0, 0.2) var max_length := 0.015
## Number of colour samples along the streak.
@export_range(4, 32) var samples := 12

var _rd: RenderingDevice
var _shader: RID
var _pipeline: RID
var _sampler: RID
## Helper texture with a copy of the colour buffer (RGBA16F), recreated on resize.
var _copy: RID
var _copy_size := Vector2i.ZERO


## Requests motion vectors and creates the GPU resources on the render thread.
func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	needs_motion_vectors = true
	RenderingServer.call_on_render_thread(_create)


## Frees the GPU resources when the effect is deleted.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _rd:
		for rid in [_copy, _sampler, _pipeline, _shader]:
			if rid.is_valid():
				_rd.free_rid(rid)


## Render thread: compiles the compute shader and creates the pipeline and a
## linear clamp-to-edge sampler. Leaves `_pipeline` invalid on failure (effect disabled).
func _create() -> void:
	_rd = RenderingServer.get_rendering_device()
	if _rd == null:
		return
	var file: RDShaderFile = load("res://scripts/effects/motion_blur.glsl")
	_shader = _rd.shader_create_from_spirv(file.get_spirv())
	if not _shader.is_valid():
		return
	_pipeline = _rd.compute_pipeline_create(_shader)
	var s := RDSamplerState.new()
	s.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	s.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	s.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	s.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	_sampler = _rd.sampler_create(s)


## Render thread, once per viewport per frame: (re)creates the copy texture at the
## internal render size and dispatches both passes for every view.
func _render_callback(type: int, render_data: RenderData) -> void:
	if _rd == null or not _pipeline.is_valid() or type != EFFECT_CALLBACK_TYPE_POST_TRANSPARENT or strength <= 0.0:
		return
	var buffers := render_data.get_render_scene_buffers() as RenderSceneBuffersRD
	if buffers == null:
		return
	var size := buffers.get_internal_size()
	if size.x == 0 or size.y == 0:
		return
	if size != _copy_size:
		if _copy.is_valid():
			_rd.free_rid(_copy)
		var f := RDTextureFormat.new()
		f.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
		f.width = size.x
		f.height = size.y
		f.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
		_copy = _rd.texture_create(f, RDTextureView.new())
		_copy_size = size
	# work groups of 8x8 pixels (local_size in the shader), rounded up
	var groups := Vector2i((size.x - 1) / 8 + 1, (size.y - 1) / 8 + 1)
	for view in buffers.get_view_count():
		var color := buffers.get_color_layer(view)
		var velocity := buffers.get_velocity_layer(view)
		var uniform_set := UniformSetCacheRD.get_cache(_shader, 0, [
			_uniform(RenderingDevice.UNIFORM_TYPE_IMAGE, 0, [color]),
			_uniform(RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE, 1, [_sampler, _copy]),
			_uniform(RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE, 2, [_sampler, velocity]),
			_uniform(RenderingDevice.UNIFORM_TYPE_IMAGE, 3, [_copy]),
		])
		for pass_index in 2:
			# push constant layout of Params in the shader (8 floats, last two padding)
			var params := PackedFloat32Array([size.x, size.y, strength, max_length, samples, pass_index, 0.0, 0.0])
			var list := _rd.compute_list_begin()
			_rd.compute_list_bind_compute_pipeline(list, _pipeline)
			_rd.compute_list_bind_uniform_set(list, uniform_set, 0)
			_rd.compute_list_set_push_constant(list, params.to_byte_array(), params.size() * 4)
			_rd.compute_list_dispatch(list, groups.x, groups.y, 1)
			_rd.compute_list_end()


## Builds an RDUniform of `type` at `binding` with the given RIDs.
func _uniform(type: int, binding: int, ids: Array) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = type
	u.binding = binding
	for id in ids:
		u.add_id(id)
	return u
