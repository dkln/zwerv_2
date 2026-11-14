extends RefCounted
## The sizes of the close-up of a machine as a whole (the layout layer of
## scripts/ui/machines/machine_screen.gd, which is the behaviour; machine_screen_rules.gd has
## the logic, machine_screen_view.gd builds it with these sizes): the design it is drawn in
## and how that fits a window, its layers, the black behind it, the line of the keys along
## the bottom and the frame of the cursor round a part of the machine. The parts of the
## screen have their own sizes: machine_stage_layout.gd (the 3D scene),
## machine_display_layout.gd (the picture on the machine's screen), machine_info_layout.gd
## (the panel bottom left). Constants and plain functions, without nodes.
##   const MachineScreenLayout = preload("res://scripts/ui/machines/machine_screen_layout.gd")

## The size everything is laid out in (px); fit_transform scales it to the window.
const DESIGN_SIZE := Vector2(1280, 720)
## The canvas layer of the screen, and of the CRT over it.
const LAYER := 90
const CRT_LAYER := LAYER + 1
## The black behind everything: this many designs big, starting this many designs up and left
## (it covers the window whatever its shape).
const BLACK_DESIGNS := 4.0
const BLACK_FROM_DESIGNS := -1.5
## The line with the keys: how far from the bottom it starts and how high it is.
const KEYS_FROM_BOTTOM := 32.0
const KEYS_HEIGHT := 24.0
## The frame of the cursor round a part of the machine: how far outside the part, and how
## thick its line is.
const CURSOR_FRAME_MARGIN := 6.0
const CURSOR_FRAME_BORDER := 4


## The design (DESIGN_SIZE) as big as fits in `window` (px), centred in it.
static func fit_transform(window: Vector2) -> Transform2D:
	var scale_factor := minf(window.x / DESIGN_SIZE.x, window.y / DESIGN_SIZE.y)
	return Transform2D(0.0, Vector2(scale_factor, scale_factor), 0.0, (window - DESIGN_SIZE * scale_factor) * 0.5)


## The black behind everything (design px).
static func black_rect() -> Rect2:
	return Rect2(DESIGN_SIZE * BLACK_FROM_DESIGNS, DESIGN_SIZE * BLACK_DESIGNS)


## The line with the keys, over the whole width along the bottom (design px).
static func keys_rect() -> Rect2:
	return Rect2(0.0, DESIGN_SIZE.y - KEYS_FROM_BOTTOM, DESIGN_SIZE.x, KEYS_HEIGHT)


## The frame of the cursor round a part whose corners are at `corners` in the window (design
## px): the box round them, CURSOR_FRAME_MARGIN outside it. No corners: an empty rectangle.
static func cursor_frame_rect(corners: Array) -> Rect2:
	if corners.is_empty():
		return Rect2()
	var around := Rect2(corners[0], Vector2.ZERO)
	for corner: Vector2 in corners:
		around = around.expand(corner)
	return around.grow(CURSOR_FRAME_MARGIN)
