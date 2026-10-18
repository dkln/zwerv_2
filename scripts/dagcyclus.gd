extends Node
## Basis voor dag en nacht: draait de zon, kleurt het licht en de lucht en dimt
## het omgevingslicht. De schaduwwerpende zon blijft minimaal `min_hoogte` graden
## boven de horizon, zodat schaduwen nooit extreem lang worden.

@export_range(0.0, 24.0) var tijd := 13.0          ## uur van de dag
@export var snelheid := 0.0                         ## uren per seconde (0 = stilstaand)
@export_range(10.0, 80.0) var min_hoogte := 36.0     ## graden; voorkomt lange schaduwen
@export_range(30.0, 89.0) var max_hoogte := 44.0
@export var zon_pad := NodePath("../Zon")
@export var vul_pad := NodePath("../Vullicht")
@export var omgeving_pad := NodePath("../Omgeving")

var _zon: DirectionalLight3D
var _vul: DirectionalLight3D
var _env: Environment
var _lucht: ProceduralSkyMaterial


func _ready() -> void:
	_zon = get_node_or_null(zon_pad)
	_vul = get_node_or_null(vul_pad)
	var we := get_node_or_null(omgeving_pad) as WorldEnvironment
	if we:
		_env = we.environment
		if _env and _env.sky:
			_lucht = _env.sky.sky_material as ProceduralSkyMaterial
	_pas_toe()


func _process(delta: float) -> void:
	if snelheid == 0.0:
		return
	tijd = fposmod(tijd + delta * snelheid, 24.0)
	_pas_toe()


func _pas_toe() -> void:
	if _zon == null:
		return
	# 6:00 zonsopkomst (oost), 12:00 zuid, 18:00 ondergang (west)
	var dag := clampf((tijd - 6.0) / 12.0, 0.0, 1.0)
	var echte_hoogte := sin(dag * PI)                 # 0 aan de horizon, 1 in de middag
	var licht := clampf(echte_hoogte * 3.0, 0.0, 1.0) if tijd > 5.5 and tijd < 18.5 else 0.0
	# draaiing rond de verticale as: 90 = licht uit het oosten, 0 = uit het zuiden.
	# De camera kijkt vanuit het zuidoosten; de zon blijft schuin van opzij
	# (oost tot zuidoost) zodat schaduwen zichtbaar in beeld vallen en de gevels licht houden.
	var azimut := lerpf(110.0, 55.0, dag)
	var hoogte := lerpf(min_hoogte, max_hoogte, echte_hoogte)
	_zon.rotation_degrees = Vector3(-hoogte, azimut, 0.0)
	var warm := 1.0 - echte_hoogte
	_zon.light_color = Color(1.0, 0.93 - warm * 0.25, 0.82 - warm * 0.45)
	_zon.light_energy = 1.55 * licht
	_zon.shadow_enabled = licht > 0.05
	RenderingServer.global_shader_parameter_set("zwervr_nacht", 1.0 - licht)
	if _vul:
		# 's nachts wordt het vullicht een zwak blauw maanlicht
		_vul.light_energy = lerpf(0.12, 0.22, licht)
		_vul.light_color = Color(0.62, 0.74, 1.0).lerp(Color(0.45, 0.55, 0.9), 1.0 - licht)
	if _env:
		_env.ambient_light_energy = lerpf(0.18, 0.8, licht)
		_env.background_energy_multiplier = lerpf(0.15, 1.0, licht)
	if _lucht:
		_lucht.sky_top_color = Color(0.05, 0.07, 0.16).lerp(Color(0.3, 0.5, 0.85), licht)
		_lucht.sky_horizon_color = Color(0.12, 0.12, 0.22).lerp(Color(0.7, 0.8, 0.92), licht).lerp(Color(0.95, 0.6, 0.4), warm * licht * 0.6)
		_lucht.ground_horizon_color = _lucht.sky_horizon_color
		_lucht.ground_bottom_color = _lucht.sky_horizon_color.lerp(_lucht.sky_top_color, 0.5)
		# glas spiegelt dezelfde lucht (voxel_glass.gdshader)
		RenderingServer.global_shader_parameter_set("zwervr_lucht_boven", _lucht.sky_top_color.lightened(0.1))
		RenderingServer.global_shader_parameter_set("zwervr_lucht_horizon", _lucht.sky_horizon_color)
