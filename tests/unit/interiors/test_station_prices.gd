extends RefCounted
## Unit test of the prices in Den Haag Centraal (scripts/story/conversations.gd,
## data/gesprekken/winkels.json against snackbarhouder.json): the station is dearer than the town.

const Conversations = preload("res://scripts/story/conversations.gd")


## What the town's snack bar sells too costs at least STATION_MARKUP times as much in every
## shop of the station.
func test_everything_at_the_station_costs_more_than_in_town(test) -> void:
	var town_prices := {}
	for entry: Dictionary in Conversations.counter().get("menu", []):
		town_prices[str(entry.item)] = float(entry.prijs)
	var compared := 0
	var cheaper: Array[String] = []
	for kind: String in (Conversations.shops().get("winkels", {}) as Dictionary):
		var seller := Node3D.new()
		seller.set_meta("kind", kind)
		for entry: Dictionary in Conversations.shop_data_of(seller).get("menu", []):
			if town_prices.has(str(entry.item)):
				compared += 1
				if float(entry.prijs) < town_prices[str(entry.item)] * Conversations.STATION_MARKUP - 0.001:
					cheaper.append("%s bij %s (%.2f, stad %.2f)" % [entry.item, kind, entry.prijs, town_prices[str(entry.item)]])
		seller.free()
	test.check(cheaper.is_empty() and compared > 0, "op het station is alles duurder dan in de stad (%d vergeleken) %s" % [compared, cheaper])
