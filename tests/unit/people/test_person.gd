extends RefCounted
## Unit tests of what the people of the town share (scripts/world/person.gd) and how the
## three kinds differ (Pedestrian, InteriorPerson, StationPerson), and of the things the
## player uses with [E] (scripts/world/interactable.gd).

const Person = preload("res://scripts/world/person.gd")
const Interactable = preload("res://scripts/world/interactable.gd")
const InteriorSpot = preload("res://scripts/world/interior_spot.gd")


## Every kind of person is a Person and says which kind it is.
func test_every_kind_of_person_says_what_it_is(test) -> void:
	var inside := InteriorPerson.create("snackbarhouder", 3, false)
	var traveller := StationPerson.create("reiziger", 4, null)
	var walker := Pedestrian.new()
	test.check(inside is Person and traveller is Person and walker is Person, "alle drie zijn een Person")
	test.check(inside.actor_kind() == Person.ACTOR_INTERIOR, "binnen: een InteriorPerson")
	test.check(traveller.actor_kind() == Person.ACTOR_STATION, "in het station: een StationPerson")
	test.check(walker.actor_kind() == Person.ACTOR_STREET, "op straat: een Pedestrian")
	test.check(inside.is_merchant() and not InteriorPerson.create("klant", 5, true).is_merchant(), "wie verkoopt is een handelaar, een klant niet")
	inside.free()
	traveller.free()
	walker.free()


## Talking to them: in the group of who can be talked to, and out of it again.
func test_talkable_on_and_off(test) -> void:
	var guest := InteriorPerson.create("klant", 9, false)
	test.check(guest.is_talkable(), "een klant is aanspreekbaar")
	guest.set_talkable(false)
	test.check(not guest.is_talkable() and not guest.is_in_group(Person.TALKABLE_GROUP), "uit: niet meer")
	guest.set_talkable(true)
	test.check(guest.is_talkable(), "en weer aan")
	guest.free()


## The shared cycle of steps: walking swings the legs, at speed the run blends in, and
## standing still for a conversation puts the legs straight at once.
func test_the_shared_cycle_of_steps(test) -> void:
	var guest := InteriorPerson.create("klant", 11, false)
	for step in 20:
		guest.walk_cycle(1.35 * 0.05, 0.05)
	test.check(guest._walk_share > 0.9 and guest._run_share_now == 0.0, "lopen: geen rennen")
	for step in 20:
		guest.walk_cycle(3.6 * 0.05, 0.05)
	test.check(guest._run_share_now > 0.9, "op snelheid: rennen")
	guest.stand_neutral()
	test.check(guest._walk_share == 0.0 and guest._run_share_now == 0.0 and guest._step_phase == 0.0, "stilstaan voor een gesprek: meteen recht")
	guest.free()


## The voice follows the look; who rides a wheelchair or a scooter sounds old.
func test_the_voice(test) -> void:
	var walker := Pedestrian.new()
	test.check(walker.voice() == "man", "zonder figuur: een man")
	walker.mobility = "rolstoel"
	test.check(walker.voice() == "oude_man", "in een rolstoel: een oude man")
	walker.free()


## The things used with [E]: each has its kind, its text and what E does; a spot of an
## interior is one of them.
func test_things_to_use_have_a_kind(test) -> void:
	var used := [0]
	var machine: Node3D = Interactable.make("Automaat", Vector3.ZERO, Interactable.KIND_MACHINE, "Pinnen", func() -> void: used[0] += 1)
	test.check(machine.kind == Interactable.KIND_MACHINE and machine.action_text() == "Pinnen", "een automaat met zijn tekst")
	test.check(machine.is_in_group(Interactable.USE_GROUP), "in de groep waar de speler in zoekt")
	machine.go_through()
	test.check(used[0] == 1, "E doet wat het moet")
	var spot: Node3D = InteriorSpot.create("Kassa", Vector3.ZERO, "Afrekenen", func() -> void: pass)
	test.check(spot is Interactable and spot.kind == Interactable.KIND_SPOT and spot.reach() == Interactable.REACH, "een plek binnen is er ook een")
	spot.text_of = func() -> String: return "Karretje terugzetten"
	test.check(spot.action_text() == "Karretje terugzetten", "de tekst kan meebewegen")
	test.check(Interactable.KINDS.size() == 5, "vijf soorten dingen")
	machine.free()
	spot.free()
