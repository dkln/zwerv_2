extends RefCounted
## The banks of this world: Brabobank, OG Bank and Bonk Bank, each with its name, its two
## colours and a little pixel emblem (rows of characters: "." empty, "a" its colour, "b" its
## second colour, "w" white). Every cash machine in the town belongs to one of them, chosen
## at random but fixed for that machine (bank_for: from where it stands, so the same in every
## game); its welcome screen shows that bank's logo (BankLogo, CashMachineScreen).
##   const Banks = preload("res://scripts/world/things/banks.gd")
##   var bank := Banks.bank_for(machine.global_position)   # "og_bank"
##   Banks.bank(bank).name                                   # "OG Bank"

const ORDER := ["brabobank", "og_bank", "bonk_bank"]
const BANKS := {
	# a bull's head in orange and blue
	"brabobank": {"name": "Brabobank", "colour": Color("#F28C00"), "second": Color("#2C5BC8"), "emblem": [
		"a......a",
		"aa....aa",
		".abbbba.",
		".bbbbbb.",
		".bwbbwb.",
		".bbbbbb.",
		"..baab..",
		"..bbbb..",
	]},
	# a gold crown on deep purple
	"og_bank": {"name": "OG Bank", "colour": Color("#E8B828"), "second": Color("#7A3EC8"), "emblem": [
		"a..a..a.",
		"aa.a.aa.",
		"aaaaaaa.",
		"abawaba.",
		"aaaaaaa.",
		"bbbbbbb.",
	]},
	# a pink hammer going BONK
	"bonk_bank": {"name": "Bonk Bank", "colour": Color("#FF4FA3"), "second": Color("#29C7B8"), "emblem": [
		"aaaaaa..",
		"awaaaa.w",
		"aaaaaa..",
		"..bb..w.",
		"..bb....",
		"..bb....",
		"..bb....",
	]},
}


## The bank (an id of ORDER) of the cash machine standing at `at`: random over the banks, but
## always the same for the same place.
static func bank_for(at: Vector3) -> String:
	var cell := Vector3i(roundi(at.x), roundi(at.y), roundi(at.z))
	return ORDER[posmod(hash(cell), ORDER.size())]


## The bank `id` ({name, colour, second, emblem}); an unknown id gives the first bank.
static func bank(id: String) -> Dictionary:
	return BANKS.get(id, BANKS[ORDER[0]])
