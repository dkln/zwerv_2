extends RefCounted
## Stops for the tour (tour.gd) and tools/screenshots.gd: fixed areas in the
## city plus all demo districts (from the "districts" metadata that
## tools/build_example_city.gd stores on the world scene root).
##
## Rows of CITY and WATER: [slug, title, text, focus x, focus z, view size], all in
## metres (view size = metres in view, see iso_camera.gd). Titles and texts are
## player-facing and therefore Dutch.

## Size of one map cell in metres (district metadata is in cells).
const CELL := 4.0

## Low flights through the town (tour.gd shots of kind "fly"), in metres:
## [slug, title, text, from x, y, z, to x, y, z, seconds, after the stop with this slug].
## The camera flies from `from` to `to` looking along the way, a little downwards.
const FLIGHTS := [
	["vlucht_gracht", "Over de gracht", "Laag over het water, tussen de grachtenpanden en onder de lantaarns door, onder de boogbrug door.", 36, 4.5, -8, 36, 4.5, 112, 9.0, "stad_overzicht"],
	["vlucht_hoofdstraat", "Door de Hoofdstraat", "Over de Hoofdstraat door de oude stad: stoepen, fietspaden, winkels en het plein.", -4, 5, 58, 140, 5, 58, 8.0, "plein"],
	["vlucht_zuidweg", "Over de Zuidweg", "Langs de busstrook, de fietspaden en de middenberm met lantaarns.", 0, 6, 180, 380, 6, 180, 9.0, "zwemmen"],
	["vlucht_snelweg", "Over de snelweg", "Laag boven de snelweg: vluchtstroken, vangrails en de portalen met de blauwe borden.", 380, 7, 312, 0, 7, 312, 10.0, "aansluiting"],
	["vlucht_winkelstraat", "Door de winkelstraat", "Door de autovrije winkelstraat, langs de etalages, terrassen en de fontein.", 252, 5, 368.5, 380, 5, 368.5, 8.0, "winkelstraat"],
]
## Seconds per shot of each kind (tour.gd): shader stops (half off, half on), stops in
## the city, demo districts, and the overview shots.
const SHADER_TIME := 8.0
const CITY_TIME := 3.5
const DISTRICT_TIME := 2.4
const OVERVIEW_TIME := 5.0

## The first stops of the tour: how the shaders suggest depth and detail. Rows as
## CITY plus the shader globals (Project > Shader Globals) the tour switches off and on
## again halfway through the stop, so the difference shows (tour.gd); "node:<name>"
## switches a node of the tour scene with an "enabled" property instead.
const SHADERS := [
	["shader_baksteen", "Shader: baksteen", "Geen extra geometrie: de shader legt reliëf in de belichting. Elke baksteen in het metselverband krijgt afgeronde randen en een donkere voeg, met hier en daar een putje of een haarscheurtje; ook de stoep en het fietspad ervoor hebben hun eigen reliëf.", 100, 44, 18, ["zwervr_relief"]],
	["shader_asfalt", "Shader: asfalt", "Asfalt krijgt het patroon van echt asfalt: steentjes van ~4 cm in donkere bitumen, elk met een eigen grijstint en een bolle bovenkant waarop de zon glinstert, en zachte slijtplekken van een paar meter. Het patroon dooft uit zodra een steentje kleiner wordt dan een pixel, zodat het van ver niet flikkert.", 60, 62, 12, ["zwervr_relief"]],
	["shader_plein", "Shader: tegels, natuursteen en klinkers", "Elk plaveisel zijn eigen reliëf: tegels van 3 x 3 voxels, blokken natuursteen, klinkers in verband. De voegen worden breder en lichter zodra ze smaller dan een pixel worden.", 74, 82, 14, ["zwervr_relief"]],
	["shader_gras", "Shader: gras van dichtbij", "Het gras is in de tile één egale kleur. De shader legt er een zachte korrel over, en ingezoomd groeien er echte sprieten uit: hoekige blokjes in voxelstijl, in plukken, die met de wind meebuigen.", 14, 104, 7, ["zwervr_grass", "node:Grassprieten"]],
	["shader_gras_hoogte", "Kort en hoog gras", "Twee grassoorten, dezelfde tile: in het park kort gemaaid gras, in de polder hoog gras met lange sprieten die verder doorbuigen in de wind.", 0, 112, 16, ["node:Grassprieten"]],
	["shader_golving", "Shader: golvende grond", "Een veld van dezelfde tiles is plat, maar de shader belicht het alsof het zacht golft: een trage hoogtekaart van brede glooiingen kantelt alleen de normaal heel licht, zodat de zon de ene kant net wat lichter maakt dan de andere.", 40, 110, 70, ["zwervr_undulation"]],
	["shader_veraf", "Shader: van ver", "Van ver zijn de voxels kleiner dan een pixel. Dan legt de shader rustige vlekken over de grond, zodat de polder en de grasvelden niet één egale kleur worden.", 260, 60, 260, ["zwervr_far_noise", "zwervr_grass", "zwervr_undulation"]],
]

## Fixed stops in the city, in tour order.
const CITY := [
	["stad_overzicht", "De stad in één beeld", "Oude stad, nieuwe wijken, rivier, snelweg en campus. Alles is opgebouwd uit losse tiles van 4x4 m.", 192, 160, 420],
	["gracht", "Gracht met grachtenpanden", "Water op laag -2, kademuren, kades met bolders en lantaarns, grachtenpanden met trap-, klok-, hals- en tuitgevels, woonboten en een bakstenen boogbrug.", 36, 24, 60],
	["bouwblok", "Gesloten bouwblok", "Schuine kappen die om de hoek lopen: hoekkepers op de buitenhoeken, kilkepers op de binnenhoeken, dakkapellen, dakterrassen en een poort naar de binnentuin.", 86, 28, 55],
	["plein", "Plein met terrassen", "Klinkers en natuursteen, fontein, kiosk, ruiterstandbeeld, terrassen met parasols, bankjes en klassieke lantaarns.", 86, 88, 45],
	["park", "Park met vijver", "Vijver met oevers en hoeken, riet en lelies, paden, tulpenbedden, verschillende bomen en een steiger.", 12, 96, 45],
	["bollenveld", "Bollenveld", "Een tulpenveld in de polder naast het park. De tulpen wiegen in de wind: een vertex-shader laat alles boven de grond van het bed meebuigen, sneller en over een kortere hoogte dan bij bomen.", -16, 74, 40],
	["spoor", "Spoorviaduct en station", "Hellingen naar een viaduct op pijlers, brugdekken met ballast, bovenleiding, perron met abri en een overweg.", 136, 70, 80],
	["kathedraal", "Kathedraal en school", "Kathedraal met torens, klokken, roosvenster, steunberen en luchtbogen; school met speelplaats.", 186, 26, 70],
	["musea", "Musea en raadhuis", "Klassiek museum met koepel en zuilen, raadhuis met klokkentoren, kantelen en vlaggen, modern museum met overstek.", 316, 30, 80],
	["bovenhuizen", "Jaren-30 bovenhuizen met horeca", "Gesloten bouwblok van vier lagen met portieken, erkers en balkons; op de hoek winkels en horeca met terrassen.", 164, 92, 55],
	["herenhuizen", "Herenhuizen", "Herenhuizen uit 1600 (lijstgevels, bordes) en 1900 (mansardedak, erkers) met tuinen, muren en poorten.", 216, 88, 45],
	["kerken", "Dorpskerk en moderne kerk", "Kleine bakstenen kerk met toren en spits, moderne kerk met spleetramen en een betonnen klokkenstoel.", 214, 140, 45],
	["hoogbouw", "Hoogbouw", "Kantoren uit de jaren 80, 2000 en modern, een appartemententoren, een galerijflat, parkeergarage, radiotoren en een loopbrug.", 285, 110, 110],
	["zwemmen", "Zwembaden en hallen", "Binnenbad in een holle hal, buitenbad met duikplank en ligstoelen, glazen hal en een glazen overkapping.", 345, 140, 60],
	["zuidweg", "Zuidweg", "Hoofdweg met fietspaden, busstrook, middenberm-lantaarns, bushaltes en een brug over de gracht.", 100, 172, 60],
	["rivier", "Rivier met bruggen", "Stalen boogbrug, tuibrug, ophaalbrug en moderne voetbrug over de rivier, kadetrap en woonboten.", 200, 204, 140],
	["tuibrug", "Tuibrug", "Pyloon met tuien naar het brugdek.", 162, 205, 40],
	["ophaalbrug", "Ophaalbrug", "Klassieke ophaalbrug met portalen en een brugwachtershuisje.", 82, 205, 30],
	["jaren60", "Jaren-60 wijk", "Eengezinswoningen met erkers en dakkapellen, maisonnettes met galerijen, parkeerplaats met laadpalen, containers en een speeltuin.", 60, 250, 80],
	["waterkant", "Vijver met waterkant", "Strand, beschoeiing, basalt-talud, boulevard, steigers en een houten boogbrug.", 96, 276, 40],
	["boerderij", "Boerderij en bedrijven", "Schuren met rieten en pannendaken, moestuin, heide, bos, sloot met duiker, heuvels en een bedrijfspand met industrieel hek.", 180, 255, 90],
	["tunnelbak", "Tunnelbak voor auto en fiets", "Verdiepte weg met keerwanden die onder de snelweg door gaat, met een fietspad ernaast.", 244, 272, 50],
	["boulevard", "Boulevard met vrije trambaan", "Twee rijstroken, stoep met halte, twee trambanen, stoep met halte, twee rijstroken.", 270, 252, 55],
	["viaduct", "Viaduct en luxe appartementen", "Een weg op een viaduct over een weg met middenberm; luxe appartementen met penthouse, dakzwembad en groendak.", 320, 250, 70],
	["snelweg", "Snelweg", "Vluchtstroken, middenberm met vangrails, lantaarns, portalen met blauwe bewegwijzering, met een tunnel eronder.", 180, 304, 80],
	["aansluiting", "Snelwegaansluiting", "Een afrit met uitvoegstrook en puntstuk met botsabsorber, een T-kruising met de lokale weg en een toerit met invoegstrook terug de snelweg op.", 205, 284, 70],
	["galerijflat", "Galerijflat langs de snelweg", "Tien woonlagen op een plint met bergingen, twee vleugels met een knik, galerijen aan de snelwegkant, balkons aan de achterkant, trappenhuizen met liftopbouw en volkstuintjes erachter.", 148, 262, 70],
	["campus", "Campus", "Universiteit met binnenplaats en dakruiter, hogeschool met gekleurde lamellen.", 130, 356, 100],
	["torens", "Kantoortorens met loopbrug", "Twee torens met kolonnade aan de voorkant, verbonden door een loopbrug op 36 m hoogte.", 204, 352, 70],
	["winkelstraat", "Winkelstraat (wandelgebied)", "Autovrije straat met alle winkel- en horecatypes, terrassen, bomen, fontein en paaltjes bij de ingangen.", 312, 366, 60],
	["toegangslanen", "Lanen met rotondes", "Twee lanen verbinden de campusweg met de nieuwe wijken: de ene met een stoepeiland, de andere met een middengeleider en grasberm. Waar ze de eerste straat raken ligt een rotonde.", 158, 380, 180],
]

## Close-ups of the water; in the tour right after the park.
const WATER := [
	["water_spiegeling", "Water: spiegeling", "Bomen, lantaarns, boten en kademuren spiegelen in de gracht. De shader volgt de gespiegelde kijkstraal over het scherm (geen raytracing); raakt hij niets, dan spiegelt de lucht.", 37, 37, 20],
	["water_golven", "Water: golven en glinstering", "Golven uit vier richtingen laten het oppervlak onregelmatig deinen; lichte vlekken drijven mee en kleine glinsteringen flonkeren. Het riet beweegt in de wind.", 12, 96, 20],
	["water_dobberen", "Water: dobberen", "Boten deinen op dezelfde golven als het water en rollen en stampen langzaam; waterlelies in de vijvers dobberen elk op hun eigen plek. Dat doet een vertex-shader (voxel_drijf); de tiles zelf staan gewoon stil in de GridMap.", 120, 206, 40],
	["water_brug", "Water: brug en steigers", "De houten boogbrug en de steigers spiegelen in de vijver; de golven vervormen de spiegeling.", 96, 276, 18],
]

## Display names of the building styles, for districts named "stijl:<style>".
const STYLE_NAMES := {
	"klassiek_rood": "Klassiek (rode baksteen)", "klassiek_donker": "Klassiek (donkere baksteen)", "klassiek_geel": "Klassiek (gele baksteen)",
	"herenhuis_1600": "Herenhuis 1600", "herenhuis_1900": "Herenhuis 1900", "jaren30": "Jaren-30 bovenhuizen", "jaren60": "Jaren-60 woningen",
	"galerijflat": "Galerijflat", "modern_wit": "Modern (wit)", "modern_donker": "Modern (donker)", "modern_hout": "Modern (hout)",
	"appartement_modern": "Modern appartementengebouw", "luxe_appartement": "Luxe appartementen", "kantoor_glas": "Kantoor (glas)",
	"kantoor_beton": "Kantoor (beton)", "kantoor_80": "Kantoor jaren 80", "kantoor_2000": "Kantoor jaren 2000", "kantoor_modern": "Kantoor modern",
	"museum_klassiek": "Klassiek museum", "museum_modern": "Modern museum", "kerk_baksteen": "Bakstenen kerk", "kerk_steen": "Kathedraal (natuursteen)",
	"kerk_modern": "Moderne kerk", "school": "School", "universiteit": "Universiteit", "hogeschool": "Hogeschool", "overheid": "Overheidsgebouw",
	"bedrijfspand": "Bedrijfspand", "schuur_zwart": "Zwarte schuur", "schuur_rood": "Rode schuur",
	"loods_staal": "Stalen loods", "loods_steen": "Loods met stenen plint", "magazijn": "Magazijn", "fabriek": "Fabriek",
}

## [title, text] per district name; districts not listed use their name as title.
const DISTRICT_TEXT := {
	"hallen": ["Sportcomplex", "Drie holle hallen (glas, zwembad en sport) aan één voorplein met een glazen entreeoverkapping, een zuilengalerij met alle pilaren, een parkeergarage met helling en inrit, en een radiomast."],
	"bedrijventerrein": ["Bedrijventerrein", "Grote stalen loods met laaddocks, loods met stenen plint en tondak, magazijn, fabriek met sheddak en schoorsteen, kleinere units, een erf vol containers en silo's, een personeelsparkeerplaats en hekwerk."],
	"tint": ["Woonstraat met tint-shader", "Drie rijtjes identieke huizen aan een straat, elk huis met een eigen tint via TintVlak-nodes: warm, koel, groenig, lichter, donkerder, oker en rozig. Op de hoek kleurt één vlak een heel blok inclusief de grond ervoor."],
	"bochten": ["Woonlussen", "Voor elk straatprofiel een woonlus van twee afgeronde bochten die aansluit op de straat eronder, met een speeltuintje in elke lus. Markeringen, rails en stoepranden lopen mee door de bocht."],
	"dorpskern": ["Dorpskern met kinderkopjes", "Brink met keienplein, keienstraten met keienstoepen en een middengoot, een kerktoren en dorpshuisjes."],
	"lussen": ["Fietslus, tramlus en emplacement", "Een fietslus, een tramlus met haltes en een grote bocht, en een spoorwegemplacement met wissel, overwegen, perron, stootjuk en een grote spoorbocht."],
	"dijk": ["Rivierdijk", "Een dijkweg op de kruin; straten, een fietspad en een pleintje gaan flauw omhoog, straat, tram, spoor en een snelwegverbinding steil. Vier viaducten gaan over de dijk, een terp steekt uit en in de uiterwaard liggen heuvels van gras, zand en grind."],
	"tunnelpark": ["Verdiepte wegen", "Een autotunnel met toerit, open bak, portaal en een weg erboven; een weg die trapsgewijs dieper gaat; een onderdoorgang met stoepen en een fietstunnel."],
	"hellingen_bochten": ["Tunnel met bocht", "Een driestrooks autotunnel die onder de grond een bocht van 90 graden maakt, met toeritten aan beide kanten en straten over het overdekte deel."],
	"keerlussen": ["Keerlussen op dijk en brug", "Per straatprofiel een keerlus die stijgt en weer daalt: eerst op een dijklichaam, daarna als brug op pijlers. De poten komen uit op de straat eronder."],
	"viaductbochten": ["Viaductbochten", "Vlakke, gebogen bruggen op pijlers voor straat, klinkerstraat, fietspad en weg, bereikbaar via rechte hellingen."],
	"kanaal": ["Grachtengordel", "Een gracht met grachtenpanden op beide kades, elk brugtype van kade naar kade, zijstraten naar de stad, een steiger in het water en een viaduct dat over panden en gracht heen loopt."],
	"natuurpark": ["Natuur- en recreatiepark", "Vijver met alle oevers en houten voetbruggen, sloot met duiker, terrastuin met trappen, paden, een bosje, een plantvak, een jeu-de-boulesbaan en een buitenzwembad."],
}

## Spots the build found itself (the "places" metadata, in metres): slug -> [title, text, view size].
const PLACE_TEXT := {
	"verkeerslichten": ["Stratennet met verkeerslichten", "Tweestrooksstraten met stopstrepen, haaientanden, zebra's, pijlen, fietsstroken, fietsstraten en eenrichtingsverkeer. Op deze kruising staan lichten voor auto, fiets, voetganger en OV: noord-zuid groen, oost-west rood.", 55],
	"verkeerslichten_2": ["Kruising op oranje", "Een tweede kruising met verkeerslichten, nu met noord-zuid op oranje en het OV-sein op attentie.", 45],
}


## Slugs of the highlights, in tour order (see `highlights`).
const HIGHLIGHTS := ["stad_overzicht", "gracht", "plein", "hoogbouw", "rivier", "snelweg", "winkelstraat",
	"wijk_kanaal", "water_spiegeling", "water_dobberen", "wijk_hellingen_bochten", "wijk_dorpskern",
	"wijk_bedrijventerrein", "wijk_tint"]


## Only the stops in HIGHLIGHTS, in that order (missing ones are skipped).
static func highlights(all_stops: Array) -> Array:
	var by_slug := {}
	for s in all_stops:
		by_slug[s["slug"]] = s
	return HIGHLIGHTS.filter(func(slug): return by_slug.has(slug)).map(func(slug): return by_slug[slug])


## Returns the stops for the scene `root` as a list of
## {slug, title, text, x, z, size}: focus x/z and view size in metres.
## Order: SHADERS, CITY, then the districts with the PLACE_TEXT spots between them (by z), with
## WATER inserted right after the "park" stop (or at the front if there is no park).
static func stops(root: Node) -> Array:
	var list := []
	for s in SHADERS + CITY:
		list.append(_row_to_stop(s))
	for d in root.get_meta("districts", []):
		var district_name: String = d["name"]
		var title := ""
		var text := ""
		if district_name.begins_with("stijl:"):
			var st := district_name.trim_prefix("stijl:")
			title = "Buurt: " + STYLE_NAMES.get(st, st)
			text = "Een buurtje in deze stijl aan een woonerf: begane grond en winkels, verdiepingen, hoekpanden, daken, toppen en torens, plus een pand met gevel- en dakdetails."
		elif district_name.begins_with("dak:"):
			var kind := district_name.trim_prefix("dak:").replace("_", " ")
			title = "Daken: " + kind
			text = "Alle kapvormen in " + kind + ": schuine kappen met hoekkepers, een L-vorm met kilkeper, afgeknotte kappen, zadeldaken met schild, L en T, piramide- en lessenaarsdak."
		else:
			var dt: Array = DISTRICT_TEXT.get(district_name, [district_name, ""])
			title = dt[0]
			text = dt[1]
		# district x/z/w/d are in cells; focus on its centre, view size a bit over its largest side
		list.append({"slug": "wijk_" + district_name.replace(":", "_"), "title": title, "text": text,
			"x": (d["x"] + d["w"] / 2.0) * CELL, "z": (d["z"] + d["d"] / 2.0) * CELL,
			"size": maxf(d["w"], d["d"]) * CELL * 0.62 + 12.0})
	# spots found by the build, between the districts around them (by z)
	var places: Dictionary = root.get_meta("places", {})
	for slug in PLACE_TEXT:
		if places.has(slug):
			var pt: Array = PLACE_TEXT[slug]
			var at: Vector2 = places[slug]
			var k := CITY.size()
			while k < list.size() and list[k]["z"] <= at.y:
				k += 1
			list.insert(k, {"slug": slug, "title": pt[0], "text": pt[1], "x": at.x, "z": at.y, "size": float(pt[2])})
	# water close-ups right after the park (or at the front if there is no park)
	var after := 0
	for k in list.size():
		if list[k]["slug"] == "park":
			after = k + 1
	for s in WATER:
		list.insert(after, _row_to_stop(s))
		after += 1
	return list


## The tour as one continuous list of camera shots (tour.gd), from stops() plus the
## FLIGHTS. Every shot: {slug, title, text, kind, seconds, ...}; kind "iso": the iso
## camera glides from focus `a` with `size_a` metres in view to `b` with `size_b`
## (a slow push in and a drift); kind "fly": a low flight from `from` to `to`. Shader
## stops keep their "toggle" (their globals go off, then on halfway); "x"/"z" is where
## the shot lies (for the map parts).
static func shots(root: Node) -> Array:
	var flights := {}
	for f in FLIGHTS:
		flights[f[10]] = flights.get(f[10], []) + [f]
	var list := []
	for st in stops(root):
		var focus := Vector3(st["x"], 0, st["z"])
		var size: float = st["size"]
		var drift := Vector3(-1, 0, 1).normalized() * size * 0.06
		var shot := {"slug": st["slug"], "title": st["title"], "text": st["text"], "kind": "iso",
			"x": st["x"], "z": st["z"]}
		if st.has("toggle"):
			shot.merge({"toggle": st["toggle"], "seconds": SHADER_TIME, "a": focus, "b": focus,
				"size_a": size, "size_b": size * 0.85})
		elif str(st["slug"]).begins_with("wijk_"):
			shot.merge({"seconds": DISTRICT_TIME, "a": focus - drift, "b": focus + drift,
				"size_a": size * 1.05, "size_b": size * 0.9})
		else:
			shot.merge({"seconds": OVERVIEW_TIME if size > 300.0 else CITY_TIME, "a": focus - drift,
				"b": focus + drift, "size_a": size * 1.15, "size_b": size * 0.85})
		list.append(shot)
		for f in flights.get(st["slug"], []):
			var from := Vector3(f[3], f[4], f[5])
			var to := Vector3(f[6], f[7], f[8])
			list.append({"slug": f[0], "title": f[1], "text": f[2], "kind": "fly", "from": from,
				"to": to, "seconds": float(f[9]), "x": (from.x + to.x) * 0.5, "z": (from.z + to.z) * 0.5})
	return list


## Converts a SHADERS/CITY/WATER row into a stop dictionary ("toggle": shader globals).
static func _row_to_stop(s: Array) -> Dictionary:
	var stop := {"slug": s[0], "title": s[1], "text": s[2], "x": float(s[3]), "z": float(s[4]), "size": float(s[5])}
	if s.size() > 6:
		stop["toggle"] = s[6]
	return stop
