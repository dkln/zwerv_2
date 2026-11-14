extends RefCounted
## The rules of the CRT look of the HUD (logic; docs/CODE_LAGEN.md): the numbers its
## shader gets from the settings: how far the HUD bends with the world, when the corners
## are rounded, and the look switched off. Shown by crt_view.gd; the settings themselves
## are the HUD's (scripts/ui/hud.gd: crt_curvature, crt_ui_curvature, crt_corner).
##   const CrtRules = preload("res://scripts/ui/hud/crt_rules.gd")

## The screen the shader counts with while the overlay has no size yet.
const FALLBACK_SCREEN := Vector2(1280.0, 720.0)


## How far the HUD bends: as set, at most as far as the world.
static func ui_curvature(ui: float, world: float) -> float:
	return minf(ui, world)


## The rounding of the corners: as set, none on a flat picture.
static func corner(rounding: float, curvature: float) -> float:
	return rounding if curvature > 0.0 else 0.0


## The size of the screen in real lines: that of the overlay, FALLBACK_SCREEN while it
## has none.
static func screen_size(overlay_size: Vector2) -> Vector2:
	return overlay_size if overlay_size.x > 0.0 else FALLBACK_SCREEN


## A curvature with the look on (`as_made`: what it was set to) or off (flat).
static func curvature_when(on: bool, as_made: float) -> float:
	return as_made if on else 0.0
