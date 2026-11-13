extends Node3D
## A vehicle on fire after a crash that was too hard (catches_fire: a closing speed of
## FIRE_SPEED or more): flames of glowing cubes and a column of smoke (menu_fire.gd, at
## SIZE) with a flickering orange light, on the wreck. It burns BURN_SECONDS, dying down
## over the last DIE_SECONDS; then the wreck goes (blinking, death_blink.gd) and the smoke
## drifts on a while where it was (leave_smoke). In the worst case it explodes first
## (explode): a ball of fire bursting out, a flash, shards and black smoke, and the wreck
## thrown up (EXPLOSION_HOP, EXPLOSION_SPIN). It sounds (RuimtelijkGeluid): the fire roars and
## crackles (FIRE_SOUND, softer as it dies down), an explosion booms (EXPLOSION_SOUND). Part of the vehicle logic: the town's
## vehicles (vehicle.gd) and the wrecks behind the menu (main_menu.gd) both use it.

const MenuFire = preload("res://scripts/effects/menu_fire.gd")
const FIRE_SOUND := "brand_loop"
const EXPLOSION_SOUND := "explosie"
const FIRE_SOUND_DB := -3.0
const CrashBurst = preload("res://scripts/effects/crash_burst.gd")

## Closing speed (m/s, about 50 km/h) from which a crash sets the vehicles alight.
const FIRE_SPEED := 14.0
const BURN_SECONDS := 18.0
const DIE_SECONDS := 5.0
## Size of the fire (MenuFire: 0 .. 1).
const SIZE := 0.4
const LIGHT_COLOUR := Color(1.0, 0.5, 0.15)
const LIGHT_ENERGY := 4.0
const LIGHT_RANGE := 16.0
## The explosion: closing speed (m/s) from which a crash behind the menu blows up (the town
## goes by health, vehicle.gd EXPLODE_HEALTH); the ball of fire (MenuFire size), the flash
## (energy, reach, seconds), and how the wreck is thrown (m/s up, rad/s round).
const EXPLODE_SPEED := 20.0
const FIREBALL_SIZE := 1.0
const FLASH_ENERGY := 16.0
const FLASH_RANGE := 30.0
const FLASH_SECONDS := 0.6
const FIREBALL_COLOUR := Color(1.0, 0.55, 0.15)
const SMOKE_COLOUR := Color(0.12, 0.11, 0.1)
const EXPLOSION_HOP := 7.0
const EXPLOSION_SPIN := 5.0

var _flames: GPUParticles3D
var _smoke: GPUParticles3D
var _light: OmniLight3D
var _age := 0.0
var _sound: AudioStreamPlayer3D


## True if a crash at this closing speed (m/s) sets the vehicles on fire.
static func catches_fire(closing_speed: float) -> bool:
	return closing_speed >= FIRE_SPEED


## True if a crash behind the menu at this closing speed (m/s) blows the vehicles up.
static func explodes(closing_speed: float) -> bool:
	return closing_speed >= EXPLODE_SPEED


## Blows up `wreck` (a RigidBody3D) at `height` metres up: the ball of fire, the flash, the
## shards and the black smoke under `parent`, and the wreck thrown up and round.
static func explode(wreck: RigidBody3D, height: float, parent: Node) -> void:
	var at := wreck.global_position + Vector3.UP * height
	var sound := wreck.get_tree().root.get_node_or_null("RuimtelijkGeluid") if wreck.is_inside_tree() else null
	if sound and sound.has_method("play_event"):
		sound.play_event(at, EXPLOSION_SOUND, 25.0)
	var fireball := MenuFire.make_flames(FIREBALL_SIZE)
	fireball.name = "Vuurbal"
	fireball.one_shot = true
	fireball.explosiveness = 0.9
	parent.add_child(fireball)
	fireball.global_position = at
	fireball.emitting = true
	fireball.get_tree().create_timer(fireball.lifetime + 0.5).timeout.connect(fireball.queue_free)
	CrashBurst.spawn(parent, at, FIREBALL_COLOUR, 1.0)
	CrashBurst.spawn(parent, at + Vector3.UP * 0.5, SMOKE_COLOUR, 1.0)
	var flash := OmniLight3D.new()
	flash.name = "Steekvlam"
	flash.light_color = FIREBALL_COLOUR
	flash.light_energy = FLASH_ENERGY
	flash.omni_range = FLASH_RANGE
	flash.shadow_enabled = false
	parent.add_child(flash)
	flash.global_position = at + Vector3.UP
	var dying := flash.create_tween()
	dying.tween_property(flash, "light_energy", 0.0, FLASH_SECONDS).set_ease(Tween.EASE_OUT)
	dying.tween_callback(flash.queue_free)
	wreck.linear_velocity += Vector3.UP * EXPLOSION_HOP
	wreck.angular_velocity += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * EXPLOSION_SPIN


## Sets `wreck` on fire, the flames `height` metres up (on its roof); returns the fire.
static func ignite(wreck: Node3D, height: float) -> Node3D:
	var fire: Node3D = load("res://scripts/effects/vehicle_fire.gd").new()
	fire.name = "Brand"
	wreck.add_child(fire)
	fire.position = Vector3(0.0, height, 0.0)
	return fire


func _ready() -> void:
	_flames = MenuFire.make_flames(SIZE)
	_smoke = MenuFire.make_smoke(SIZE)
	_light = OmniLight3D.new()
	_light.name = "Brandgloed"
	_light.light_color = LIGHT_COLOUR
	_light.omni_range = LIGHT_RANGE
	_light.shadow_enabled = false
	for part: Node3D in [_flames, _smoke, _light]:
		add_child(part)
	var sound := get_tree().root.get_node_or_null("RuimtelijkGeluid")
	if sound and sound.has_method("attach_loop"):
		_sound = sound.attach_loop(self, FIRE_SOUND, 10.0, FIRE_SOUND_DB)


func _process(delta: float) -> void:
	_age += delta
	var burning := clampf(seconds_left() / DIE_SECONDS, 0.0, 1.0)
	_flames.amount_ratio = burning
	if _smoke:
		_smoke.amount_ratio = maxf(burning, 0.3)
	var flicker := 0.75 + 0.25 * sin(_age * 19.0) * sin(_age * 6.1)
	_light.light_energy = LIGHT_ENERGY * burning * flicker
	if _sound:
		# heard while in view (or just outside it), as every sound
		var sound := get_tree().root.get_node_or_null("RuimtelijkGeluid")
		var heard: bool = sound == null or not sound.has_method("in_view") or sound.in_view(global_position)
		var softer: float = sound.distance_db(global_position) if sound and sound.has_method("distance_db") else 0.0
		_sound.volume_db = FIRE_SOUND_DB + softer + linear_to_db(maxf(burning, 0.001)) if heard else -80.0


## Seconds until it has burnt out (and the wreck goes).
func seconds_left() -> float:
	return BURN_SECONDS - _age


## The wreck goes: the last smoke stays under `parent` where it was and drifts off, the
## rest of the fire goes with the wreck.
func leave_smoke(parent: Node) -> void:
	if _smoke == null or parent == null:
		return
	_smoke.reparent(parent)
	_smoke.emitting = false
	var smoke := _smoke
	_smoke = null
	smoke.get_tree().create_timer(smoke.lifetime).timeout.connect(smoke.queue_free)
