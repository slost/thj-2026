## The guided battle, in play order.
## Add a step by appending a TutorialStep here. Reorder by moving the lines in build().
class_name TutorialSteps
extends RefCounted


static func build() -> Array[TutorialStep]:
	var steps: Array[TutorialStep] = []
	steps.append(_setup())
	steps.append(_talk("summon", "ui.tutorial.summon", "spell_bar", TutorialStep.Wait.SUMMONED_UNIT, true))
	steps.append(_talk("offering", "ui.tutorial.offering", "resource_bar", TutorialStep.Wait.CONFIRM, false))
	var select := _talk("select", "ui.tutorial.select", "unit", TutorialStep.Wait.UNIT_SELECTED, true)
	select.enter_wait = TutorialStep.Wait.UNIT_SPAWN_FINISHED
	steps.append(select)
	var move := _talk("move", "ui.tutorial.move", "field", TutorialStep.Wait.MOVE_ORDER_ISSUED, false)
	move.apply_order_cap = true
	move.order_cap = 1
	move.reset_orders = true
	move.short_move = true
	steps.append(move)
	steps.append(_talk("bars", "ui.tutorial.bars", "unit_bars", TutorialStep.Wait.CONFIRM, false))
	var cpu := _talk("cpu_gpu", "ui.tutorial.cpu_gpu", "script_panel_stats", TutorialStep.Wait.CONFIRM, false)
	_panel(cpu, false, true, false, false, "stats")
	cpu.pin_minion = true
	steps.append(cpu)
	var queue := _talk("queue", "ui.tutorial.queue", "script_panel_queue", TutorialStep.Wait.UNIT_RAM_FULL, false)
	_panel(queue, false, true, true, false, "queue")
	queue.pin_minion = true
	queue.highlight_unit = true
	queue.apply_order_cap = true
	queue.order_cap = -1
	steps.append(queue)
	var ram := _talk("ram", "ui.tutorial.ram", "script_panel_ram", TutorialStep.Wait.CONFIRM, false)
	_panel(ram, false, true, true, true, "ram")
	ram.pin_minion = true
	ram.highlight_unit = true
	steps.append(ram)
	var sacrifice := _talk("sacrifice", "ui.tutorial.sacrifice", "sacrifice_button", TutorialStep.Wait.UNIT_SACRIFICED, true)
	sacrifice.show_sacrifice = true
	sacrifice.highlight_unit = true
	_panel_all(sacrifice)
	steps.append(sacrifice)
	var book := _talk("book", "ui.tutorial.book", "code_button", TutorialStep.Wait.CODE_OPENED, true)
	book.enable_code = true
	book.lock_code_exit = true
	steps.append(book)
	var pages := _talk("two_pages", "ui.tutorial.two_pages", "page_buttons", TutorialStep.Wait.CONFIRM, false)
	pages.lock_code_exit = true
	steps.append(pages)
	var summoning := _talk("summoning_page", "ui.tutorial.summoning_page", "summoning_page_button", TutorialStep.Wait.PAGE_OPENED, false)
	summoning.lock_code_exit = true
	summoning.wait_page = 0
	steps.append(summoning)
	var thinking := _talk("thinking_page", "ui.tutorial.thinking_page", "thinking_page_button", TutorialStep.Wait.SCRIPT_HAS_ACTION, false)
	thinking.wait_page = 1
	thinking.focus_after_page = "rune_palette"
	thinking.grant_rune_ids = PackedStringArray([
		"remember_hostile", "has_remembered_target", "move_to_target", "attack_target",
	])
	thinking.apply_unlocked_spells = true
	thinking.unlocked_spells = 8
	thinking.lock_code_exit = true
	_panel(thinking, true, true, true, true, "script")
	steps.append(thinking)
	var fight := _talk("fight", "ui.tutorial.fight", "none", TutorialStep.Wait.CONFIRM, false)
	fight.then_wait = TutorialStep.Wait.BATTLE_WON
	fight.collapse_after_confirm = true
	fight.focus_id = "none"
	fight.spawn_villager_count = 3
	fight.top_up_resources = true
	fight.show_rewards = true
	fight.apply_summon_cap = true
	fight.summon_cap = -1
	steps.append(fight)
	var ending := _talk("ending", "ui.tutorial.ending", "none", TutorialStep.Wait.NONE, false)
	ending.stage_end = true
	steps.append(ending)
	return steps


static func _setup() -> TutorialStep:
	var step := TutorialStep.new()
	step.id = "setup"
	step.setup_only = true
	step.clear_runes = true
	step.set_wallet = true
	step.wallet_corpse = 6
	step.wallet_gore = 6
	step.slot_ram = 5
	step.apply_visible_spells = true
	step.visible_spells = 8
	step.apply_unlocked_spells = true
	step.unlocked_spells = 1
	step.apply_summon_cap = true
	step.summon_cap = 1
	step.apply_order_cap = true
	step.order_cap = 0
	step.hide_sacrifice = true
	step.disable_code = true
	return step


static func _talk(id: String, key: String, focus: String, wait: TutorialStep.Wait, locked: bool) -> TutorialStep:
	var step := TutorialStep.new()
	step.id = id
	step.text_key = key
	step.focus_id = focus
	step.wait = wait
	step.locked = locked
	return step


static func _panel(step: TutorialStep, script: bool, stats: bool, queue: bool, ram: bool, highlight: String) -> void:
	step.apply_panel = true
	step.panel_script = script
	step.panel_stats = stats
	step.panel_queue = queue
	step.panel_ram = ram
	step.panel_highlight = highlight


static func _panel_all(step: TutorialStep) -> void:
	_panel(step, true, true, true, true, "")
