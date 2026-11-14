extends RefCounted
## Unit tests of the moments of the intro music (scripts/ui/intro_timing.gd): they follow
## each other and fall within the music.
##   tests/run_unit_tests.sh intro_timing

const IntroTiming = preload("res://scripts/ui/intro_timing.gd")


func test_the_moments_of_the_intro_follow_each_other(test) -> void:
	var moments := [IntroTiming.LOGO_AT, IntroTiming.CRAWL_AT, IntroTiming.CLIMAX_AT, IntroTiming.DUEL_AT,
			IntroTiming.CRASH_AT, IntroTiming.REST_AT, IntroTiming.END_AT]
	test.check(moments[0] > 0.0, "het logo komt niet meteen")
	for moment_index in range(1, moments.size()):
		test.check(moments[moment_index] > moments[moment_index - 1], "moment %d komt na het vorige (%s)" % [moment_index, moments[moment_index]])
	var music_path := "res://assets/audio/muziek/zwervr_intro.ogg"
	if ResourceLoader.exists(music_path):
		var music: AudioStream = load(music_path)
		test.check(IntroTiming.END_AT <= music.get_length() + 0.05, "het eind valt binnen de muziek (%s van %s s)" % [IntroTiming.END_AT, music.get_length()])
