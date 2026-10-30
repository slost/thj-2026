## One line of the guided battle. Reorder them in tutorial_steps.gd.
class_name TutorialStep
extends Resource

enum Wait {
	NONE,
	CONFIRM,
	SUMMONED_UNIT,
	UNIT_SPAWN_FINISHED,
	UNIT_SELECTED,
	MOVE_ORDER_ISSUED,
	UNIT_RAM_FULL,
	UNIT_SACRIFICED,
	CODE_OPENED,
	PAGE_OPENED,
	SCRIPT_HAS_ACTION,
	BATTLE_WON,
}

@export var id: String = ""
@export var text_key: String = ""
## spell_bar, resource_bar, unit, field, unit_bars, script_panel_stats,
## script_panel_queue, script_panel_ram, sacrifice_button, code_button,
## page_buttons, summoning_page_button, thinking_page_button, rune_palette,
## city_progress, or none.
@export var focus_id: String = "none"
@export var wait: Wait = Wait.CONFIRM
## Editor page index. 0 is Summoning, 1 is Thinking. Used by PAGE_OPENED.
@export var wait_page: int = -1
@export var locked: bool = false
@export var setup_only: bool = false
## The next step stays hidden until this has already happened.
@export var enter_wait: Wait = Wait.NONE
## Pressing Next runs the then-fields and waits for this instead of advancing.
@export var then_wait: Wait = Wait.NONE
@export var collapse_after_confirm: bool = false
@export var stage_end: bool = false
## After PAGE_OPENED of wait_page, the highlight moves here. Empty keeps focus_id.
@export var focus_after_page: String = ""

@export var clear_runes: bool = false
@export var set_wallet: bool = false
@export var wallet_corpse: int = 0
@export var wallet_gore: int = 0
@export var slot_ram: int = -1
@export var grant_rune_ids: PackedStringArray = PackedStringArray()
@export var grant_corpse: int = 0
@export var grant_gore: int = 0
@export var spawn_villager_count: int = 0
@export var top_up_resources: bool = false
@export var show_rewards: bool = false

@export var apply_summon_cap: bool = false
@export var summon_cap: int = -1
@export var apply_order_cap: bool = false
@export var order_cap: int = -1
@export var reset_orders: bool = false
@export var apply_visible_spells: bool = false
@export var visible_spells: int = 8
## Slots from this index upward stay on screen but cannot be summoned.
@export var apply_unlocked_spells: bool = false
@export var unlocked_spells: int = 1

@export var show_sacrifice: bool = false
@export var hide_sacrifice: bool = false
@export var enable_code: bool = false
@export var disable_code: bool = false

@export var panel_script: bool = true
@export var panel_stats: bool = true
@export var panel_queue: bool = true
@export var panel_ram: bool = true
@export var apply_panel: bool = false
## stats, queue, ram, or script. Empty leaves every visible section at full strength.
@export var panel_highlight: String = ""
## Keep the tutorial minion pinned while this step is showing.
@export var pin_minion: bool = false
## Cut a second hole around the minion, on top of focus_id.
@export var highlight_unit: bool = false
## The field flag cannot close the book while this step is showing.
@export var lock_code_exit: bool = false
## The one allowed move order walks a couple of cells, not to the clicked spot.
@export var short_move: bool = false
