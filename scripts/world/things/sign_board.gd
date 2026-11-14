extends RefCounted
## Boards with a text on them in an interior, built in code (graphics; docs/CODE_LAGEN.md:
## it keeps its name, the interiors load it; its sizes: sign_board_layout.gd): a plate in a colour with the text
## in the pixel font (lit, unshaded), on the front and, when `both_sides`, on the back. Its
## front faces the node's +z. The signs over the aisles of a supermarket, the lane numbers of
## its checkouts, the price boards, the floor display of the lift in the city hall.
##   const SignBoard = preload("res://scripts/world/things/sign_board.gd")
##   var board := SignBoard.create("DRANKEN", Color("#DE1828"), Color.WHITE)

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const SignBoardLayout = preload("res://scripts/world/things/sign_board_layout.gd")
## The names of the texts on the front and the back.
const TEXT_NAMES := ["Tekst", "TekstAchter"]


## A board of `text` on a plate of `plate` in `ink`, `letter` metres a letter (0 the
## default), `fixed_width` metres wide (0: as wide as the text).
static func create(text: String, plate: Color, ink: Color, letter := 0.0, both_sides := true, fixed_width := 0.0) -> Node3D:
	var size := SignBoardLayout.letter_size(letter)
	var board := Node3D.new()
	board.name = "Bord"
	var mesh := BoxMesh.new()
	mesh.size = SignBoardLayout.plate_size(text.length(), size, fixed_width)
	var material := StandardMaterial3D.new()
	material.albedo_color = plate
	material.roughness = 0.8
	mesh.material = material
	var plate_node := MeshInstance3D.new()
	plate_node.name = "Plaat"
	plate_node.mesh = mesh
	board.add_child(plate_node)
	for side: float in SignBoardLayout.sides(both_sides):
		var label := Label3D.new()
		label.name = TEXT_NAMES[0] if side > 0.0 else TEXT_NAMES[1]
		label.text = text
		label.font = UiStyle.font(UiStyle.FONT_PIXEL_BOLD)
		label.font_size = SignBoardLayout.FONT_PIXELS
		label.pixel_size = SignBoardLayout.pixel_size(size)
		label.modulate = ink
		label.outline_size = 0
		label.shaded = false
		label.double_sided = false
		label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		label.position = SignBoardLayout.text_place(side)
		label.rotation.y = SignBoardLayout.text_turn(side)
		board.add_child(label)
	return board


## The text of a board made by create (both sides).
static func set_text(board: Node3D, text: String) -> void:
	for label_name: String in TEXT_NAMES:
		var label := board.get_node_or_null(label_name) as Label3D
		if label:
			label.text = text
