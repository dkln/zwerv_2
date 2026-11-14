extends RefCounted
## What a can in a waste bin looks like (graphics; docs/CODE_LAGEN.md; litter_bins.gd): the
## empty can of the machine models sticking out of the top of the bin, with the glowing
## outline of things to pick up (QuestOutline). Where it stands and how it leans:
## litter_bins_layout.gd.
##   const LitterBinsView = preload("res://scripts/world/things/litter_bins_view.gd")
##   LitterBinsView.add_can(spot, bin.top, yaw)

const MachineModels = preload("res://scripts/world/things/machine_models.gd")
const QuestOutline = preload("res://scripts/effects/quest_outline.gd")
const LitterBinsLayout = preload("res://scripts/world/things/litter_bins_layout.gd")
const CAN_NAME := "Blikje"


## A can (the node "Blikje") under `spot` (in the tree), sticking out of the bin whose top
## is at `bin_top` (world), turned `yaw` radians.
static func add_can(spot: Node3D, bin_top: Vector3, yaw: float) -> MeshInstance3D:
	var can := MeshInstance3D.new()
	can.name = CAN_NAME
	can.mesh = MachineModels.can_mesh()
	spot.add_child(can)
	can.global_position = LitterBinsLayout.can_place(bin_top)
	can.rotation = LitterBinsLayout.can_turn(yaw)
	QuestOutline.add(can, LitterBinsLayout.CAN_OUTLINE)
	return can
