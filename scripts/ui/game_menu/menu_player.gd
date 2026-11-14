extends RefCounted
## The player as the game menu sees it (behaviour, without a picture; docs/CODE_LAGEN.md):
## the "Speler" node of the current scene (scripts/player/player_controller.gd: archetype_id,
## level, money, stat(name) -> Vector2(value, maximum), inventory, inventory_slots(),
## use_item(id), drop_item(id), is_dead(), teleport(at, yaw), signals inventory_changed and
## stats_changed); without it the chosen archetype (PlayerCharacter), its START_ITEMS and
## the stats of the HUD, kept here so that using and dropping still work. Made by
## scripts/ui/game_menu.gd and handed to its tabs.
##   const MenuPlayer = preload("res://scripts/ui/game_menu/menu_player.gd")

const PlayerCharacter = preload("res://scripts/player/player_character.gd")
const Items = preload("res://scripts/player/items.gd")
const Iso = preload("res://scripts/camera/iso_camera.gd")
const InventoryTabRules = preload("res://scripts/ui/game_menu/inventory_tab_rules.gd")
const PLAYER_NODE := "Speler"
## The signals of the player after which the menu shows itself anew.
const CHANGE_SIGNALS := ["inventory_changed", "stats_changed"]
## The number the machine of Burgerzaken gave (CityHall.TICKET_META), on the player.
const TICKET_META := "wachtnummer"

## The player node; null when the scene has none.
var node: Node
## The HUD the menu hangs under (its stats and level stand in for a missing player); may be null.
var hud: Node

var _fallback_inventory := {}   # item id -> count, when there is no player
var _fallback_stats := {}       # stat name -> Vector2(value, maximum), when there is no player or HUD


## Looks up the "Speler" node of `scene` (on each opening of the menu: it may come later
## than the HUD) and calls `on_change` whenever its things or stats change.
func find_in(scene: Node, on_change: Callable) -> void:
	var found: Node = scene.get_node_or_null(PLAYER_NODE) if scene else null
	if found != node:
		node = found
		if node:
			for signal_name: String in CHANGE_SIGNALS:
				if node.has_signal(signal_name) and not node.is_connected(signal_name, on_change):
					node.connect(signal_name, on_change)
	if node == null and _fallback_inventory.is_empty():
		_fallback_inventory = Items.START_ITEMS.get(PlayerCharacter.current_id(), {}).duplicate()


func is_dead() -> bool:
	return node != null and node.has_method("is_dead") and node.is_dead()


func archetype_id() -> String:
	if node and "archetype_id" in node and PlayerCharacter.ARCHETYPES.has(node.archetype_id):
		return node.archetype_id
	return PlayerCharacter.current_id()


func archetype() -> Dictionary:
	return PlayerCharacter.ARCHETYPES[archetype_id()]


func level() -> int:
	if node and "level" in node:
		return int(node.level)
	if hud and "player_level" in hud:
		return int(hud.player_level)
	return int(archetype().get("level", 1))


func money() -> float:
	if node and "money" in node:
		return float(node.money)
	return float(archetype().get("start_money", 0))


## A stat as Vector2(value, maximum): from the player, else the HUD, else the archetype
## (hunger and overstimulation start empty, as in the HUD).
func stat(stat_name: String) -> Vector2:
	if node and node.has_method("stat"):
		return node.stat(stat_name)
	if _fallback_stats.has(stat_name):
		return _fallback_stats[stat_name]
	if hud and hud.has_method("get_stat"):
		var from_hud: Vector2 = hud.get_stat(stat_name)
		if from_hud.y > 0.0:
			return from_hud
	return InventoryTabRules.starting_stat(stat_name, float(archetype().stats.get(stat_name, 100)))


## What the player has on it: item id -> count.
func inventory() -> Dictionary:
	if node and "inventory" in node:
		return node.inventory
	return _fallback_inventory


## How many kinds of item the player has room for (Items.BASE_SLOTS, more with a rucksack),
## at most `most` (the slots of the grid).
func slot_count(most: int) -> int:
	if node and node.has_method("inventory_slots"):
		return mini(int(node.inventory_slots()), most)
	return Items.BASE_SLOTS


## Whether the player wears a coat (Items "worn"): its pockets give more room.
func has_coat() -> bool:
	if node == null or not ("inventory" in node):
		return false
	for item_id: String in node.inventory:
		if Items.is_worn(item_id):
			return true
	return false


## Uses an item (eats, drinks...): through the player's use_item, or without a player on
## the menu's own copy of the things and stats. Whether it was used.
func use_item(item_id: String) -> bool:
	if node and node.has_method("use_item"):
		return node.use_item(item_id)
	if int(_fallback_inventory.get(item_id, 0)) <= 0:
		return false
	InventoryTabRules.take_one(_fallback_inventory, item_id)
	var effect: Dictionary = Items.item(item_id).get("effect", {})
	for stat_name: String in effect:
		_fallback_stats[stat_name] = InventoryTabRules.stat_after(stat(stat_name), float(effect[stat_name]))
	return true


## Throws one of an item away: through the player's drop_item, else from the menu's own copy.
func drop_item(item_id: String) -> void:
	if node and node.has_method("drop_item"):
		node.drop_item(item_id)
	else:
		InventoryTabRules.take_one(_fallback_inventory, item_id)


## The number of the slip of Burgerzaken the player holds; -1 without one.
func ticket_number() -> int:
	return int(node.get_meta(TICKET_META)) if node and node.has_meta(TICKET_META) else -1


## Where the player is (world x, z): the player node, else the point `camera` looks at.
func position(camera: Camera3D) -> Vector2:
	if node is Node3D:
		var position_3d := (node as Node3D).global_position
		return Vector2(position_3d.x, position_3d.z)
	if camera:
		var focus := Iso.ground_focus(camera)
		return Vector2(focus.x, focus.z)
	return Vector2.ZERO


## Which way the player looks (x, z): the player node, else the way `camera` looks; north
## without either.
func heading(camera: Camera3D) -> Vector2:
	if node is Node3D:
		var forward := (node as Node3D).global_basis.z
		return Vector2(forward.x, forward.z)
	if camera:
		var forward := -camera.global_basis.z
		return Vector2(forward.x, forward.z)
	return Vector2(0.0, -1.0)


## Whether the player can be put somewhere else (the debug teleport of the map).
func can_teleport() -> bool:
	return node != null and node.has_method("teleport")


## Puts the player at `at`, looking the way it looked.
func teleport(at: Vector3) -> void:
	node.teleport(at, node.rotation.y)


## How high the player stands (world y); 0 without one.
func height() -> float:
	return (node as Node3D).global_position.y if node is Node3D else 0.0
