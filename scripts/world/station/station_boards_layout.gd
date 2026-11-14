extends RefCounted
## The boards, displays, clock and shop signs of Den Haag Centraal (layout;
## docs/CODE_LAGEN.md): where their texts stand and how wide they may be; station_view.gd
## builds them.
## The blue face of a departure board (binnen/station/vertrekbord: 6 m wide, a frame of
## 0.125 m) reaches BOARD_EDGE either side of its middle, the columns start (x, metres) at
## BOARD_COLUMNS: the time, the destination, the track (centred) and the remark; each text is
## made smaller when it would reach past the next column or the edge (fitted_pixel_size).
##   const BoardsLayout = preload("res://scripts/world/station/station_boards_layout.gd")

## Rows on a departure board.
const BOARD_ROWS := 7
const BOARD_EDGE := 2.8
const BOARD_COLUMNS := [-2.75, -1.95, 1.65, 2.0]
## The columns of a row, in the order of BOARD_COLUMNS.
const TIME := 0
const DESTINATION := 1
const TRACK := 2
const REMARK := 3
const BOARD_HEADER_Y := 0.69
const BOARD_FIRST_ROW_Y := 0.5
const BOARD_ROW_STEP := 0.19
const BOARD_COLUMN_GAP := 0.1
const BOARD_FONT_SIZE := 40
const BOARD_HEADER_FONT_SIZE := 30
const BOARD_PIXEL_SIZE := 0.0034
## Texts stand this far before the face of their board.
const TEXT_LIFT := 0.01
## The face of a platform display (binnen/station/perronscherm: 2.5 m wide): the white square
## for the track number (centre and width) and where its text starts and ends.
const DISPLAY_NUMBER_X := -0.81
const DISPLAY_NUMBER_WIDTH := 0.5
const DISPLAY_TEXT_LEFT := -0.4
const DISPLAY_EDGE := 1.08
const DISPLAY_TIME_Y := 0.12
const DISPLAY_DESTINATION_Y := -0.11
const DISPLAY_NUMBER_FONT_SIZE := 64
const DISPLAY_NUMBER_PIXEL_SIZE := 0.006
const DISPLAY_FONT_SIZE := 34
## The hands of the station clock: [name, length, width] (metres), from the back to the front.
const CLOCK_HANDS := [["hour", 0.26, 0.07], ["minute", 0.4, 0.05], ["second", 0.38, 0.018]]
const CLOCK_FACE_LIFT := 0.14
const CLOCK_HAND_THICKNESS := 0.02
## The red disc at the end of the seconds hand: its radius, and how far from the tip.
const CLOCK_DISC_RADIUS := 0.05
const CLOCK_DISC_FROM_TIP := 0.1
## The board over a stall: its size (m) and how tall the logo on it is.
const SHOP_BOARD_SIZE := Vector3(2.4, 0.6, 0.06)
const SHOP_LOGO_HEIGHT := 0.42
const SHOP_NAME_FONT_SIZE := 40
const SHOP_NAME_PIXEL_SIZE := 0.0045
## The arrow over a shop (InteriorPerson.place_mark_ahead): this far before its front (m),
## its point between these heights (under the shop sign at 3 m).
const SHOP_MARK_AHEAD := 0.6
const SHOP_MARK_BOTTOM := 1.9
const SHOP_MARK_TOP := 2.4
## A can of the story sticking out of the top of a bin: where and how it lies.
const CAN_POSITION := Vector3(0.0, 1.0, 0.0)
const CAN_ROTATION := Vector3(0.35, 1.1, 0.2)


## The height of row `row_index` (0 the top one) on a departure board.
static func board_row_y(row_index: int) -> float:
	return BOARD_FIRST_ROW_Y - row_index * BOARD_ROW_STEP


## Where the text of `column` (TIME..REMARK) of a row stands on a departure board.
static func board_cell_position(row_index: int, column: int) -> Vector3:
	return Vector3(BOARD_COLUMNS[column], board_row_y(row_index), TEXT_LIFT)


## Where the heading over `column` stands.
static func board_header_position(column: int) -> Vector3:
	return Vector3(BOARD_COLUMNS[column], BOARD_HEADER_Y, TEXT_LIFT)


## Whether the text of `column` starts at its x (left aligned); the track is centred on it.
static func board_column_is_left(column: int) -> bool:
	return column != TRACK


## The most room (m) the text of `column` has on a departure board.
static func board_column_width(column: int) -> float:
	match column:
		TIME:
			return BOARD_COLUMNS[DESTINATION] - BOARD_COLUMNS[TIME] - BOARD_COLUMN_GAP
		DESTINATION:
			return BOARD_COLUMNS[TRACK] - 0.25 - BOARD_COLUMNS[DESTINATION] - BOARD_COLUMN_GAP
		TRACK:
			return 2.0 * (BOARD_COLUMNS[REMARK] - BOARD_COLUMNS[TRACK]) - BOARD_COLUMN_GAP
	return BOARD_EDGE - BOARD_COLUMNS[REMARK]


## The room (m) of a line of text on a platform display.
static func display_text_width() -> float:
	return DISPLAY_EDGE - DISPLAY_TEXT_LEFT


static func display_number_position() -> Vector3:
	return Vector3(DISPLAY_NUMBER_X, 0.0, TEXT_LIFT)


static func display_time_position() -> Vector3:
	return Vector3(DISPLAY_TEXT_LEFT, DISPLAY_TIME_Y, TEXT_LIFT)


static func display_destination_position() -> Vector3:
	return Vector3(DISPLAY_TEXT_LEFT, DISPLAY_DESTINATION_Y, TEXT_LIFT)


## The pixel size of a text `text_width` m wide at `full_size` so it fits in `max_width`:
## smaller when it would be too wide.
static func fitted_pixel_size(full_size: float, text_width: float, max_width: float) -> float:
	return full_size * max_width / text_width if text_width > max_width else full_size


## The size of hand `hand_index` of the clock (CLOCK_HANDS).
static func clock_hand_size(hand_index: int) -> Vector3:
	return Vector3(CLOCK_HANDS[hand_index][2], CLOCK_HANDS[hand_index][1], CLOCK_HAND_THICKNESS)


## Where hand `hand_index` hangs on its pivot: its foot just under the middle of the clock,
## each hand a little before the last.
static func clock_hand_position(hand_index: int) -> Vector3:
	return Vector3(0.0, float(CLOCK_HANDS[hand_index][1]) * 0.5 - 0.04, float(hand_index) * 0.01)


## Where the disc of hand `hand_index` (the seconds hand) is on its pivot.
static func clock_disc_position(hand_index: int) -> Vector3:
	return Vector3(0.0, float(CLOCK_HANDS[hand_index][1]) - CLOCK_DISC_FROM_TIP, 0.03)


## The plate of a shop board, behind the texts.
static func shop_plate_position() -> Vector3:
	return Vector3(0.0, 0.0, -SHOP_BOARD_SIZE.z * 0.5 - 0.01)


## The logo at the left of a shop board.
static func shop_logo_position() -> Vector3:
	return Vector3(-SHOP_BOARD_SIZE.x * 0.5 + SHOP_LOGO_HEIGHT * 0.5 + 0.12, 0.0, 0.005)


## The name on a shop board: in the middle, or of what the logo leaves.
static func shop_name_position(has_logo: bool) -> Vector3:
	return Vector3((SHOP_LOGO_HEIGHT + 0.2) * 0.5 if has_logo else 0.0, 0.0, 0.006)


## The room (m) of the name on a shop board.
static func shop_name_width(has_logo: bool) -> float:
	return SHOP_BOARD_SIZE.x - (SHOP_LOGO_HEIGHT + 0.3 if has_logo else 0.2)
