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

## Opening of the tour: the heart of the old town, seen while the day goes by.
## [title, text, focus x, focus z, view size at the start, view size at the end].
const INTRO := ["Het stadshart", "Gracht, grachtenpanden, bouwblokken en het plein in de oude stad.", 72, 60, 130, 80]
## The times of day of the opening, in order: [hour, name, text]. Hours keep counting
## past 24 so the clock always runs forward (31 = 7:00 the next morning).
const DAY := [
	[7.0, "Ochtend", "De zon komt op in het oosten: warm, laag licht over de daken en het water."],
	[13.0, "Middag", "De zon staat hoog: volle kleuren, korte schaduwen en de lucht spiegelt in het glas."],
	[17.6, "Avond", "Laag oranje zonlicht en een gloeiende horizon; ramen en lantaarns gaan aan."],
	[23.0, "Nacht", "Lantaarns, ramen en etalages gloeien; blauw maanlicht en geen schaduwen."],
	[31.0, "Ochtend", "Een nieuwe dag: de nachtverlichting dooft en de zon komt weer op."],
	[37.0, "Middag", "Weer volop daglicht. Nu langs alle gebieden van de stad."],
]

## Fixed stops in the city, in tour order.
const CITY := [
	["stad_overzicht", "De stad in één beeld", "Oude stad, nieuwe wijken, rivier, snelweg en campus. Alles is opgebouwd uit losse tiles van 4x4 m.", 192, 160, 420],
	["gracht", "Gracht met grachtenpanden", "Water op laag -2, kademuren, kades met bolders en lantaarns, grachtenpanden met trap-, klok-, hals- en tuitgevels, woonboten en een bakstenen boogbrug.", 36, 24, 60],
	["bouwblok", "Gesloten bouwblok", "Schuine kappen die om de hoek lopen: hoekkepers op de buitenhoeken, kilkepers op de binnenhoeken, dakkapellen, dakterrassen en een poort naar de binnentuin.", 86, 28, 55],
	["plein", "Plein met terrassen", "Klinkers en natuursteen, fontein, kiosk, ruiterstandbeeld, terrassen met parasols, bankjes en klassieke lantaarns.", 86, 88, 45],
	["park", "Park met vijver", "Vijver met oevers en hoeken, riet en lelies, paden, tulpenbedden, verschillende bomen en een steiger.", 12, 96, 45],
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
## Order: CITY, then the districts with the PLACE_TEXT spots between them (by z), with
## WATER inserted right after the "park" stop (or at the front if there is no park).
static func stops(root: Node) -> Array:
	var list := []
	for s in CITY:
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


## Converts a CITY/WATER row into a stop dictionary.
static func _row_to_stop(s: Array) -> Dictionary:
	return {"slug": s[0], "title": s[1], "text": s[2], "x": float(s[3]), "z": float(s[4]), "size": float(s[5])}
