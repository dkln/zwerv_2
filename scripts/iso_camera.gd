extends RefCounted
## Isometrisch ogende perspectiefcamera: 45 graden gedraaid, ~35 graden naar
## beneden, met een smalle kijkhoek zodat het bijna isometrisch blijft.
## "grootte" = hoeveel meter je verticaal in beeld ziet rond het focuspunt
## (zoals de size van een orthografische camera). De afstand volgt uit de grootte.
## Een echte perspectiefcamera, omdat Godot schaduwsplits en SSR alleen daarmee
## goed berekent.

const FOV := 20.0
const ROTATIE := Vector3(-35.264, 45.0, 0.0)
const RICHTING := Vector3(0.57735, 0.57735, 0.57735)   # van focus naar camera


static func afstand(grootte: float) -> float:
	return grootte * 0.5 / tan(deg_to_rad(FOV * 0.5))


static func positie(focus: Vector3, grootte: float) -> Vector3:
	return focus + RICHTING * afstand(grootte)


static func plaats(cam: Camera3D, focus: Vector3, grootte: float) -> void:
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = FOV
	cam.near = 2.0
	cam.far = 6000.0
	cam.rotation_degrees = ROTATIE
	cam.global_position = positie(focus, grootte)


## Afstand van de camera tot het grondvlak (y = 0) langs de kijkrichting.
static func afstand_tot_grond(cam: Camera3D) -> float:
	var vooruit := -cam.global_transform.basis.z
	if vooruit.y > -0.05:
		return cam.far * 0.25
	return cam.global_position.y / -vooruit.y


## Huidige grootte (meter in beeld), voor orthografisch en perspectief.
static func grootte(cam: Camera3D) -> float:
	if cam.projection == Camera3D.PROJECTION_ORTHOGONAL:
		return cam.size
	return 2.0 * afstand_tot_grond(cam) * tan(deg_to_rad(cam.fov * 0.5))
