extends RefCounted
## The logic of the loading screen (the rules layer of scripts/ui/loading_screen.gd, which
## is the behaviour; loading_screen_layout.gd has the sizes, loading_screen_view.gd builds
## and shows it): how the line with what is loading reads, how far it is as a percentage,
## and which CRT setting it takes. Plain functions, without nodes.
##   const LoadingScreenRules = preload("res://scripts/ui/screens/loading_screen_rules.gd")

## The title over what is loading.
const TITLE := "ZWERVR"


## The line with what is loading: `text` ("Stad laden…") in capitals without the ellipsis,
## between dashes ("— STAD LADEN —").
static func heading(text: String) -> String:
	return "— " + text.trim_suffix("…").to_upper() + " —"


## How far it is (`share_done` 0..1) as a percentage, rounded down: only 100% when it is done.
static func percentage_text(share_done: float) -> String:
	return "%d%%" % floori(100.0 * share_done)


## A setting of the HUD (`value`: what the HUD has for it, null without a HUD or without
## that setting), or `default`.
static func setting(value: Variant, default: float) -> float:
	return float(value) if value != null else default
