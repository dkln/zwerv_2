extends RefCounted
## Boards with a text on them in an interior, built in code: a plate in a colour with the text
## in the pixel font (lit, unshaded), on the front and, when `both_sides`, on the back. Its
## front faces the node's +z. The signs over the aisles of a supermarket, the lane numbers of
## its checkouts, the price boards, the floor display of the lift in the city hall.
##   const SignBoard = preload("res://scripts/world/sign_board.gd")
##   var board := SignBoard.create("DRANKEN", Color("#DE1828"), Color.WHITE)

const UiStyle = preload("res://scripts/ui/ui_style.gd")
## Metres per letter of the text at font size 1 (the pixel font is square), and the room
## round the text on the plate.
const LETTER := 0.19
const MARGIN := 0.18
const THICKNESS := 0.05


## A board of `text` on a plate of `plate` in `ink`, `letter` metres a letter (0 the
## default), `fixed_width` metres wide (0: as wide as the text).
static func create(text: String, plate: Color, ink: Color, letter := 0.0, both_sides := true, fixed_width := 0.0) -> Node3D:
	var size := letter if letter > 0.0 else LETTER
	var board := Node3D.new()
	board.name = "Bord"
	var width := fixed_width if fixed_width > 0.0 else text.length() * size + MARGIN * 2.0
	var height := size * 1.2 + MARGIN
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, height, THICKNESS)
	var material := StandardMaterial3D.new()
	material.albedo_color = plate
	material.roughness = 0.8
	mesh.material = material
	var plate_node := MeshInstance3D.new()
	plate_node.name = "Plaat"
	plate_node.mesh = mesh
	board.add_child(plate_node)
	for side in ([1.0, -1.0] if both_sides else [1.0]):
		var label := Label3D.new()
		label.name = "Tekst" if side > 0.0 else "TekstAchter"
		label.text = text
		label.font = UiStyle.font(UiStyle.FONT_PIXEL_BOLD)
		label.font_size = 64
		label.pixel_size = size / 64.0
		label.modulate = ink
		label.outline_size = 0
		label.shaded = false
		label.double_sided = false
		label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		label.position = Vector3(0.0, 0.0, side * (THICKNESS * 0.5 + 0.005))
		label.rotation.y = 0.0 if side > 0.0 else PI
		board.add_child(label)
	return board


## The text of a board made by create (both sides).
static func set_text(board: Node3D, text: String) -> void:
	for label_name in ["Tekst", "TekstAchter"]:
		var label := board.get_node_or_null(label_name) as Label3D
		if label:
			label.text = text
