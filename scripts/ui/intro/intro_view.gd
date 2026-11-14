extends Control
## How the intro looks (the graphics layer of scripts/ui/intro.gd, which is the behaviour
## and has this as its child; intro_rules.gd has the logic, intro_layout.gd the sizes):
## black, and on it, laid out at the design's size and scaled to the window: the stars, the
## opening line in teal, the logo (ZWERVR in amber outline, dark inside, as the letters of
## a space saga, with a hard ink shadow), the twinkle where it vanishes, the story in amber
## (drawn into a picture of its own, a SubViewport, that a shader lays on the screen as a
## plane going away from the viewer), the context action bottom left (ActionPrompts) and
## the secondary action bottom right, and the CRT look over all of it. It builds them and
## shows what it is handed (show_...); it decides nothing. What drifts through space is
## put between the twinkle and the story (add_behind_story; drifter.gd).
##   const IntroView = preload("res://scripts/ui/intro/intro_view.gd")

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const GraphicsSettings = preload("res://scripts/ui/graphics_settings.gd")
const MenuLook = preload("res://scripts/ui/menu/menu_look.gd")
const ScreenLayout = preload("res://scripts/ui/menu/screen_layout.gd")
const ScreenCrtView = preload("res://scripts/ui/menu/screen_crt_view.gd")
const IntroLayout = preload("res://scripts/ui/intro/intro_layout.gd")

const TITLE := "ZWERVR"
const SUBTITLE := "EEN ZWERFTOCHT"
const LINE_FONT_SIZE := 30
const LOGO_FONT_SIZE := 230
const LOGO_OUTLINE := 14
const LOGO_SHADOW := 10
const LOGO_SPACING := 8
const SUBTITLE_FONT_SIZE := 22
const STORY_FONT_SIZE := 46
const FOOTER_FONT_SIZE := 11
## The story's picture laid on the screen as a plane going away from the viewer: the
## bottom edge the width of the screen, the far top edge `far_width` of it, the rows
## squeezed with distance as perspective does, fading out far off.
const CRAWL_SHADER := """shader_type canvas_item;
uniform sampler2D crawl : filter_linear, repeat_disable;
uniform float far_width = 0.22;
uniform float screen_top = 0.08;

void fragment() {
	// 0 at the far top edge of the plane, 1 at the bottom of the screen
	float down = clamp((UV.y - screen_top) / (1.0 - screen_top), 0.0, 1.0);
	float row_width = mix(far_width, 1.0, down);
	float across = (UV.x - 0.5) / row_width + 0.5;
	// distance along the plane: 1 / width, from 1 at the bottom to 1 / far_width far off
	float depth = (1.0 / row_width - 1.0) / (1.0 / far_width - 1.0);
	vec2 picture_uv = vec2(across, 1.0 - depth);
	vec4 text = texture(crawl, picture_uv);
	float inside = step(0.0, across) * step(across, 1.0) * step(screen_top, UV.y);
	float fade = smoothstep(0.0, 0.35, down);
	COLOR = vec4(text.rgb, text.a * inside * fade);
}
"""

var _design: Control
var _stars: Control
var _line: Label
var _logo_holder: Control
var _sparkle: Control   # the twinkle where the logo vanishes
var _sparks: Array[ColorRect] = []
var _crawl_text: VBoxContainer   # the story in its picture, rolled up by show_story_at
var _crawl_screen: ColorRect     # that picture laid on the screen in perspective
var _prompts: ActionPrompts
var _fast_footer: Label
var _crt: ScreenCrtView


func _init() -> void:
	name = "Beeld"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	_design = Control.new()
	_design.name = "Ontwerp"
	_design.size = IntroLayout.DESIGN_SIZE
	_design.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_design)
	_stars = _plain_holder()
	_build_line()
	_build_logo()
	_build_sparkle()
	_build_crawl()
	_build_prompts()
	_crt = ScreenCrtView.new()
	add_child(_crt)


# ------------------------------------------------------------------ told what to show

## The stars of the sky (IntroLayout.stars: where, how big), in place of the ones there were.
func show_star_field(stars: Array) -> void:
	for star in _stars.get_children():
		star.free()
	for spec: Dictionary in stars:
		var star := ColorRect.new()
		star.position = spec.position
		star.size = spec.size
		star.color = MenuLook.STAR_BRIGHT if spec.big else MenuLook.STAR_DIM
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stars.add_child(star)


## The texts: the opening line and the story, a paragraph per entry.
func show_texts(opening_line: String, story: Array) -> void:
	_line.text = opening_line
	for paragraph in _crawl_text.get_children():
		paragraph.free()
	var font := UiStyle.weighted(UiStyle.font(UiStyle.FONT_TITLE), 700)
	for paragraph: String in story:
		var label := Label.new()
		label.text = paragraph
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(IntroLayout.CRAWL_PICTURE.x, 0)
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", STORY_FONT_SIZE)
		label.add_theme_color_override("font_color", UiStyle.ACCENT)
		label.add_theme_constant_override("line_spacing", IntroLayout.LINE_SPACING)
		_crawl_text.add_child(label)


## The context actions bottom left ([key, what it does] each) and the text of the
## secondary action bottom right.
func show_actions(actions: Array, fast_text: String) -> void:
	_prompts.set_actions(actions)
	_fast_footer.text = fast_text


## The CRT look on or off.
func show_crt(on: bool) -> void:
	_crt.show_crt(on)


## The design scaled to the window (`window`: its size).
func show_window(window: Vector2) -> void:
	_design.scale = Vector2.ONE * ScreenLayout.scale_in(window)
	_design.position = ScreenLayout.position_in(window)
	_crt.show_screen_size(window)


## How much the opening line shows (0 .. 1).
func show_line(alpha: float) -> void:
	_line.modulate.a = alpha


## The stars there or not, and how much they show (0 .. 1).
func show_stars(shown: bool, alpha: float) -> void:
	_stars.visible = shown
	_stars.modulate.a = alpha


## How bright each star is now (0 .. 1), in the order of show_star_field.
func show_twinkles(alphas: Array) -> void:
	for star_index in mini(alphas.size(), _stars.get_child_count()):
		(_stars.get_child(star_index) as CanvasItem).modulate.a = alphas[star_index]


## The logo there or not, `enlarged` times as big (about the middle), showing `alpha`.
func show_logo(shown: bool, enlarged: float, alpha: float) -> void:
	_logo_holder.visible = shown
	if shown:
		_logo_holder.scale = Vector2.ONE * enlarged
		_logo_holder.modulate.a = alpha


## The story there or not, the top of its text at `text_top` in its picture, showing `alpha`.
func show_story_at(shown: bool, text_top: float, alpha: float) -> void:
	_crawl_screen.visible = shown
	if shown:
		_crawl_text.position.y = text_top
		_crawl_screen.modulate.a = alpha


## The twinkle where the logo vanishes, there or not: at `twinkling` (0 .. 1 of its time),
## `flare` bright (0 .. 1), its sparks flying out and fading.
func show_sparkle(shown: bool, twinkling: float, flare: float) -> void:
	_sparkle.visible = shown
	for spark_index in _sparks.size():
		var spark := _sparks[spark_index]
		spark.visible = shown
		if shown:
			spark.position = IntroLayout.spark_position(spark_index, _sparks.size(), twinkling, spark.size)
			spark.modulate.a = 1.0 - twinkling
	if shown:
		_sparkle.scale = Vector2.ONE * IntroLayout.sparkle_scale(flare)
		_sparkle.rotation = IntroLayout.sparkle_rotation(twinkling)
		_sparkle.modulate.a = flare


## The secondary action bottom right there or not.
func show_fast_offer(shown: bool) -> void:
	_fast_footer.visible = shown


## Puts `node` (what drifts through space) over the stars and the twinkle, under the story.
func add_behind_story(node: Control) -> void:
	_design.add_child(node)
	_design.move_child(node, _crawl_screen.get_index())


# ------------------------------------------------------------------ asked what it shows

## The tops of the paragraphs of the story in its text (pixels), in their order.
func paragraph_tops() -> Array[float]:
	var tops: Array[float] = []
	for paragraph in _crawl_text.get_children():
		tops.append((paragraph as Control).position.y)
	return tops


## How high the whole text of the story is (pixels).
func story_height() -> float:
	return _crawl_text.size.y


func stars_visible() -> bool:
	return _stars.visible


## The parts, for whoever looks at what is shown (the tests).
func design() -> Control:
	return _design


func stars() -> Control:
	return _stars


func line() -> Label:
	return _line


func logo() -> Control:
	return _logo_holder


func sparkle() -> Control:
	return _sparkle


func sparks() -> Array[ColorRect]:
	return _sparks


func story_text() -> VBoxContainer:
	return _crawl_text


func story_screen() -> ColorRect:
	return _crawl_screen


func prompts() -> ActionPrompts:
	return _prompts


func fast_footer() -> Label:
	return _fast_footer


func crt() -> ScreenCrtView:
	return _crt


# ------------------------------------------------------------------ building

func _plain_holder() -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.visible = false
	_design.add_child(holder)
	return holder


func _build_line() -> void:
	_line = Label.new()
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # too wide for the picture: two lines
	_line.size = IntroLayout.DESIGN_SIZE
	_line.add_theme_font_override("font", UiStyle.weighted(UiStyle.font(UiStyle.FONT_TITLE), 500))
	_line.add_theme_font_size_override("font_size", LINE_FONT_SIZE)
	_line.add_theme_color_override("font_color", UiStyle.SIDE_ACCENT)
	_line.modulate.a = 0.0
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_design.add_child(_line)


## The logo: ZWERVR in amber outline (dark inside), with a hard ink shadow, filling the
## width of the screen; scaled about the middle.
func _build_logo() -> void:
	_logo_holder = _plain_holder()
	_logo_holder.size = IntroLayout.DESIGN_SIZE
	_logo_holder.pivot_offset = IntroLayout.DESIGN_SIZE * 0.5
	var logo := Label.new()
	logo.text = TITLE
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	logo.size = IntroLayout.DESIGN_SIZE
	logo.add_theme_font_override("font", UiStyle.spaced(UiStyle.weighted(UiStyle.font(UiStyle.FONT_TITLE), 700), LOGO_SPACING))
	logo.add_theme_font_size_override("font_size", LOGO_FONT_SIZE)
	logo.add_theme_color_override("font_color", Color.BLACK)
	logo.add_theme_color_override("font_outline_color", UiStyle.ACCENT)
	logo.add_theme_constant_override("outline_size", LOGO_OUTLINE)
	logo.add_theme_color_override("font_shadow_color", UiStyle.INK)
	logo.add_theme_constant_override("shadow_offset_x", LOGO_SHADOW)
	logo.add_theme_constant_override("shadow_offset_y", LOGO_SHADOW)
	logo.add_theme_constant_override("shadow_outline_size", LOGO_OUTLINE)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo_holder.add_child(logo)
	var subtitle := Label.new()
	subtitle.text = SUBTITLE
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.size = Vector2(IntroLayout.DESIGN_SIZE.x, IntroLayout.SUBTITLE_HEIGHT)
	subtitle.position = IntroLayout.subtitle_position()
	subtitle.add_theme_font_override("font", UiStyle.spaced(UiStyle.font(UiStyle.FONT_PIXEL), LOGO_SPACING))
	subtitle.add_theme_font_size_override("font_size", SUBTITLE_FONT_SIZE)
	subtitle.add_theme_color_override("font_color", UiStyle.ACCENT)
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo_holder.add_child(subtitle)


## The twinkle where the logo vanishes: two crossing bars of pixels (long and thin, as the
## rays of a star), a bright core, and the sparks round it.
func _build_sparkle() -> void:
	_sparkle = _plain_holder()
	_sparkle.position = IntroLayout.DESIGN_SIZE * 0.5
	for ray in IntroLayout.sparkle_rays():
		_sparkle.add_child(_block(ray, -ray * 0.5, MenuLook.STAR_BRIGHT))
	var core_size := Vector2.ONE * IntroLayout.CORE
	_sparkle.add_child(_block(core_size, -core_size * 0.5, Color.WHITE))
	for _spark_index in IntroLayout.SPARKLE_SPARKS:
		var spark := _block(Vector2.ONE * IntroLayout.SPARK, Vector2.ZERO, MenuLook.STAR_BRIGHT)
		spark.visible = false
		_design.add_child(spark)
		_sparks.append(spark)


static func _block(block_size: Vector2, at: Vector2, colour: Color) -> ColorRect:
	var block := ColorRect.new()
	block.size = block_size
	block.position = at
	block.color = colour
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return block


## The story: its text in a picture of its own (in amber, a paragraph per entry:
## show_texts), and that picture laid on the screen in perspective (CRAWL_SHADER).
func _build_crawl() -> void:
	var picture := SubViewport.new()
	GraphicsSettings.plain_3d(picture)
	picture.name = "Verhaalbeeld"
	picture.size = IntroLayout.CRAWL_PICTURE
	picture.transparent_bg = true
	picture.disable_3d = true
	picture.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(picture)
	_crawl_text = VBoxContainer.new()
	_crawl_text.add_theme_constant_override("separation", IntroLayout.PARAGRAPH_GAP)
	_crawl_text.size = Vector2(IntroLayout.CRAWL_PICTURE.x, 0)
	_crawl_text.position = Vector2(0, IntroLayout.CRAWL_PICTURE.y)
	picture.add_child(_crawl_text)
	_crawl_screen = ColorRect.new()
	_crawl_screen.name = "Verhaal"
	_crawl_screen.size = IntroLayout.DESIGN_SIZE
	_crawl_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crawl_screen.visible = false
	var shader := Shader.new()
	shader.code = CRAWL_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("crawl", picture.get_texture())
	material.set_shader_parameter("far_width", IntroLayout.CRAWL_FAR_WIDTH)
	material.set_shader_parameter("screen_top", IntroLayout.CRAWL_SCREEN_TOP)
	_crawl_screen.material = material
	_design.add_child(_crawl_screen)


## Bottom left the context action of the game (ActionPrompts); bottom right, as the footer
## of the main menu, the secondary action in small pixel text.
func _build_prompts() -> void:
	_prompts = ActionPrompts.new()
	_prompts.name = "Toetsen"
	_prompts.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_prompts.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompts.offset_left = IntroLayout.PROMPT_MARGIN
	_prompts.offset_bottom = -IntroLayout.PROMPT_MARGIN
	_design.add_child(_prompts)
	_fast_footer = Label.new()
	_fast_footer.name = "Sneller"
	_fast_footer.add_theme_font_override("font", UiStyle.font(UiStyle.FONT_PIXEL))
	_fast_footer.add_theme_font_size_override("font_size", FOOTER_FONT_SIZE)
	_fast_footer.add_theme_color_override("font_color", MenuLook.SOFT_TEXT)
	_fast_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fast_footer.size = IntroLayout.FOOTER_SIZE
	_fast_footer.position = IntroLayout.footer_position()
	_fast_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fast_footer.visible = false
	_design.add_child(_fast_footer)
