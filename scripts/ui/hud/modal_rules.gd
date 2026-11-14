extends RefCounted
## The rules of the screens of the HUD that hold the game (logic; docs/CODE_LAGEN.md): the
## reward screen, the level-up screen, the story box and the shop. When a waiting reward
## or level up may open, whether the game stays paused when one of them closes, and when
## such a screen lies over the game menu. The HUD (scripts/ui/hud.gd) keeps the queues and
## says what is showing: a Dictionary of plain booleans as nothing_showing gives it.
##   const ModalRules = preload("res://scripts/ui/hud/modal_rules.gd")

## The screens that hold the game, as they are named in `showing`.
const REWARD := "reward"
const LEVEL_UP := "level_up"
const STORY := "story"
const SHOP := "shop"
const SCREENS := [REWARD, LEVEL_UP, STORY, SHOP]


## What can be showing, nothing of it up: the four screens, "conversation" (the story box
## is in a conversation, not on the pages of a story or a mission), "pause_menu", "death",
## "game_menu", "machine" (the close-up of a machine's screen) and "loading".
static func nothing_showing() -> Dictionary:
	return {REWARD: false, LEVEL_UP: false, STORY: false, SHOP: false, "conversation": false,
		"pause_menu": false, "death": false, "game_menu": false, "machine": false, "loading": false}


## Whether a reward or a level up has to wait: not over the pages of a story or a mission
## (its own pages come first), the pause menu, the death screen, a machine's close-up or
## the loading screen. Over a conversation, the shop and the game menu it comes.
static func must_wait(showing: Dictionary) -> bool:
	if showing[STORY] and not showing["conversation"]:
		return true
	return showing["death"] or showing["pause_menu"] or showing["machine"] or showing["loading"]


## Whether the next of `rewards_waiting` rewards may open now: one at a time, and not
## while a level up is on.
static func can_open_reward(rewards_waiting: int, showing: Dictionary) -> bool:
	return rewards_waiting > 0 and not showing[REWARD] and not showing[LEVEL_UP] and not must_wait(showing)


## Whether the next of `level_ups_waiting` level ups may open now: as a reward, and only
## once the rewards waiting have been shown.
static func can_open_level_up(level_ups_waiting: int, rewards_waiting: int, showing: Dictionary) -> bool:
	return level_ups_waiting > 0 and rewards_waiting == 0 and not showing[LEVEL_UP] and not showing[REWARD] and not must_wait(showing)


## The experience of `reward` that goes onto the level-up screen in place of a reward of
## its own (one screen for both): all of it while a level up waits, else none.
static func xp_for_level_up(reward: Dictionary, level_ups_waiting: int) -> int:
	var xp := int(reward.get("xp", 0))
	return xp if xp > 0 and level_ups_waiting > 0 else 0


## Whether the game stays paused when the screen `closing` (one of SCREENS) closes: only
## while another of them is still up, or the pause menu, or the game menu (the shop is
## never over the game menu). Never from a state remembered when it opened: the town
## would stand still.
static func keeps_paused(closing: String, showing: Dictionary) -> bool:
	for screen: String in SCREENS:
		if screen != closing and showing[screen]:
			return true
	if showing["pause_menu"]:
		return true
	return closing != SHOP and showing["game_menu"]


## Whether a conversation in the story box waits (under the reward or the level-up screen;
## it goes on where it was after it).
static func is_story_on_hold(showing: Dictionary) -> bool:
	return showing[REWARD] or showing[LEVEL_UP]


## True while the story box, the reward screen or the level-up screen shows with the game
## menu open (a thought about opening the inventory, a reward got meanwhile).
static func is_modal_over_menu(game_menu_open: bool, story: bool, reward: bool, level_up: bool) -> bool:
	return game_menu_open and (story or reward or level_up)


## The layer of the game menu: its own (over the HUD), or just under the HUD while one of
## the HUD's screens lies over it.
static func menu_layer(modal_over_menu: bool, hud_layer: int, own_layer: int) -> int:
	return hud_layer - 1 if modal_over_menu else own_layer
