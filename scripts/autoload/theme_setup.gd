# Builds a global Theme at boot — Pretendard font + dark palette inspired
# by the Electron version's Tailwind scheme. Applied via get_tree().root.theme
# so every Control auto-inherits.
#
# Building in code (rather than a hand-authored .tres) keeps the styling
# greppable and avoids the unstable .tres binary diffs.

extends Node

# Runtime load (not preload) so the first --import pass can complete before
# the OTF .import metadata is required — preload is evaluated at parse time
# and fails on a cold project tree.
const FONT_REGULAR_PATH := "res://assets/fonts/Pretendard-Regular.otf"
const FONT_BOLD_PATH := "res://assets/fonts/Pretendard-Bold.otf"
# Japanese fallback — Pretendard has no kana/kanji, so quiz content tofu'd on iOS
# (no OS font fallback there). Attached as a fallback so Korean UI keeps
# Pretendard and Japanese glyphs resolve through Noto Sans JP.
const FONT_JP_REGULAR_PATH := "res://assets/fonts/NotoSansJP-Regular.woff2"
const FONT_JP_BOLD_PATH := "res://assets/fonts/NotoSansJP-Bold.woff2"

# Tailwind-ish dark palette (matches study_game Electron --color-* tokens)
const C_BG        := Color("#0c111c")  # zinc-950 ish
const C_PANEL     := Color("#1a1f2b")  # surface
const C_PANEL_2   := Color("#22293a")  # raised
const C_BORDER    := Color("#374151")
const C_TEXT      := Color("#e5e7eb")
const C_MUTED     := Color("#9ca3af")
const C_ACCENT    := Color("#60a5fa")  # primary blue
const C_ACCENT_SOFT := Color("#1e3a8a")
const C_DANGER    := Color("#f87171")
const C_OK        := Color("#4ade80")
const C_WARN      := Color("#fbbf24")


func _ready() -> void:
	var theme := Theme.new()
	var font_regular: Font = load(FONT_REGULAR_PATH) as Font
	var font_bold: Font = load(FONT_BOLD_PATH) as Font

	# Attach the Japanese fallback so missing glyphs (kana/kanji) resolve instead
	# of rendering as tofu boxes on platforms without OS font fallback (iOS).
	var jp_regular: Font = load(FONT_JP_REGULAR_PATH) as Font
	var jp_bold: Font = load(FONT_JP_BOLD_PATH) as Font
	if font_regular and jp_regular:
		font_regular.fallbacks = [jp_regular]
	if font_bold and jp_bold:
		font_bold.fallbacks = [jp_bold]

	# ─ Default font (skip if asset import not ready — falls back to Godot default)
	if font_regular:
		theme.default_font = font_regular
	theme.default_font_size = 16

	# ─ Label
	theme.set_color("font_color", "Label", C_TEXT)

	# ─ Button (idle / hover / pressed / disabled)
	var btn_normal := _stylebox(C_PANEL_2, C_BORDER, 6)
	var btn_hover := _stylebox(C_PANEL_2.lightened(0.08), C_ACCENT, 6)
	var btn_pressed := _stylebox(C_ACCENT_SOFT, C_ACCENT, 6)
	var btn_disabled := _stylebox(C_PANEL, C_BORDER, 6)
	btn_disabled.bg_color.a = 0.5
	theme.set_stylebox("normal", "Button", btn_normal)
	theme.set_stylebox("hover", "Button", btn_hover)
	theme.set_stylebox("pressed", "Button", btn_pressed)
	theme.set_stylebox("focus", "Button", _stylebox(C_PANEL_2, C_ACCENT, 6))
	theme.set_stylebox("disabled", "Button", btn_disabled)
	theme.set_color("font_color", "Button", C_TEXT)
	theme.set_color("font_hover_color", "Button", C_TEXT)
	theme.set_color("font_pressed_color", "Button", C_TEXT)
	theme.set_color("font_disabled_color", "Button", C_MUTED)
	if font_regular:
		theme.set_font("font", "Button", font_regular)
	theme.set_font_size("font_size", "Button", 16)

	# ─ OptionButton (theme dropdown)
	theme.set_stylebox("normal", "OptionButton", btn_normal)
	theme.set_stylebox("hover", "OptionButton", btn_hover)
	theme.set_stylebox("pressed", "OptionButton", btn_pressed)
	theme.set_color("font_color", "OptionButton", C_TEXT)

	# ─ PanelContainer (feedback box)
	theme.set_stylebox("panel", "PanelContainer", _stylebox(C_PANEL, C_BORDER, 8))

	# ─ Panel
	theme.set_stylebox("panel", "Panel", _stylebox(C_PANEL, C_BORDER, 6))

	# ─ ProgressBar (boss HP bar)
	var pb_bg := _stylebox(Color("#1f2937"), Color("#374151"), 4)
	var pb_fg := _stylebox(C_OK, Color("#1c8546"), 4)
	theme.set_stylebox("background", "ProgressBar", pb_bg)
	theme.set_stylebox("fill", "ProgressBar", pb_fg)

	# ─ Window background (root viewport background)
	RenderingServer.set_default_clear_color(C_BG)

	get_tree().root.theme = theme

	# ─ Force the actual OS window to the design resolution (1280x800) and center.
	# Windows DPI scaling at 125-150% otherwise shrinks the window to ~1024x648,
	# which clips bottom buttons in Home. Doing this in code is more reliable than
	# project.godot's window_*_override (which is ignored under hidpi scaling).
	if DisplayServer.get_name() != "headless":
		var target_size := Vector2i(1280, 800)
		DisplayServer.window_set_size(target_size)
		var screen_size := DisplayServer.screen_get_size()
		DisplayServer.window_set_position((screen_size - target_size) / 2)


# Helper — FlatStyleBox with bg color, border color, corner radius
static func _stylebox(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb
