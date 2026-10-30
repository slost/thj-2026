## Shared colors, type sizes, and spacing for the flat UI.
## Theme resources and code-built controls both read these constants.
class_name UiPalette
extends Object


# Dark necromancer field. HP red, think blue, and animation yellow match the unit bars.
const BG_DARK := Color(0.067, 0.075, 0.063, 1)
const PANEL := Color(0.12, 0.145, 0.118, 1)
const PANEL_ALT := Color(0.176, 0.208, 0.165, 1)
const ACCENT := Color(0.42, 0.78, 0.38, 1)
const ACCENT_HOVER := Color(0.56, 0.88, 0.5, 1)
const DANGER := Color(0.8, 0.1, 0.1, 1)
const INFO := Color(0.25, 0.8, 1.0, 1)
const WARN := Color(0.95, 0.72, 0.2, 1)
const TEXT := Color(0.93, 0.96, 0.91, 1)
const TEXT_MUTED := Color(0.62, 0.67, 0.58, 1)
const TEXT_ON_ACCENT := Color(0.08, 0.12, 0.06, 1)
const DISABLED_FILL := Color(0.145, 0.153, 0.137, 1)
const DISABLED_TEXT := Color(0.45, 0.48, 0.42, 1)
const CORPSE := Color(0.78, 0.74, 0.62, 1)
const GORE := Color(0.55, 0.1, 0.12, 1)

## Cream pages of the Necronomicon. Ink is for text that sits on those pages.
const PAPER := Color(0.93, 0.88, 0.76, 1)
const INK := Color(0.16, 0.12, 0.08, 1)
const INK_MUTED := Color(0.4, 0.32, 0.22, 1)

## Solid rune fills. Condition, action, and everything else.
const RUNE_CONDITION := Color(0.55, 0.74, 0.82, 1)
const RUNE_ACTION := Color(0.62, 0.78, 0.5, 1)
const RUNE_OTHER := Color(0.82, 0.7, 0.46, 1)

# Rebecca Sharp is an outline face, not a pixel grid, so these are just the four roles.
const SMALL := 16
const BODY := 32
const TITLE := 48
const HUGE := 64

const S := 8
const M := 16
const L := 32

## Distance from the screen edge for HUD chrome. Same on every aspect.
const SCREEN_MARGIN := 16
const BUTTON_HUD := 48
const BUTTON_MENU := 64
const HOTBAR_SLOT := 80
## Category stripe on a rune card. A fill, not a border.
const STRIP := 4

const FONT_PATH := "res://contents/bc-rebecca-sharp-regular.otf"


static func hex(color: Color) -> String:
	return "#%02x%02x%02x" % [
		int(round(color.r * 255.0)),
		int(round(color.g * 255.0)),
		int(round(color.b * 255.0)),
	]


static func tint(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)


## Flat locked/ruined tint: mostly gray, pulled toward the disabled panel fill.
static func dim(color: Color) -> Color:
	var gray := color.r * 0.299 + color.g * 0.587 + color.b * 0.114
	var neutral := Color(gray, gray, gray, color.a)
	return color.lerp(neutral, 0.85).lerp(DISABLED_FILL, 0.45)
