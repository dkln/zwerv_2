extends RefCounted
## Where the light of a street lamp sits (layout; docs/CODE_LAGEN.md): per kind of lamp its
## heads (metres, in the tile's own frame, before its turn in the grid): at the end of the
## arm, on top, both heads of a double lamp; and how far its light reaches. A lamp not in
## LAMP_HEADS has one light on the top of its middle. The node: street_lights.gd.
##   const StreetLightsLayout = preload("res://scripts/world/town/street_lights_layout.gd")

## Per lamp: the heads ([x, y, z] in the tile) and the reach (m) of its light.
const LAMP_HEADS := {
	"verlichting/lantaarn_modern": {"heads": [Vector3(1.4, 5.75, 0.0)], "range": 11.0},
	"verlichting/lantaarn_klassiek": {"heads": [Vector3(0.0, 4.9, 0.0)], "range": 9.0},
	"verlichting/lantaarn_wand_klassiek": {"heads": [Vector3(0.06, 0.9, 0.45)], "range": 6.0},
	"verlichting/lantaarn_klassiek_dubbel": {"heads": [Vector3(-1.15, 3.9, 0.0), Vector3(1.15, 3.9, 0.0)], "range": 9.0},
	"verlichting/lantaarn_gietijzer": {"heads": [Vector3(1.3, 4.1, 0.0)], "range": 9.0},
	"verlichting/lantaarn_park": {"heads": [Vector3(0.0, 3.4, 0.0)], "range": 8.0},
	"verlichting/lantaarn_middenberm": {"heads": [Vector3(-4.0, 9.9, 0.0), Vector3(4.0, 9.9, 0.0)], "range": 15.0},
}
## A lamp not in LAMP_HEADS: its light reaches this far, and sits this far under its top.
const DEFAULT_RANGE := 9.0
const DEFAULT_HEAD_DROP := 0.3


## True for a lamp whose heads are known.
static func is_known(item_name: String) -> bool:
	return not (LAMP_HEADS.get(item_name, {}) as Dictionary).get("heads", []).is_empty()


## The heads of lamp `item_name` in the tile's own frame; one on the top of the middle of
## `mesh_box` (the box round its model) for a lamp that is not known.
static func heads_of(item_name: String, mesh_box: AABB) -> Array:
	var heads: Array = (LAMP_HEADS.get(item_name, {}) as Dictionary).get("heads", [])
	if heads.is_empty():
		heads = [Vector3(mesh_box.get_center().x, mesh_box.end.y - DEFAULT_HEAD_DROP, mesh_box.get_center().z)]
	return heads


## How far the light of lamp `item_name` reaches (metres).
static func range_of(item_name: String) -> float:
	return float((LAMP_HEADS.get(item_name, {}) as Dictionary).get("range", DEFAULT_RANGE))
