extends RefCounted
## Unit tests of how the sounds of the machines are made
## (scripts/ui/machines/machine_sounds_rules.gd): which sounds there are, how loud each is
## played, the waves they are made of (square, sweep, noise, silence), the samples of every
## sound and the samples as 16-bit bytes.
##   tests/run_unit_tests.sh machine_sounds_rules

const MachineSoundsRules = preload("res://scripts/ui/machines/machine_sounds_rules.gd")


func test_is_sound_knows_the_names(test) -> void:
	for sound_name: String in MachineSoundsRules.NAMES:
		test.check(MachineSoundsRules.is_sound(sound_name), "%s is een geluid" % sound_name)
	test.check(MachineSoundsRules.NAMES.size() == 9, "negen geluiden")
	test.check(not MachineSoundsRules.is_sound("bestaat_niet") and not MachineSoundsRules.is_sound(""), "een onbekende naam niet")
	for sound_name: String in MachineSoundsRules.LEVEL_TRIM_DB:
		test.check(MachineSoundsRules.is_sound(sound_name), "%s (bijgesteld in volume) bestaat" % sound_name)


func test_volume_db_adds_the_mix_the_trim_and_softer(test) -> void:
	test.check(is_equal_approx(MachineSoundsRules.volume_db("toets"), MachineSoundsRules.VOLUME_DB), "een gewoon geluid: de mix")
	test.check(is_equal_approx(MachineSoundsRules.volume_db("blik"), -9.0 - 4.8), "een te hard geluid: bijgesteld (%.1f)" % MachineSoundsRules.volume_db("blik"))
	test.check(is_equal_approx(MachineSoundsRules.volume_db("fout", -3.0), -9.0 - 2.2 - 3.0), "en zachter als dat gevraagd is")
	test.check(is_equal_approx(MachineSoundsRules.volume_db("bestaat_niet", -6.0), -15.0), "een onbekende naam: alleen de mix en zachter")


func test_samples_of_every_sound(test) -> void:
	var random := RandomNumberGenerator.new()
	for sound_name: String in MachineSoundsRules.NAMES:
		var made := MachineSoundsRules.samples(sound_name, random)
		test.check(made.size() > 0, "%s heeft samples" % sound_name)
		test.check(made == MachineSoundsRules.samples(sound_name, RandomNumberGenerator.new()), "%s: elke keer dezelfde, met welke generator ook" % sound_name)
		var loudest := 0.0
		for sample in made:
			loudest = maxf(loudest, absf(sample))
		test.check(loudest > 0.2 and loudest <= 1.0, "%s: hoorbaar en niet over vol (%.2f)" % [sound_name, loudest])
	test.check(MachineSoundsRules.samples("bestaat_niet", random).is_empty(), "een onbekend geluid: geen samples")
	test.check(MachineSoundsRules.samples("toets", random).size() == int(0.05 * MachineSoundsRules.MIX_RATE), "de toets duurt 0,05 s")
	test.check(MachineSoundsRules.samples("inslikken", random).size() > MachineSoundsRules.samples("kaart", random).size(), "inslikken duurt langer dan de kaart")
	test.check(MachineSoundsRules.samples("goed", random).size() == int(0.07 * 22050) + int(0.02 * 22050) + int(0.11 * 22050), "goed: twee piepjes met een stilte ertussen")


func test_square_wave(test) -> void:
	var made := MachineSoundsRules.square(441.0, 0.1, 0.5)
	test.check(made.size() == int(0.1 * MachineSoundsRules.MIX_RATE), "een blokgolf: zoveel samples als hij duurt")
	var loudest := 0.0
	var high_samples := 0
	for sample in made:
		loudest = maxf(loudest, absf(sample))
		if sample > 0.0:
			high_samples += 1
	test.check(loudest <= 0.5 and loudest > 0.45, "niet harder dan gevraagd (%.2f)" % loudest)
	test.check(absf(float(high_samples) / made.size() - 0.25) < 0.02, "een kwart van de tijd hoog (%.3f)" % (float(high_samples) / made.size()))
	test.check(absf(made[made.size() - 1]) < absf(made[0]), "het volume zakt weg")
	test.check(MachineSoundsRules.square(441.0, 0.0, 0.5).is_empty(), "geen duur: geen samples")


func test_sweep_starts_soft_and_slides(test) -> void:
	var made := MachineSoundsRules.sweep(200.0, 400.0, 0.2, 0.4)
	test.check(made.size() == int(0.2 * MachineSoundsRules.MIX_RATE) and made[0] == 0.0, "een glijdende toon: begint zacht")
	var loudest := 0.0
	for sample in made:
		loudest = maxf(loudest, absf(sample))
	test.check(loudest <= 0.4 and loudest > 0.3, "niet harder dan gevraagd (%.2f)" % loudest)
	var flips_early := _flips(made.slice(0, made.size() / 2))
	var flips_late := _flips(made.slice(made.size() / 2))
	test.check(flips_late > flips_early, "omhoog glijdend: later meer golven (%d tegen %d)" % [flips_late, flips_early])


func test_noise_is_the_same_every_time(test) -> void:
	var random := RandomNumberGenerator.new()
	var made := MachineSoundsRules.noise(0.1, 0.6, 4, random)
	test.check(made == MachineSoundsRules.noise(0.1, 0.6, 4, random), "ruis is elke keer dezelfde, ook met dezelfde generator")
	test.check(made == MachineSoundsRules.noise(0.1, 0.6, 4, RandomNumberGenerator.new()), "en met een nieuwe")
	test.check(made[0] == made[3] and is_equal_approx(absf(made[0]), 0.6), "en houdt zijn niveau `hold` samples vast")
	test.check(MachineSoundsRules.noise(0.01, 0.5, 0, random).size() == int(0.01 * MachineSoundsRules.MIX_RATE), "hold 0 telt als 1")
	test.check(made != MachineSoundsRules.noise(0.1, 0.6, 2, random), "een andere hold: andere ruis")
	test.check(absf(made[made.size() - 1]) < 0.1, "de ruis sterft uit")


func test_silence_is_silent(test) -> void:
	var made := MachineSoundsRules.silence(0.05)
	test.check(made.size() == int(0.05 * MachineSoundsRules.MIX_RATE) and made[0] == 0.0 and made[made.size() - 1] == 0.0, "stilte is stil")
	test.check(MachineSoundsRules.silence(0.0).is_empty(), "geen duur: niets")


func test_pcm_bytes_clips_at_full(test) -> void:
	var data := MachineSoundsRules.pcm_bytes(PackedFloat32Array([0.0, 1.0, -1.0, 5.0, 0.5]))
	test.check(data.size() == 10, "twee bytes per sample")
	test.check(data.decode_s16(0) == 0 and data.decode_s16(2) == 26000 and data.decode_s16(4) == -26000, "stil, vol en vol negatief")
	test.check(data.decode_s16(6) == 26000, "harder dan vol: afgekapt")
	test.check(data.decode_s16(8) == 13000, "half is half")
	test.check(MachineSoundsRules.pcm_bytes(PackedFloat32Array()).is_empty(), "geen samples: geen bytes")


## How often the wave changes sign.
static func _flips(samples: PackedFloat32Array) -> int:
	var count := 0
	for sample_index in range(1, samples.size()):
		if signf(samples[sample_index]) != signf(samples[sample_index - 1]) and samples[sample_index] != 0.0 and samples[sample_index - 1] != 0.0:
			count += 1
	return count
