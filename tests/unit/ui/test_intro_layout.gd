extends RefCounted
## Unit tests of the sizes of the intro (scripts/ui/intro/intro_layout.gd): the stars, the
## twinkle where the logo vanishes and its sparks, and the texts in the corners.
##   tests/run_unit_tests.sh intro_layout

const IntroLayout = preload("res://scripts/ui/intro/intro_layout.gd")


static func _random() -> RandomNumberGenerator:
	var random := RandomNumberGenerator.new()
	random.seed = IntroLayout.STAR_SEED
	return random


func test_the_stars_are_the_same_every_time(test) -> void:
	var stars := IntroLayout.stars(_random())
	var again := IntroLayout.stars(_random())
	test.check(stars.size() == IntroLayout.STAR_COUNT, "%d sterren" % IntroLayout.STAR_COUNT)
	test.check(stars == again, "met hetzelfde zaad dezelfde sterren")
	var inside := true
	var big := 0
	var well_made := true
	for star in stars:
		var at: Vector2 = star.position
		inside = inside and at.x >= 0.0 and at.x < IntroLayout.DESIGN_SIZE.x and at.y >= 0.0 and at.y < IntroLayout.DESIGN_SIZE.y
		big += 1 if star.big else 0
		well_made = well_made and star.size == Vector2.ONE * (IntroLayout.BIG_STAR if star.big else IntroLayout.SMALL_STAR) \
				and star.depth == (IntroLayout.BIG_STAR_DIMS if star.big else IntroLayout.SMALL_STAR_DIMS) \
				and star.pace >= IntroLayout.TWINKLE_PACE.x and star.pace <= IntroLayout.TWINKLE_PACE.y and star.phase >= 0.0 and star.phase <= TAU
	test.check(inside, "allemaal binnen het beeld")
	test.check(big > 0 and big < stars.size() / 4, "een paar grote, de meeste klein (%d groot)" % big)
	test.check(well_made, "elk met zijn maat, tempo, moment en diepte van dimmen")


func test_the_twinkle(test) -> void:
	var rays := IntroLayout.sparkle_rays()
	test.check(rays.size() == 4 and rays[0] == Vector2(rays[1].y, rays[1].x) and rays[2] == Vector2(rays[3].y, rays[3].x), "twee paar gekruiste stralen")
	test.check(rays[0].y == IntroLayout.SPARKLE_ARM * 2.0 and rays[2].y == IntroLayout.SPARKLE_ARM and rays[0].x < rays[2].x, "lang en dun, kort en dik")
	test.check(is_equal_approx(IntroLayout.sparkle_scale(0.0), IntroLayout.SPARKLE_SMALLEST) and is_equal_approx(IntroLayout.sparkle_scale(1.0), 1.0), "van klein tot zijn hele maat")
	test.check(IntroLayout.sparkle_scale(0.25) > lerpf(IntroLayout.SPARKLE_SMALLEST, 1.0, 0.25), "hij groeit snel aan het begin")
	test.check(IntroLayout.sparkle_rotation(0.0) == 0.0 and is_equal_approx(IntroLayout.sparkle_rotation(1.0), PI * 0.25), "hij draait een achtste rond")


func test_the_sparks_fly_out_from_the_middle(test) -> void:
	var spark_size := Vector2.ONE * IntroLayout.SPARK
	var middle := IntroLayout.DESIGN_SIZE * 0.5
	var count := IntroLayout.SPARKLE_SPARKS
	test.check(IntroLayout.spark_position(0, count, 0.0, spark_size).is_equal_approx(middle - spark_size * 0.5), "ze beginnen in het midden")
	var ways := {}
	for spark_index in count:
		var out := IntroLayout.spark_position(spark_index, count, 1.0, spark_size) + spark_size * 0.5 - middle
		test.check(is_equal_approx(out.length(), IntroLayout.SPARKLE_REACH), "vonk %d komt tot de rand van de twinkeling" % spark_index)
		ways[roundi(rad_to_deg(out.angle()))] = true
	test.check(ways.size() == count, "elk zijn eigen kant op")
	var early := (IntroLayout.spark_position(0, count, 0.5, spark_size) + spark_size * 0.5 - middle).length()
	test.check(early > IntroLayout.SPARKLE_REACH * 0.5 and early < IntroLayout.SPARKLE_REACH, "eerst snel, dan langzamer (%.1f halverwege)" % early)


func test_the_texts_in_the_corners_and_under_the_logo(test) -> void:
	var footer := IntroLayout.footer_position()
	test.check(is_equal_approx(footer.x + IntroLayout.FOOTER_SIZE.x, IntroLayout.DESIGN_SIZE.x - IntroLayout.PROMPT_MARGIN), "de regel rechtsonder eindigt een marge van de rand")
	test.check(is_equal_approx(footer.y, IntroLayout.DESIGN_SIZE.y - IntroLayout.PROMPT_MARGIN), "en staat een marge van onderen")
	var subtitle := IntroLayout.subtitle_position()
	test.check(subtitle.x == 0.0 and subtitle.y > IntroLayout.DESIGN_SIZE.y * 0.5 and subtitle.y + IntroLayout.SUBTITLE_HEIGHT < IntroLayout.DESIGN_SIZE.y, "de ondertitel onder het midden, in beeld")
	test.check(IntroLayout.CRAWL_REST > 0.0 and IntroLayout.CRAWL_REST < 1.0 and IntroLayout.CRAWL_FAR_WIDTH < 1.0 and IntroLayout.CRAWL_SCREEN_TOP < 0.5, "het verhaal: smal in de verte, rust in het beeld")
