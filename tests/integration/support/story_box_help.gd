extends RefCounted
## What the suites that talk to people share (the story box of the HUD, scripts/ui/story_box.gd,
## with a conversation in it, scripts/story/conversations.gd): the page it shows, making a
## choice, closing it, and whether a reply is all in view.


## The page the story box shows now.
static func page(box: Node) -> Dictionary:
	return box._pages[box._page_index]


## Makes the choice with the text `choice_text` on the page shown (the line typed out
## first) and returns the page that follows.
static func choose(box: Node, choice_text: String) -> Dictionary:
	box._typewriter.finish()
	box._choose((page(box).choices as Array).find(choice_text))
	box._say_choice()
	return page(box)


## Closes the story box whatever it shows (to its last page and past it).
static func close(box: Node) -> void:
	if not box.is_showing():
		return
	box._pages = box._pages.slice(-1)
	box._page_index = 0
	box._next_page()


## Waits (game time; the timers run while the game is paused) until the line has typed out
## and the scroll has settled on it (StoryBox.FOLLOW_AFTER).
static func typed_out_and_settled(tree: SceneTree, box: Node) -> void:
	for attempt in 120:
		if box._typewriter.is_done():
			break
		await tree.create_timer(0.05, true).timeout
	await tree.create_timer(box.FOLLOW_AFTER + 0.2, true).timeout


## Where the newest line stands in the view of the box, in the box's own (design) pixels
## (headless the window is tiny, the layout is not): {"top", "bottom", "view_height",
## "in_view": its end in view, and its start too when the whole line fits}.
static func reply_in_view(box: Node) -> Dictionary:
	var reply_top: float = box._text.position.y - box._scroll.scroll_vertical
	var reply_bottom: float = reply_top + box._text.size.y
	var view_height: float = box._scroll.size.y
	var whole_fits: bool = box._text.size.y <= view_height
	return {"top": reply_top, "bottom": reply_bottom, "view_height": view_height,
		"in_view": reply_bottom <= view_height + 1.0 and (reply_top >= -1.0 or not whole_fits)}
