extends Node
## Day and night cycle (the "Dagcyclus" node of the world scene): rotates and colours
## the sun, dims the fill light and the ambient light, colours the procedural sky and
## sets the global shader parameters the voxel shaders read:
## `zwervr_night` (0 = day, 1 = night; brightens emissive voxels) and
## `zwervr_sky_top` / `zwervr_sky_horizon` (sky colours reflected by glass).
##
## The day is a Dutch summer day (SUNRISE 5:30, SUNSET 22:00): long light evenings, a blue
## hour until late, only a few hours of real dark. The colours follow the moment of the day
## (DAY_COLOURS): the blue hour, a red-orange sunrise, the golden hours, white light at
## midday, a red sunset under a violet sky, a deep blue night with moonlight; between those
## moments they blend smoothly.
##
## The shadow-casting sun stays between `min_elevation` and `max_elevation` degrees
## above the horizon, so shadows never become extremely long; the time of day mainly
## drives the colours and the brightness.
## Indoors (Interiors sets `indoors` while the player is in a building) there is no day and
## night: the clock runs on, but the light stays that of INDOOR_HOUR (sun, fill, ambient, sky
## and the shader globals), the same day and night; going out applies the real hour again.
## Next to itself it makes the street lights (StreetLights, "Straatverlichting"): at night the
## lamps of the Props layer light the street.

const IsoView = preload("res://scripts/camera/iso_camera.gd")

@export_range(0.0, 24.0) var time_of_day := 6.0        ## hour of the day (the game starts at six in the morning; the main menu sets its own)
## Hours per second (0 = standing still), before the two factors below.
@export var speed := 0.08
## The light lasts long: by day the clock runs `daylight_slowdown` times slower, in the dark
## `night_speedup` times faster, blended by how dark it is (`night`). At speed 0.08 that is
## about 11 minutes of light (6 to 21 h) and 1.5 minutes of dusk and dark: ~12.5 minutes a day.
@export var daylight_slowdown := 4.0
@export var night_speedup := 1.6
## Hours the clock must have moved before the light is set again: the sky is baked anew on
## every change of its colours, so not every frame (0.02 h = four times a second at 0.08).
const APPLY_STEP_HOURS := 0.02
@export_range(10.0, 80.0) var min_elevation := 36.0     ## degrees; sun elevation at sunrise/sunset, prevents long shadows
@export_range(30.0, 89.0) var max_elevation := 44.0     ## degrees; sun elevation at midday
@export var sun_path := NodePath("../Zon")
@export var fill_light_path := NodePath("../Vullicht")
@export var environment_path := NodePath("../Omgeving")

## How dark it is now: 0 = day, 1 = night (the same as the shader global zwervr_night),
## for scripts that switch lights on (vehicle headlights, scripts/vehicles/vehicle.gd).
var night := 0.0
## The player is inside a building: the light stays at INDOOR_HOUR (see set_indoors).
var indoors := false
## The hour whose light the interiors always have (the light they were made in).
const INDOOR_HOUR := 13.0

## A Dutch summer day (late June in The Hague): sunrise and sunset (hours).
const StreetLights = preload("res://scripts/world/street_lights.gd")

const SUNRISE := 5.5
const SUNSET := 22.0
## The colours of the day at these hours, blended smoothly between them: the sun (colour,
## energy), the fill light from the other side (by day sky light, at night the moon), the
## ambient light and the background, the sky (top, horizon) and how dark it counts as
## (night: lit windows, lamps and signs).
const DAY_COLOURS := [
	[0.0, {"sun": Color("#FFB070"), "sun_energy": 0.0, "fill": Color("#7F95E6"), "fill_energy": 0.24,
		"ambient": 0.34, "background": 0.28, "sky_top": Color("#070B22"), "horizon": Color("#141A38"), "night": 1.0}],
	# the blue hour before sunrise (it barely gets dark: from half past three it greys)
	[4.4, {"sun": Color("#FF9A6A"), "sun_energy": 0.0, "fill": Color("#8A9CE8"), "fill_energy": 0.26,
		"ambient": 0.4, "background": 0.42, "sky_top": Color("#1A2556"), "horizon": Color("#4A4F86"), "night": 0.9}],
	# sunrise: low red-orange sun, a pink horizon
	[5.5, {"sun": Color("#FF8A55"), "sun_energy": 0.75, "fill": Color("#A8A8E0"), "fill_energy": 0.3,
		"ambient": 0.5, "background": 0.62, "sky_top": Color("#46609E"), "horizon": Color("#F29A78"), "night": 0.55}],
	# the golden hour of the morning
	[6.8, {"sun": Color("#FFC488"), "sun_energy": 1.25, "fill": Color("#AFC0EC"), "fill_energy": 0.38,
		"ambient": 0.66, "background": 0.85, "sky_top": Color("#5E8ACB"), "horizon": Color("#F4CFA8"), "night": 0.1}],
	[9.0, {"sun": Color("#FFEEDC"), "sun_energy": 1.5, "fill": Color("#A6C0F0"), "fill_energy": 0.44,
		"ambient": 0.78, "background": 1.0, "sky_top": Color("#4A82CE"), "horizon": Color("#BBD5EE"), "night": 0.0}],
	# midday: white light, the deepest blue sky
	[13.7, {"sun": Color("#FFF8EE"), "sun_energy": 1.6, "fill": Color("#9FBCF2"), "fill_energy": 0.45,
		"ambient": 0.82, "background": 1.0, "sky_top": Color("#3C78CC"), "horizon": Color("#B2D0F0"), "night": 0.0}],
	[18.0, {"sun": Color("#FFEBD2"), "sun_energy": 1.5, "fill": Color("#A3BEF0"), "fill_energy": 0.44,
		"ambient": 0.78, "background": 1.0, "sky_top": Color("#4580CC"), "horizon": Color("#C4D6EC"), "night": 0.0}],
	# the long golden evening
	[20.4, {"sun": Color("#FFB86E"), "sun_energy": 1.2, "fill": Color("#B3B9E4"), "fill_energy": 0.38,
		"ambient": 0.64, "background": 0.85, "sky_top": Color("#5577BC"), "horizon": Color("#F5BC86"), "night": 0.1}],
	# sunset: a deep red sun, an orange-red horizon under violet
	[21.9, {"sun": Color("#FF6A3C"), "sun_energy": 0.7, "fill": Color("#B49ADB"), "fill_energy": 0.3,
		"ambient": 0.5, "background": 0.62, "sky_top": Color("#3D3F86"), "horizon": Color("#E8704E"), "night": 0.5}],
	# the blue hour after sunset: violet horizon, the windows on
	[22.7, {"sun": Color("#FF6A3C"), "sun_energy": 0.0, "fill": Color("#8C92E2"), "fill_energy": 0.27,
		"ambient": 0.42, "background": 0.44, "sky_top": Color("#1B2260"), "horizon": Color("#5A4886"), "night": 0.88}],
	[23.6, {"sun": Color("#FFB070"), "sun_energy": 0.0, "fill": Color("#7F95E6"), "fill_energy": 0.24,
		"ambient": 0.35, "background": 0.3, "sky_top": Color("#0A0F2A"), "horizon": Color("#171D3E"), "night": 1.0}],
	[24.0, {"sun": Color("#FFB070"), "sun_energy": 0.0, "fill": Color("#7F95E6"), "fill_energy": 0.24,
		"ambient": 0.34, "background": 0.28, "sky_top": Color("#070B22"), "horizon": Color("#141A38"), "night": 1.0}],
]


## The colours at `hour`: those of the two moments of DAY_COLOURS round it, blended with an
## ease (smoothstep) so no change of colour has a corner.
static func _colours_at(hour: float) -> Dictionary:
	for index in range(1, DAY_COLOURS.size()):
		var later: Array = DAY_COLOURS[index]
		if hour <= later[0]:
			var earlier: Array = DAY_COLOURS[index - 1]
			var share := smoothstep(0.0, 1.0, (hour - earlier[0]) / maxf(later[0] - earlier[0], 0.0001))
			var blended := {}
			for key: String in earlier[1]:
				var from: Variant = earlier[1][key]
				var to: Variant = later[1][key]
				blended[key] = (from as Color).lerp(to, share) if from is Color else lerpf(from, to, share)
			return blended
	return (DAY_COLOURS[-1] as Array)[1]

var _sun: DirectionalLight3D
var _fill: DirectionalLight3D
var _env: Environment
var _sky: ProceduralSkyMaterial
var _applied_at := -100.0            # time_of_day when the light was last set


func _ready() -> void:
	_sun = get_node_or_null(sun_path)
	_fill = get_node_or_null(fill_light_path)
	var we := get_node_or_null(environment_path) as WorldEnvironment
	if we:
		_env = we.environment
		if _env and _env.sky:
			_sky = _env.sky.sky_material as ProceduralSkyMaterial
	_apply()
	if get_parent().has_node("Props") and not get_parent().has_node("Straatverlichting"):
		var street_lights := StreetLights.new()
		street_lights.name = "Straatverlichting"
		get_parent().add_child.call_deferred(street_lights)


## Advances the clock by `speed` hours per second (slower by day, faster in the dark;
## wrapping at 24) and reapplies.
func _process(delta: float) -> void:
	if speed == 0.0:
		return
	var pace := lerpf(1.0 / maxf(daylight_slowdown, 0.01), night_speedup, night)
	time_of_day = fposmod(time_of_day + delta * speed * pace, 24.0)
	if absf(time_of_day - _applied_at) >= APPLY_STEP_HOURS:
		if indoors:
			# no change of light inside; only `night` (the pace of the clock) follows the hour
			_applied_at = time_of_day
			night = _colours_at(time_of_day)["night"]
		else:
			_apply()


## Sets the clock to `hour` (any value, wrapped to 0..24) and applies it at once.
func set_time(hour: float) -> void:
	time_of_day = fposmod(hour, 24.0)
	_apply()


## Inside a building (on) the light stops following the clock and stays that of INDOOR_HOUR;
## outside again (off) the light of the real hour comes back at once.
func set_indoors(on: bool) -> void:
	indoors = on
	_apply()


## Applies `time_of_day` (indoors: INDOOR_HOUR) to the sun, fill light, environment, sky and shader globals.
func _apply() -> void:
	if _sun == null:
		return
	_applied_at = time_of_day
	var lit_hour := INDOOR_HOUR if indoors else time_of_day
	# a Dutch summer day: sunrise (east) at SUNRISE, highest about 13:45, sunset (west) at SUNSET
	var day := clampf((lit_hour - SUNRISE) / (SUNSET - SUNRISE), 0.0, 1.0)
	var true_elevation := sin(day * PI)               # 0 at the horizon, 1 at midday
	# brightness 0..1 of the sun: full from ~1/3 elevation, none while it is down
	var light := clampf(true_elevation * 3.0, 0.0, 1.0) if lit_hour > SUNRISE and lit_hour < SUNSET else 0.0
	# rotation around the vertical axis: 90 = light from the east, 0 = from the south.
	# The sun stays on the right of the camera's view, so the shadows fall to the left in the
	# picture (at the start, 13:00, straight to the left and a little up; in the morning a
	# little down, in the evening more up) and one of the two facades it sees stays lit; it
	# turns with the camera (iso_camera.gd ROTATION.y).
	var azimuth := lerpf(145.0, 90.0, day) + IsoView.ROTATION.y - 45.0
	var elevation := lerpf(min_elevation, max_elevation, true_elevation)
	_sun.rotation_degrees = Vector3(-elevation, azimuth, 0.0)
	# the colours of this moment, blended between the moments of DAY_COLOURS
	var look := _colours_at(lit_hour)
	_sun.light_color = look["sun"]
	_sun.light_energy = look["sun_energy"] * clampf(light * 4.0, 0.0, 1.0)
	_sun.shadow_enabled = _sun.light_energy > 0.05
	# `night` is the real dark (the pace of the clock, the street lights, headlights); the
	# shaders get that of the light shown (indoors: none)
	night = _colours_at(time_of_day)["night"] if indoors else look["night"]
	RenderingServer.global_shader_parameter_set("zwervr_night", look["night"])
	if _fill:
		_fill.light_energy = look["fill_energy"]
		_fill.light_color = look["fill"]
	if _env:
		_env.ambient_light_energy = look["ambient"]
		_env.background_energy_multiplier = look["background"]
	if _sky:
		_sky.sky_top_color = look["sky_top"]
		_sky.sky_horizon_color = look["horizon"]
		_sky.ground_horizon_color = look["horizon"]
		_sky.ground_bottom_color = (look["horizon"] as Color).lerp(look["sky_top"], 0.5).darkened(0.3)
		# glass reflects the same sky (voxel_glass.gdshader)
		RenderingServer.global_shader_parameter_set("zwervr_sky_top", _sky.sky_top_color.lightened(0.1))
		RenderingServer.global_shader_parameter_set("zwervr_sky_horizon", _sky.sky_horizon_color)
