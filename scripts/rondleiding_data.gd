extends RefCounted
## Stops voor de rondleiding en de screenshots: vaste gebieden in de stad plus
## alle demowijken (uit de metadata "wijken" van de wereld-scene).

const STAD := [
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
	["campus", "Campus", "Universiteit met binnenplaats en dakruiter, hogeschool met gekleurde lamellen.", 130, 356, 100],
	["torens", "Kantoortorens met loopbrug", "Twee torens met kolonnade aan de voorkant, verbonden door een loopbrug op 36 m hoogte.", 204, 352, 70],
	["winkelstraat", "Winkelstraat (wandelgebied)", "Autovrije straat met alle winkel- en horecatypes, terrassen, bomen, fontein en paaltjes bij de ingangen.", 312, 366, 60],
]

const STIJLNAMEN := {
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

const WIJKTEKST := {
	"hallen": ["Hallen, overkapping en parkeergarage", "Holle hallen (glas, zwembad, sport), glazen overkapping, pilaren, parkeergarage met helling en inrit, radiotoren."],
	"verkeerstuin": ["Verkeerstuin", "Doorlopende straten waarin elke weg-, tram-, fiets-, parkeer- en snelwegmarkering een stuk straat vormt, met wisselende stoepen."],
	"kruispunten": ["Kruispunten en stoephoeken", "Verkeerseilanden, rotonde, middengeleider en alle buiten- en binnenhoeken van stoepen (ook met goot, klinkers en kade)."],
	"lussen": ["Fiets-, tram- en spoorlussen", "Lussen met bochten, T-splitsingen, kruisingen en eindstukken; spoor met wissel, overweg, perron en grote bochten."],
	"dijk": ["Dijk met hellingen en heuvels", "Elke helling als oprit naar een dijk, flauwe hellingen in twee delen, en heuvels van gras, zand en grind."],
	"tunnelpark": ["Tunnelpark", "Autotunnel met toerit, open bak en weg erboven; een verdiepte weg die trapsgewijs dieper gaat; onderdoorgangen en een fietstunnel."],
	"kanaal": ["Kanaal met bruggen", "Alle brugdekken, bakstenen boogbruggen, ophaalbrug, voetbrug, stalen boogbrug, tuibrug, viaduct op pijlers en een loopbrug."],
	"natuurpark": ["Natuur- en recreatiepark", "Vijver met alle oever- en waterkanttypes, sloot met duiker, terrastuin met trappen, pleinmozaïek en een buitenzwembad."],
	"rest": ["Overige tiles", "Tiles die (nog) nergens anders een plek hadden."],
	"verkeerslichten": ["Verkeerslichten in alle standen", "Twee kruisingen met lichten voor auto, fiets, voetganger, bus/tram (OV-sein) en masten: links noord-zuid groen en oost-west rood, rechts noord-zuid oranje."],
	"tint": ["Tint-shader", "Dezelfde panden met elk een eigen tint via TintVlak-nodes: origineel, warm, koel, groenig, lichter, donkerder, oker en rozig. Rechts kleurt één groot vlak een heel blok inclusief de grond."],
	"bedrijventerrein": ["Bedrijventerrein", "Grote stalen loods met laaddocks, loods met stenen plint en tondak, magazijn, fabriek met sheddak en schoorsteen, kleinere units, containers, silo's en hekwerk."],
}


## Geeft een lijst van {titel, tekst, x, z, grootte} (meters) voor de scene-root.
static func stops(root: Node) -> Array:
	var lijst := []
	for s in STAD:
		lijst.append({"slug": s[0], "titel": s[1], "tekst": s[2], "x": float(s[3]), "z": float(s[4]), "grootte": float(s[5])})
	for w in root.get_meta("wijken", []):
		var naam: String = w["naam"]
		var t := ""
		var u := ""
		if naam.begins_with("stijl:"):
			var st := naam.trim_prefix("stijl:")
			t = "Buurt: " + STIJLNAMEN.get(st, st)
			u = "Alle onderdelen van deze stijl toegepast: begane grond en winkels, verdiepingen, hoekpanden, daken, toppen en torens, plus een pand met aangebrachte gevel- en dakdetails."
		elif naam.begins_with("dak:"):
			var soort := naam.trim_prefix("dak:").replace("_", " ")
			t = "Daken: " + soort
			u = "Alle kapvormen in " + soort + ": schuine kappen met hoekkepers, een L-vorm met kilkeper, afgeknotte kappen, zadeldaken met schild, L en T, piramide- en lessenaarsdak."
		else:
			var wt: Array = WIJKTEKST.get(naam, [naam, ""])
			t = wt[0]
			u = wt[1]
		lijst.append({"slug": "wijk_" + naam.replace(":", "_"), "titel": t, "tekst": u,
			"x": (w["x"] + w["w"] / 2.0) * 4.0, "z": (w["z"] + w["d"] / 2.0) * 4.0,
			"grootte": maxf(w["w"], w["d"]) * 4.0 * 0.62 + 12.0})
	return lijst
