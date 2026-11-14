extends RefCounted
## The colours the screens before the game share (the intro, the main menu and the
## character creation): the night sky, its stars and the soft texts (graphics, only data;
## docs/CODE_LAGEN.md). The colours of the HUD's style are in scripts/ui/ui_style.gd.
##   const MenuLook = preload("res://scripts/ui/menu/menu_look.gd")

## The night sky behind the menu and the character creation.
const SKY := Color("#0E1130")
## The stars: the big ones and the small ones.
const STAR_BRIGHT := Color("#F2E8C9")
const STAR_DIM := Color("#8A90C0")
## The big titles ("ZWERVR", "KIES JE KARAKTER", the name of a character).
const TITLE_COLOUR := Color("#F4EEDD")
## Small texts: the footer with the keys, the credits.
const SOFT_TEXT := Color("#C9CCE6")
const MUTED_TEXT := Color("#9AA0C8")
