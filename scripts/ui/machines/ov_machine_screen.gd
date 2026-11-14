extends "res://scripts/ui/machines/machine_screen.gd"
## The OV-chipkaart machine (in the hall of Den Haag Centraal, scripts/world/station/station.gd: the
## only place to buy or top up a card; the tram stops have OV posts), close up. With what the
## game has (OvCard, scripts/world/station/ov_card.gd):
## - no card yet: buy one (OvCard.CARD_PRICE, with START_BALANCE on it) or a single ticket;
## - with a card: its balance on the display, top it up (OvCard.TOP_UPS) or buy a single
##   ticket. Checking in costs OvCard.RIDE_FARE of the balance.
## You pay with what is in your wallet (the coin slot). Sounds (MachineSounds): the buttons,
## the coins dropping, the ticket or card printed and pushed out, refused.
## Keys: 1-4 the options, Esc away; the mouse too.
##   OvMachineScreen.show_for(player, "DEN HAAG CENTRAAL")

const OvCard = preload("res://scripts/world/station/ov_card.gd")
const SCRIPT_PATH := "res://scripts/ui/machines/ov_machine_screen.gd"
const OPTION_COUNT := 4
## Its model: the tile of the station hall (as StreetMachines OV_TILE).
const INTERIOR_LIBRARY := "res://assets/libraries/binnen.res"
const OV_TILE := "station/kaartautomaat"

var _options: Array[Button] = []
var _option_actions: Array[Callable] = []


static func show_for(for_player: Node, place := "", with_animation := true) -> CanvasLayer:
	var screen: CanvasLayer = (load(SCRIPT_PATH) as GDScript).new()
	screen.set("brand", "OV-CHIPKAART")
	screen.set("body_colour", Color("#E8E4D8"))
	screen.set("trim_colour", Color("#1E5AC8"))
	screen.set("screen_colour", Color("#FFD23A"))
	screen.set("place_name", place)
	screen.set("screen_controls_width", 360.0)   # its choices are long
	screen.set("backdrop", "station" if place.to_upper().contains("CENTRAAL") else "straat")
	return present(screen, for_player, with_animation)


## The OV-chipkaart machine: the tile of the station hall (binnen/station/kaartautomaat, as
## in the streets: StreetMachines), its parts where such a machine has them on its front.
func machine_parts() -> Dictionary:
	var library: MeshLibrary = load(INTERIOR_LIBRARY) if ResourceLoader.exists(INTERIOR_LIBRARY) else null
	var item := library.find_item_by_name(OV_TILE) if library else -1
	if item < 0 or library.get_item_mesh(item) == null:
		return super()
	# the mesh moved so it stands on y = 0, centred in x and z
	var mesh: Mesh = library.get_item_mesh(item)
	var box := library.get_item_mesh_transform(item) * mesh.get_aabb()
	var placed := ArrayMesh.new()
	var tool := SurfaceTool.new()
	for surface in mesh.get_surface_count():
		tool.clear()
		tool.append_from(mesh, surface, Transform3D(library.get_item_mesh_transform(item).basis,
			library.get_item_mesh_transform(item).origin - Vector3(box.get_center().x, box.position.y, box.get_center().z)))
		tool.commit(placed)
		placed.surface_set_material(placed.get_surface_count() - 1, mesh.surface_get_material(surface))
	# where its parts are (the tile: 12 x 8 x 28 voxels, tools/voxgen/tiles/interior.py
	# ticket_machine): the screen sunk two voxels, the buttons under it, the tray low right
	var width := box.size.x
	var height := box.size.y
	var front := box.size.z * 0.5
	var voxel := height / 28.0
	return {"mesh": placed, "screen": Rect2(-width / 3.0, voxel * 15.0, width * 2.0 / 3.0, voxel * 6.0), "front": front,
		"screen_sunk": voxel * 2.0, "keys": Vector3(-voxel, voxel * 11.5, front),
		"slot": Vector3(voxel * 3.0, voxel * 4.5, front)}


func _opened() -> void:
	_show_menu()


## On the touch screen: the choices and STOP.
func build_controls(box: VBoxContainer) -> void:
	for option_index in OPTION_COUNT:
		var option := button("", _option.bind(option_index), 0, Color("#1E5AC8"))
		option.alignment = HORIZONTAL_ALIGNMENT_LEFT
		box.add_child(option)
		_options.append(option)
		_option_actions.append(Callable())
	box.add_child(button("[ESC] STOPPEN", cancel, 0, Color("#7A7E86")))


func pocket_lines() -> Array:
	var lines: Array = [["GELD  " + euros(_money()), UiStyle.TEXT]]
	if OvCard.has_card(player):
		lines.append(["OV-chipkaart", UiStyle.ACCENT])   # its balance is on the machine's screen
	else:
		lines.append(["Geen OV-chipkaart", UiStyle.MUTED])
	if OvCard.has_ticket(player):
		lines.append(["Los kaartje  %d×" % int(_inventory().get(OvCard.TICKET_ITEM, 0)), UiStyle.ACCENT])
	lines.append(["Inchecken kost %s van je saldo." % euros(OvCard.RIDE_FARE), UiStyle.MUTED])
	return lines


func key_hints() -> String:
	return "[1-4] KIEZEN   [ESC] STOPPEN"


func _key(keycode: Key) -> bool:
	for index in OPTION_COUNT:
		if keycode == KEY_1 + index or keycode == KEY_KP_1 + index:
			_option(index)
	return true


func _show_menu(note := "", note_colour := Color(0, 0, 0, 0)) -> void:
	var choices: Array = []
	var lines: Array = []
	if OvCard.has_card(player):
		lines.append("Saldo op uw kaart: " + euros(OvCard.balance(player)))
		for index in OvCard.TOP_UPS.size():
			var amount: float = OvCard.TOP_UPS[index]
			choices.append(["[%d] OPLADEN  %s" % [index + 1, euros(amount)], top_up.bind(amount)])
	else:
		lines.append("Houd uw kaart voor de lezer.")
		lines.append("(Je hebt nog geen OV-chipkaart.)")
		choices.append(["[1] OV-CHIPKAART KOPEN  %s" % euros(OvCard.CARD_PRICE), buy_card])
	choices.append(["[%d] LOS KAARTJE  %s" % [choices.size() + 1, euros(OvCard.TICKET_PRICE)], buy_ticket])
	lines.append("")
	lines.append("Betalen met munten.")
	if note != "":
		lines.append(note)
	show_display("MAAK UW KEUZE", lines, note_colour)
	_set_options(choices)


func buy_card() -> String:
	var result := OvCard.buy_card(player)
	await _after_payment(result, "OV-CHIPKAART", ["Anoniem, blauw."])
	return result


func buy_ticket() -> String:
	var result := OvCard.buy_ticket(player)
	await _after_payment(result, "LOS KAARTJE", ["Enkele reis.", "Bij uitchecken houdt het poortje hem."])
	return result


func top_up(amount: float) -> String:
	var result := OvCard.top_up(player, amount)
	await _after_payment(result, "OPGELADEN", ["+ " + euros(amount)])
	return result


func _after_payment(result: String, what: String, lines: Array) -> void:
	match result:
		"ok":
			_busy = true
			_set_options([])
			UiSounds.play(self, "munt", -4.0)
			show_display("EEN MOMENT...", ["Betaling ontvangen."])
			await pause_for(0.4)
			sound("printer")
			await pause_for(0.6)
			sound("kaart")
			show_tray(what, lines, GOOD)
			refresh_pockets()
			_busy = false
			_show_menu("Betaald. Goede reis!", GOOD)
		"geld":
			sound("fout")
			_show_menu("Te weinig geld.", WARNING)
		"vol":
			sound("fout")
			_show_menu("Je zakken zitten vol.", WARNING)
		"heb_al":
			sound("fout")
			_show_menu("Je hebt al een kaart.", WARNING)
		_:
			sound("fout")
			_show_menu("Dat kan niet.", WARNING)


func _set_options(choices: Array) -> void:
	for index in _options.size():
		var shown := index < choices.size()
		_options[index].visible = shown
		_options[index].text = String(choices[index][0]) if shown else ""
		_option_actions[index] = choices[index][1] if shown else Callable()


func _option(index: int) -> void:
	if index < _option_actions.size() and _option_actions[index].is_valid() and _options[index].visible:
		sound("toets")
		_option_actions[index].call()
