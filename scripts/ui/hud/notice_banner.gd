extends Control
## The notice at the top of the HUD (the node "NieuwGebied", top centre; behaviour,
## docs/CODE_LAGEN.md): "nieuw gebied ontdekt" with the name of the area, "nieuwe missie"
## with its title (and a jingle: jingle_wanted, the music is the HUD's), "level omhoog", or
## a notice of its own (the floor the lift has brought you to). One at a time: the next
## waits until the one before has gone; the same name twice in a row is one notice
## (notice_rules.gd). Its picture: notice_banner_view.gd.
##   const NoticeBanner = preload("res://scripts/ui/hud/notice_banner.gd")

const NoticeRules = preload("res://scripts/ui/hud/notice_rules.gd")
const NoticeBannerView = preload("res://scripts/ui/hud/notice_banner_view.gd")

## A notice with a jingle comes up: the path of the jingle.
signal jingle_wanted(path: String)

## Its picture.
var view: NoticeBannerView

var _waiting: Array[Dictionary] = []   # NoticeRules.notice each


func _init() -> void:
	name = "NieuwGebied"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	view = NoticeBannerView.new()
	add_child(view)


## Shows a notice (NoticeRules.notice), or lets it wait for the one that is up. False when
## it is dropped: the notice that is up has the same name.
func queue(new_notice: Dictionary) -> bool:
	if NoticeRules.is_repeat(visible, view.name_text(), new_notice):
		return false
	_waiting.append(new_notice)
	if not visible:
		show_next()
	return true


## True while a notice is up.
func is_showing() -> bool:
	return visible


## How many notices wait for the one that is up.
func waiting() -> int:
	return _waiting.size()


## The notice that is up goes, and the next one waiting comes (none: the banner is gone).
func show_next() -> void:
	if _waiting.is_empty():
		view.stop()
		visible = false
		return
	var next: Dictionary = _waiting.pop_front()
	if next["jingle"] != "":
		jingle_wanted.emit(next["jingle"])
	visible = true
	view.show_notice(next["heading"], next["name"], next["seconds"], show_next)
