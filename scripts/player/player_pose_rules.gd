extends RefCounted
## The poses the player puts its figure in (logic; docs/CODE_LAGEN.md): a pose is a
## Dictionary limb -> Vector3 (degrees, PlayerModel.pose_limb). The jump as in the old
## platform games, the flailing while drowning. The behaviour (player_controller.gd) asks for
## a pose and hands it to its view (player_controller_view.gd show_pose).
##   const PlayerPoseRules = preload("res://scripts/player/player_pose_rules.gd")

## The jump: the right arm straight up, the left down and back bent square at the elbow; the
## left leg forward with the knee bent, the right back with the foot kicked up.
const JUMP_POSE := {
	"arm_right": Vector3(-165.0, 0.0, 10.0), "forearm_right": Vector3(-10.0, 0.0, 0.0),
	"arm_left": Vector3(40.0, 0.0, -12.0), "forearm_left": Vector3(-90.0, 0.0, 0.0),
	"leg_left": Vector3(-60.0, 0.0, 0.0), "shin_left": Vector3(55.0, 0.0, 0.0),
	"leg_right": Vector3(30.0, 0.0, 0.0), "shin_right": Vector3(70.0, 0.0, 0.0),
}
## Drowning: how wildly it still flails at the very end (a share of the start).
const FLAIL_LEAST := 0.4
const FLAIL_FADING := 0.6


## The jump pose (on), or the same limbs back to normal (off).
static func jump_pose(on: bool) -> Dictionary:
	var pose := {}
	for limb: String in JUMP_POSE:
		pose[limb] = JUMP_POSE[limb] if on else Vector3.ZERO
	return pose


## How wildly it flails `time` seconds into `drown_time` seconds of drowning: FLAIL_FADING + FLAIL_LEAST (1) fading to FLAIL_LEAST.
static func flail_strength(time: float, drown_time: float) -> float:
	return clampf(1.0 - time / drown_time, 0.0, 1.0) * FLAIL_FADING + FLAIL_LEAST


## The arms and legs while drowning, `time` seconds in: waving over the head, kicking.
static func flail_pose(time: float, drown_time: float) -> Dictionary:
	var tiring := flail_strength(time, drown_time)
	return {
		"arm_left": Vector3(sin(time * 13.0) * 30.0, 0.0, (-150.0 + sin(time * 17.0) * 35.0) * tiring),
		"arm_right": Vector3(-sin(time * 13.0 + 1.3) * 30.0, 0.0, (150.0 - sin(time * 17.0 + 0.8) * 35.0) * tiring),
		"leg_left": Vector3(sin(time * 9.0) * 25.0 * tiring, 0.0, 0.0),
		"leg_right": Vector3(-sin(time * 9.0) * 25.0 * tiring, 0.0, 0.0),
	}
