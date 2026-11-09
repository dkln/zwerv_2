extends RefCounted
## Shows how far a long job of a tool is, in the style of Godot's own import lines:
##   [ 42% ] bibliotheek gebouwen: tiles laden  540/1290  nog ~25 s  (overheid_dak_rand)
## A job shorter than SHOW_AFTER s prints nothing (so the editor plugin stays quiet on a small
## update); after that a line per SHOW_STEP_PERCENT of the job or every SHOW_EVERY s (never more
## often than SHOW_AT_MOST s), and a last line when it is done.
##   var progress := Progress.new("previews grond", todo.size())
##   for tile in todo:
##       ...
##       progress.step(tile_name)
##   progress.finish()
## A job without countable steps: Progress.new(label, 100) and set_done(fraction * 100).

const SHOW_AFTER := 1.0
const SHOW_EVERY := 10.0
const SHOW_STEP_PERCENT := 5
const SHOW_AT_MOST := 1.0

var label: String
var total: int
var done := 0
var _started_msec := 0
var _last_shown_msec := 0
var _last_shown_percent := -100
var _shown := false


func _init(job_label: String, step_total: int) -> void:
	label = job_label
	total = maxi(step_total, 0)
	_started_msec = Time.get_ticks_msec()
	_last_shown_msec = _started_msec


## One (or `amount`) step further; `item` is shown with the line (what was just done).
func step(item := "", amount := 1) -> void:
	set_done(done + amount, item)


func set_done(steps_done: int, item := "") -> void:
	done = clampi(steps_done, 0, maxi(total, steps_done))
	var now := Time.get_ticks_msec()
	var since_last := (now - _last_shown_msec) / 1000.0
	if (now - _started_msec) / 1000.0 < SHOW_AFTER or since_last < SHOW_AT_MOST:
		return
	if _percent() - _last_shown_percent < SHOW_STEP_PERCENT and since_last < SHOW_EVERY:
		return
	_last_shown_msec = now
	_last_shown_percent = _percent()
	_print_line(item, now)


## A line about a new stage of the job ("atlas maken"), only once the job is being shown.
func stage(text: String) -> void:
	if _shown or (Time.get_ticks_msec() - _started_msec) / 1000.0 >= SHOW_AFTER:
		_shown = true
		print("[  ..  ] %s: %s" % [label, text])


## The last line, with the time it took (only if anything was shown, or it took long).
func finish() -> void:
	var seconds := (Time.get_ticks_msec() - _started_msec) / 1000.0
	if _shown or seconds >= SHOW_AFTER:
		print("[ 100%% ] %s  %d/%d  klaar in %s" % [label, total, total, _duration(seconds)])


func _percent() -> int:
	return int(100.0 * done / total) if total > 0 else 0


func _print_line(item: String, now: int) -> void:
	_shown = true
	var share := float(done) / total if total > 0 else 0.0
	var line := "[ %3d%% ] %s  %d/%d" % [int(share * 100.0), label, done, total]
	var seconds := (now - _started_msec) / 1000.0
	if share > 0.02:
		line += "  nog ~%s" % _duration(seconds / share - seconds)
	if not item.is_empty():
		line += "  (%s)" % item
	print(line)


static func _duration(seconds: float) -> String:
	if seconds < 60.0:
		return "%d s" % ceili(seconds)
	if seconds < 3600.0:
		return "%d min %02d s" % [int(seconds / 60.0), int(seconds) % 60]
	return "%d u %02d min" % [int(seconds / 3600.0), int(seconds / 60.0) % 60]
