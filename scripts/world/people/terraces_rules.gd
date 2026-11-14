extends RefCounted
## Who sits on the terraces (logic; docs/CODE_LAGEN.md): how many of the chairs are taken.
## Where the chairs stand: terraces_layout.gd; the node that seats the people: terraces.gd.
##   const TerracesRules = preload("res://scripts/world/people/terraces_rules.gd")

## How many in 100 of the chairs are taken, and the most a roll can be.
const OCCUPIED := 35
const ROLL_MOST := 100
## What the people on a terrace are (a kind of InteriorPerson).
const GUEST_KIND := "klant"


## True if a chair is taken, by a `roll` of 1..ROLL_MOST.
static func is_taken(roll: int) -> bool:
	return roll <= OCCUPIED
