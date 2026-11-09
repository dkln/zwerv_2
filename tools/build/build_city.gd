extends "res://tools/build/city/finishing.gd"
## Builds scenes/stad.tscn: the centre of The Hague, compressed onto a street grid and
## made only of the tiles in the libraries.
## usage: GODOT_TIMEOUT=1200 tools/godot.sh --headless --script tools/build/build_city.gd
##
## This is the entry point: _init builds the town in order, district by district and then
## the passes over the whole of it. The work is in the builder in tools/build/city/ (the
## chain is in city/base.gd): the general parts (placement G/B/D/Pr, building helpers
## block, ring, tower, ..., the street grid with its markings, lights and kerbs) and the
## parts of this town (the plan in city/map.gd, then its streets, districts, motorway,
## rails and finishing). Coordinates: x = east, z = south, ground tiles of 4 m;
## directions name the side a tile's front faces (see city/base.gd).
##
## MAP (x 0..215, z 0..175: the city x 0..175, the A12 and Voorburg east of it)
##   The Singelgracht rings the old centre (water x 2-3, x 66-67, z 2-3, z 88-89, quays
##   on both sides). Inside, on a grid of streets (x 5, 24, 48, 63 and z 5, 29, 58, 85):
##                x 7..23              x 26..47                  x 50..62
##   z  7..28     Paleis Noordeinde,   Lange Voorhout,           Denneweg,
##                Paleistuin           Kloosterkerk, Des Indes   Prinsessegracht houses
##   z 31..57     Grote Kerk,          Hofvijver, Binnenhof,     Plein with the statue,
##                Hoogstraat, Oude     Ridderzaal, Torentje,     ministries, Tweede Kamer
##                Raadhuis             Mauritshuis, Buitenhof
##   z 60..84     Grote Markt,         Grote Marktstraat with    Spuiplein, Nieuwe Kerk,
##                Chinatown            the Bijenkorf, Passage,   white city hall, Amare
##                                     shops on the Spui (x 48)
##   The street x 48 is the Korte Vijverberg, then the Lange Poten (z 31..57), then the Spui
##   (z 60..84); the shops of the Lange Poten, Spui and Grote Marktstraat are on them.
##   East of the Prinsessegracht (street x 69, Koningskade), cut by the streets x 96
##   (Juliana van Stolberglaan) and x 128 (Laan van NOI): the Haagse Bos with Paleis Huis
##   ten Bosch (z 0..17) and the offices of the Prins Clauslaan east of it; the A12
##   (Utrechtsebaan, z 19..27) coming in from the bend east of the city, down into a trough, covered
##   from x 95 to x 130 with the Malietoren, Snackbar De Vrijheid and offices on the deck
##   (_over_a12), up again to a junction with the Koningskade by the Ministerie van
##   Financien; the Malieveld, the Bezuidenhout and the Theresiastraat (z 31..57);
##   Centraal Station with its square and towers, the Beatrixkwartier and the
##   Bezuidenhout-Oost (z 60..91).
##   Trams: Buitenhof (x 24, z 29..59), Kneuterdijk - Korte Voorhout - Malieveld (z 29)
##   and Grote Marktstraat - Spui - Centraal (z 58), over bridges across the singel;
##   the RandstadRail viaduct (z 90..91) from Centraal Station east over the
##   Beatrixkwartier, with stops at Centraal, there and at the Laan van NOI, on over the
##   Bezuidenhout-Oost; a ramp and tracks along x 72..73 join it to the line of street
##   z 58 (_schenkviaduct). Railway: two tracks from Centraal Station south and up to a
##   viaduct beside the tram (z 93..94), through elevated Station Laan van NOI over the
##   street x 128 and Station Voorburg to the map edge (_railway). The trams of the Grote Marktstraat run through a tunnel with an
##   underground stops at the Grote Markt and the Spui between two ramps (x 26..55, _tram_tunnel). The tracks along
##   x 72..73 run under a wing of the Ministerie van VWS (De Resident) built over them (_ministry_over_tram). South of the viaducts the Schenkkade (z 96) and the
##   neighbourhood along it (_schenkkade). Road bridges over the east arm of the singel
##   at the Mauritskade (z 5), the two tram streets and the Zuidwal (z 85).
##   East of the city (x 176..215): the A12 turns south in a square bend (x 181..189) and
##   runs past the Binckhorst and Voorburg, with the half junctions 3 (Bezuidenhout, the
##   Schenkkade) and 4 (Voorburg, the street z 130) whose streets cross it on bridges, and
##   from z 148 in a trough to the map edge (_a12_east, _a12_bridges); the viaducts of
##   RandstadRail and railway cross it to Station Voorburg (x 200..210); Voorburg on the
##   street x 204 with the Oude Kerk (_voorburg).

const Progress = preload("res://tools/progress.gd")


func _init() -> void:
	Common.watchdog(self, 1100)
	var root := _make_scene("Stad")
	var build_steps: Array[Callable] = [
		_streets, _singel, _noordeinde, _lange_voorhout, _denneweg, _grote_kerk, _binnenhof, _plein,
		_grote_markt, _grote_marktstraat, _spui, _haagse_bos, _a12, _a12_east, _over_a12,
		_prins_clauslaan, _malieveld, _bezuidenhout, _theresiastraat, _bezuidenhout_oost, _centraal,
		_beatrixkwartier, _schenkkade, _schilderswijk, _laakkwartier, _binckhorst, _voorburg,
		_tram_lines, _paint_streets, _dress_streets, _paint_trams, _tram_tunnel, _bridges, _a12_junction,
		_square_corners, _auto_kerbs, _round_bend_kerbs, _fill_grass_all, _railway, _a12_bridges,
		_schenkviaduct, _ministry_over_tram, _a12_footbridge, _paths_to_lonely_buildings,
		_join_gravel_paths, _roof_equipment, _straighten_hidden_corners, _flatten_facades_by_viaducts,
		_remove_trees_in_buildings, _fit_signs_on_facades, _one_sign_per_spot, _clear_behind_signs,
		_bins, _grote_marktstraat_lanes, _camera.bind(root), _zebra_clock.bind(root),
		_helicopter_flights.bind(root), _car.bind(root), _own_tints.bind(root),
	]
	var progress := Progress.new("stad bouwen", build_steps.size())
	for build_step in build_steps:
		build_step.call()
		progress.step(build_step.get_method())
	progress.finish()
	if missing.size() > 0:
		print("MISSING TILES: ", missing.keys())
	_report()
	root.set_meta("districts", districts)
	root.set_meta("places", places)
	root.set_meta("wijken", WIJKEN)
	root.set_meta("straten", STRATEN)
	_save(root, "res://scenes/stad.tscn")
	quit()


## Prints how many library items the town uses per layer.
func _report() -> void:
	for gm in [ground, buildings, details, props]:
		var used := {}
		for c in gm.get_used_cells():
			used[gm.get_cell_item(c)] = true
		var total: int = gm.mesh_library.get_item_list().size()
		print("%s: %d of %d used" % [gm.name, used.size(), total])
