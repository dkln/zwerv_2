extends RefCounted
## How a figure is framed in its portrait (layout; docs/CODE_LAGEN.md): what the camera
## shows between the whole figure (a little from above) and the face (straight on), how big
## a townsperson stands in it and where its face is. Used by player_portrait.gd and
## player_portrait_view.gd.
##   const PlayerPortraitLayout = preload("res://scripts/ui/widgets/player_portrait_layout.gd")

## Share of the size the picture is rendered at (smaller = blockier).
const PIXEL_SCALE := 1.0
## Metres the full framing shows (the tallest figure, Jos with his hat, fits with room).
const FULL_HEIGHT := 2.9
## The room round the whole figure, and the aspect below which more metres are shown.
const FULL_ROOM := 1.08
const NARROW_ASPECT := 0.75
## Metres the face framing shows when nothing else is asked.
const FACE_VIEW := 0.85
## The camera for the whole figure: how far over the middle and how far off; for the face.
const FULL_EYE := Vector2(0.9, 4.0)
const FACE_EYE := Vector2(0.3, 3.0)
## A townsperson: how big beside a player figure, the least height it counts as, and how far
## under the top of its head its face is (metres).
const TOWNSFOLK_SHARE := 0.92
const TOWNSFOLK_LEAST := 0.1
const FACE_UNDER_TOP := 0.17
## The invisible floor that shows the shadow (metres).
const SHADOW_FLOOR := Vector2(6.0, 6.0)


## How many screen pixels a pixel of the picture is.
static func shrink() -> int:
	return int(round(1.0 / PIXEL_SCALE))


## The aspect of a picture of `size` px (1 while it has no height yet).
static func aspect(size: Vector2) -> float:
	return size.x / size.y if size.y > 0.0 else 1.0


## `zoom` (0..1) eased in and out.
static func eased(zoom: float) -> float:
	return zoom * zoom * (3.0 - 2.0 * zoom)


## Metres the full framing shows in a picture of `picture_aspect`: more when it is narrow.
static func full_view(picture_aspect: float) -> float:
	var view := FULL_HEIGHT * FULL_ROOM
	if picture_aspect < NARROW_ASPECT:
		view *= NARROW_ASPECT / picture_aspect
	return view


## Metres the camera shows at `zoom` (0 the whole figure .. 1 the face, `face_view` metres).
static func camera_size(picture_aspect: float, face_view: float, zoom: float) -> float:
	return lerpf(full_view(picture_aspect), face_view, eased(zoom))


## What the camera looks at at `zoom`: the middle of the figure .. the face at `face` metres.
static func camera_target(face: float, zoom: float) -> Vector3:
	return Vector3(0.0, FULL_HEIGHT * 0.5, 0.0).lerp(Vector3(0.0, face, 0.0), eased(zoom))


## Where the camera stands at `zoom`: a little from above .. straight on the face.
static func camera_eye(face: float, zoom: float) -> Vector3:
	return Vector3(0.0, FULL_HEIGHT * 0.5 + FULL_EYE.x, FULL_EYE.y).lerp(Vector3(0.0, face + FACE_EYE.x, FACE_EYE.y), eased(zoom))


## How much a townsperson of `figure_height` metres grows to stand beside a player figure of
## `model_height` metres.
static func townsfolk_grow(model_height: float, figure_height: float) -> float:
	return (model_height / maxf(figure_height, TOWNSFOLK_LEAST)) * TOWNSFOLK_SHARE


## The height of the face of a townsperson whose head ends at `top` metres, grown `grow`
## times: a little under the top of the head.
static func townsfolk_face(top: float, grow: float) -> float:
	return (top - FACE_UNDER_TOP) * grow


## The scale of a figure grown `grow` times that stands `breath` (share) higher.
static func breathing_scale(breath: float, grow: float) -> Vector3:
	return Vector3(1.0, 1.0 + breath, 1.0) * grow


## The top of a picture `width` px wide, in the middle: where the head is taken to be while
## there is no figure.
static func top_centre(width: float) -> Vector2:
	return Vector2(width * 0.5, 0.0)
