## Plays TutorialSteps on top of the battle.
## A step that waits on an action advances on its own. Confirm steps wait for Next.
## No class_name: this script reads the Game autoload.
extends Node

const _Steps := preload("res://systems/tutorial/tutorial_steps.gd")
const _TASK_DONE := preload("res://contents/audio/sfx/general/sfx_task_done.wav")

var steps: Array[TutorialStep] = []
var index := 0
var phase := 0
var next_enabled := false

var _holding_enter := false
var _saw_summon := false
var _saw_spawn_done := false
var _saw_selected := false
var _saw_move := false
var _saw_sacrifice := false
var _saw_code := false
var _saw_page := -1
var _ram_full := false
var _saw_victory := false
var _granting := false
## Tests set this false so Skip does not load the world map.
var travel_on_exit := true
var _minion: Unit2D
var _wired := false
var _advance_depth := 0

var _layer: CanvasLayer
var _dialog: PanelContainer
var _body: RichTextLabel
var _counter: Label
var _objective: Label
var _next: Button
var _dim: Array[ColorRect] = []
var _arrow: Label
var _pulse: Tween


func _ready() -> void:
	steps = _Steps.build()
	_build_ui()
	call_deferred("_boot")


func _boot() -> void:
	_wire()
	if steps.is_empty():
		return
	_enter(0)


func _process(_delta: float) -> void:
	if steps.is_empty() or index < 0 or index >= steps.size():
		return
	var step := steps[index]
	if step.pin_minion:
		_pin_minion()
	if _active_wait(step) == TutorialStep.Wait.UNIT_RAM_FULL and _minion_full():
		_ram_full = true
		_refresh_wait()
	_layout_focus()


func press_next() -> void:
	if steps.is_empty():
		return
	var step := steps[index]
	if phase == 1 and step.collapse_after_confirm and _dialog != null and _dialog.visible:
		_hide_overlay()
		return
	if not next_enabled:
		return
	if phase == 0 and step.then_wait != TutorialStep.Wait.NONE:
		phase = 1
		_apply(step, true)
		_arm(step.then_wait)
		_show_dialog(step, true)
		_refresh_wait()
		return
	_advance()


func skip() -> void:
	if Game:
		Game.skip_tutorial(travel_on_exit)


func _play_task_done() -> void:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	var audio := tree.root.get_node_or_null("Audio")
	if audio != null and audio.has_method("play_ui"):
		audio.call("play_ui", _TASK_DONE, 1.0)


func notify_summoned(unit: Unit2D = null) -> void:
	if unit != null and unit.team == Unit2D.Team.MINION:
		_minion = unit
	_saw_summon = true
	_refresh_wait()


func notify_spawn_finished() -> void:
	_saw_spawn_done = true
	if _holding_enter and index + 1 < steps.size():
		_holding_enter = false
		_enter(index + 1)
		return
	_refresh_wait()


func notify_selected() -> void:
	_saw_selected = true
	_refresh_wait()


func notify_move() -> void:
	_saw_move = true
	_refresh_wait()


func notify_ram_full() -> void:
	_ram_full = true
	_refresh_wait()


func notify_sacrificed() -> void:
	_saw_sacrifice = true
	_refresh_wait()


func notify_code() -> void:
	_saw_code = true
	_refresh_wait()


func notify_page(page: int) -> void:
	_saw_page = page
	_refresh_wait()


func notify_victory() -> void:
	_on_victory()


func poke() -> void:
	_refresh_wait()


func _enter(next_index: int) -> void:
	index = next_index
	phase = 0
	_holding_enter = false
	if index < 0 or index >= steps.size():
		return
	var step := steps[index]
	_apply(step, false)
	if step.setup_only:
		if index + 1 < steps.size():
			_enter(index + 1)
		return
	if step.stage_end:
		_hide_overlay()
		_present_ending(step)
		return
	_arm(step.wait)
	_show_dialog(step, false)
	_refresh_wait()


func _advance() -> void:
	if index + 1 >= steps.size():
		return
	_play_task_done()
	var nxt := steps[index + 1]
	if nxt.enter_wait != TutorialStep.Wait.NONE and not _met(nxt.enter_wait, nxt):
		_holding_enter = true
		next_enabled = false
		_sync_next_button()
		return
	_enter(index + 1)


func _active_wait(step: TutorialStep) -> TutorialStep.Wait:
	if phase == 1 and step.then_wait != TutorialStep.Wait.NONE:
		return step.then_wait
	return step.wait


func _refresh_wait() -> void:
	if _advance_depth > 8 or steps.is_empty() or index >= steps.size():
		return
	var step := steps[index]
	if step.setup_only or step.stage_end:
		return
	var wait := _active_wait(step)
	var met := _met(wait, step)
	if met and not _waits_for_next(wait):
		next_enabled = false
		_sync_next_button()
		_advance_depth += 1
		_advance()
		_advance_depth -= 1
		return
	next_enabled = met
	_sync_next_button()
	_layout_focus()


func _waits_for_next(wait: TutorialStep.Wait) -> bool:
	return wait == TutorialStep.Wait.NONE or wait == TutorialStep.Wait.CONFIRM


func _met(wait: TutorialStep.Wait, step: TutorialStep) -> bool:
	match wait:
		TutorialStep.Wait.NONE, TutorialStep.Wait.CONFIRM:
			return true
		TutorialStep.Wait.SUMMONED_UNIT:
			return _saw_summon
		TutorialStep.Wait.UNIT_SPAWN_FINISHED:
			return _saw_spawn_done
		TutorialStep.Wait.UNIT_SELECTED:
			return _saw_selected
		TutorialStep.Wait.MOVE_ORDER_ISSUED:
			return _saw_move
		TutorialStep.Wait.UNIT_RAM_FULL:
			return _ram_full or _minion_full()
		TutorialStep.Wait.UNIT_SACRIFICED:
			return _saw_sacrifice
		TutorialStep.Wait.CODE_OPENED:
			return _saw_code
		TutorialStep.Wait.PAGE_OPENED:
			return _page_is(step.wait_page)
		TutorialStep.Wait.SCRIPT_HAS_ACTION:
			return _spell_has_action()
		TutorialStep.Wait.BATTLE_WON:
			return _saw_victory
		_:
			return false


func _arm(wait: TutorialStep.Wait) -> void:
	match wait:
		TutorialStep.Wait.SUMMONED_UNIT:
			_saw_summon = false
		TutorialStep.Wait.UNIT_SELECTED:
			_saw_selected = false
		TutorialStep.Wait.MOVE_ORDER_ISSUED:
			_saw_move = false
		TutorialStep.Wait.UNIT_SACRIFICED:
			_saw_sacrifice = false
		TutorialStep.Wait.CODE_OPENED:
			_saw_code = false
		TutorialStep.Wait.PAGE_OPENED:
			_saw_page = -1
		TutorialStep.Wait.UNIT_RAM_FULL:
			_ram_full = false
		TutorialStep.Wait.BATTLE_WON:
			_saw_victory = false
		_:
			pass


func _apply(step: TutorialStep, then_phase: bool) -> void:
	var defer_world := step.then_wait != TutorialStep.Wait.NONE
	if not then_phase:
		var battle := _battle()
		if battle != null and "tutorial_short_move" in battle:
			battle.tutorial_short_move = step.short_move
		if step.pin_minion:
			_pin_minion()
		_apply_sandbox(step)
		_apply_chrome(step)
		_apply_panel(step)
	if step.apply_summon_cap and then_phase == defer_world:
		var battle := _battle()
		if battle:
			battle.tutorial_summon_cap = step.summon_cap
	if not then_phase:
		_apply_enter_limits(step)
	if then_phase == defer_world:
		_apply_world(step)
	if then_phase:
		_maybe_bailout()


func _apply_sandbox(step: TutorialStep) -> void:
	if Game == null:
		return
	if step.clear_runes and Game.block_inventory:
		Game.block_inventory.clear_counts()
	if step.set_wallet:
		Game.set_wallet(step.wallet_corpse, 0, 0, 0, step.wallet_gore)
	if step.slot_ram >= 0 and not Game.spells.is_empty():
		var spell := Game.spells[0]
		spell.base_ram = step.slot_ram
		spell.race = Unit2D.Race.ZOMBIE
		spell.corpse_amount = 1
		spell.gore_amount = 1
		spell.build_def()
	for rune_id in step.grant_rune_ids:
		if Game.block_inventory:
			Game.block_inventory.grant_id(rune_id, 2)


func _apply_enter_limits(step: TutorialStep) -> void:
	var battle := _battle()
	if battle == null:
		return
	if step.apply_visible_spells:
		battle.tutorial_visible_spells = step.visible_spells
	if step.apply_unlocked_spells and "tutorial_unlocked_spells" in battle:
		battle.tutorial_unlocked_spells = step.unlocked_spells
	if step.apply_order_cap:
		battle.tutorial_order_cap = step.order_cap
		if step.reset_orders and battle.has_method("reset_order_count"):
			battle.reset_order_count()


func _apply_chrome(step: TutorialStep) -> void:
	var battle := _battle()
	if step.hide_sacrifice or step.show_sacrifice:
		_sacrifice_button(step.show_sacrifice and not step.hide_sacrifice)
	if battle != null and "tutorial_lock_field" in battle:
		battle.tutorial_lock_field = step.lock_code_exit
		if battle.has_method("_update_state_buttons"):
			battle.call("_update_state_buttons")
	if battle != null and battle.get("code_button"):
		var code: Node = battle.get("code_button")
		if step.disable_code and code is BaseButton:
			(code as BaseButton).disabled = true
		if step.enable_code and code is BaseButton:
			(code as BaseButton).disabled = false


func _apply_panel(step: TutorialStep) -> void:
	if not step.apply_panel:
		return
	var panel := _script_panel()
	if panel == null:
		return
	panel.show_script_section = step.panel_script
	panel.show_stats_section = step.panel_stats
	panel.show_queue_section = step.panel_queue
	panel.show_ram_section = step.panel_ram
	panel.highlight_section = step.panel_highlight


func _apply_world(step: TutorialStep) -> void:
	var battle := _battle()
	if step.spawn_villager_count > 0 and battle != null and battle.has_method("spawn_practice_villagers"):
		battle.spawn_practice_villagers(step.spawn_villager_count)
	if Game == null:
		return
	if step.top_up_resources:
		if Game.corpse < 6:
			Game.change_resource(Game.ResourceType.CORPSE, 6 - Game.corpse)
		if Game.gore < 6:
			Game.change_resource(Game.ResourceType.GORE, 6 - Game.gore)
	if step.grant_corpse > 0:
		Game.change_resource(Game.ResourceType.CORPSE, step.grant_corpse)
	if step.grant_gore > 0:
		Game.change_resource(Game.ResourceType.GORE, step.grant_gore)
	if step.show_rewards:
		Game.raid_rewards = [
			{"resource_type": Game.ResourceType.CORPSE, "amount": 4},
			{"resource_type": Game.ResourceType.GORE, "amount": 4},
		]


func _maybe_bailout() -> void:
	if _granting or Game == null or Game.tutorial_done or Game.spells.is_empty():
		return
	if _living_minions() > 0 or _can_afford_summon():
		return
	_granting = true
	for entry in Game.spells[0].get_costs():
		var cost := entry as SummonCost
		if cost == null or cost.amount <= 0:
			continue
		var kind: int = cost.resource_type
		if Game.get_resource(kind) > 0:
			continue
		Game.change_resource(kind, cost.amount)
	_granting = false


func _living_minions() -> int:
	var tree := get_tree()
	if tree == null:
		return 0
	var count := 0
	for node in tree.get_nodes_in_group(Unit2D.GROUP):
		var unit := node as Unit2D
		if unit != null and unit.team == Unit2D.Team.MINION and unit.state != Unit2D.State.DEAD:
			count += 1
	return count


func _can_afford_summon() -> bool:
	if Game == null or Game.spells.is_empty():
		return false
	return Game.can_afford(Game.spells[0].get_costs())


func _minion_full() -> bool:
	return _minion != null and is_instance_valid(_minion) and _minion.is_ram_full()


func _spell_has_action() -> bool:
	if Game == null or Game.spells.is_empty():
		return false
	var function := Game.spells[0].get_update_function()
	for line in function.lines:
		if line != null and line.block is ActionBlock:
			return true
	return false


func _page_is(page: int) -> bool:
	if _saw_page == page:
		return true
	var editor := _editor()
	if editor == null or not bool(editor.call("is_open")):
		return false
	return int(editor.get("_page")) == page


func _wire() -> void:
	if _wired:
		return
	_wired = true
	var tree := get_tree()
	if tree:
		tree.node_added.connect(_on_node_added)
	var battle := _battle()
	if battle:
		if battle.has_signal("move_order_issued"):
			battle.connect("move_order_issued", _on_move_order)
		if battle.has_signal("battle_won"):
			battle.connect("battle_won", _on_victory)
		var focus := battle.get_node_or_null("FocusDirector")
		if focus and focus.has_signal("selection_changed"):
			focus.connect("selection_changed", _on_selection)
	var editor := _editor()
	if editor:
		if editor.has_signal("opened"):
			editor.connect("opened", notify_code)
		if editor.has_signal("page_changed"):
			editor.connect("page_changed", notify_page)
	if tree and tree.root:
		var gui := tree.root.get_node_or_null("GUI")
		if gui and gui.has_signal("unit_sacrificed"):
			gui.connect("unit_sacrificed", _on_sacrificed)
	if Game:
		if not Game.resource_changed.is_connected(_on_resources):
			Game.resource_changed.connect(_on_resources)
		if Game.block_inventory and not Game.block_inventory.changed.is_connected(poke):
			Game.block_inventory.changed.connect(poke)


func _on_node_added(node: Node) -> void:
	if not node is Unit2D:
		return
	if node.is_node_ready():
		_bind_unit(node as Unit2D)
	else:
		node.ready.connect(_bind_unit.bind(node), CONNECT_ONE_SHOT)


func _bind_unit(unit: Unit2D) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if not unit.died.is_connected(_on_died):
		unit.died.connect(_on_died)
	if unit.team != Unit2D.Team.MINION:
		return
	_minion = unit
	notify_summoned(unit)
	if unit.state != Unit2D.State.SPAWNING:
		notify_spawn_finished()
	elif not unit.spawned.is_connected(_on_spawned):
		unit.spawned.connect(_on_spawned)


func _on_spawned(_unit: Unit2D) -> void:
	notify_spawn_finished()


func _on_selection(unit: Unit2D) -> void:
	if unit != null and unit.team == Unit2D.Team.MINION:
		notify_selected()


func _on_move_order(_unit: Unit2D) -> void:
	notify_move()


func _on_sacrificed(_unit: Unit2D) -> void:
	notify_sacrificed()


func _on_died(_unit: Unit2D) -> void:
	_maybe_bailout()


func _on_resources() -> void:
	_maybe_bailout()


func _on_victory() -> void:
	_saw_victory = true
	_refresh_wait()


func _ending_step() -> TutorialStep:
	for step in steps:
		if step.stage_end:
			return step
	return null


func _pin_minion() -> void:
	if _minion == null or not is_instance_valid(_minion):
		return
	var battle := _battle()
	if battle == null:
		return
	var focus := battle.get_node_or_null("FocusDirector")
	if focus != null and focus.has_method("pin_unit"):
		focus.pin_unit(_minion)


func _present_ending(step: TutorialStep) -> void:
	var battle := _battle()
	if battle == null or not battle.has_method("present_tutorial_ending"):
		return
	var text := LocaleText.resolve(step.text_key, step.text_key)
	battle.present_tutorial_ending(text)


func _battle() -> Node:
	var parent := get_parent()
	if parent != null and parent.has_method("allows_summon"):
		return parent
	return null


func _editor() -> Node:
	var battle := _battle()
	if battle == null:
		return null
	return battle.get_node_or_null("CodeLayer/Editor")


func _script_panel() -> ScriptDebugPanel:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("GUI/ScriptPreview") as ScriptDebugPanel


func _sacrifice_button(show: bool) -> void:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	var button := tree.root.get_node_or_null("GUI/SacrificeButton") as CanvasItem
	if button:
		button.visible = show


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "TutorialUI"
	_layer.layer = 110
	add_child(_layer)
	for _i in 4:
		var shade := ColorRect.new()
		shade.color = Color(0, 0, 0, 0.62)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shade.visible = false
		_layer.add_child(shade)
		_dim.append(shade)
	_arrow = Label.new()
	_arrow.text = "▼"
	_arrow.add_theme_font_size_override(&"font_size", 42)
	_arrow.add_theme_color_override(&"font_color", Color(1, 0.86, 0.35))
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_arrow)
	_dialog = PanelContainer.new()
	_dialog.name = "TutorialDialog"
	_dialog.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_dialog.offset_left = -400.0
	_dialog.offset_top = -520.0
	_dialog.offset_right = 400.0
	_dialog.offset_bottom = -140.0
	_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(_dialog)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	_dialog.add_child(box)
	_counter = Label.new()
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_counter)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.custom_minimum_size = Vector2(760, 0)
	_body.add_theme_font_size_override(&"normal_font_size", 26)
	box.add_child(_body)
	_objective = Label.new()
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective.visible = false
	box.add_child(_objective)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(row)
	_next = Button.new()
	_next.text = LocaleText.resolve("ui.tutorial.next", "Next")
	_next.custom_minimum_size = Vector2(160, 56)
	_next.pressed.connect(press_next)
	row.add_child(_next)
	_dialog.visible = false


func _show_dialog(step: TutorialStep, collapsed: bool) -> void:
	if _dialog == null:
		return
	_dialog.visible = true
	var collapse := collapsed and step.collapse_after_confirm
	_body.visible = not collapse
	_counter.visible = not collapse
	_objective.visible = collapse
	_counter.text = LocaleText.resolve("ui.tutorial.counter", "{current}/{total}").format({
		"current": index + 1,
		"total": steps.size(),
	})
	_body.text = LocaleText.resolve(step.text_key, step.text_key)
	_objective.text = LocaleText.resolve("ui.tutorial.objective", "Wipe out every villager.")
	if collapse:
		_dialog.offset_top = -230.0
	else:
		_dialog.offset_top = -520.0


func _hide_overlay() -> void:
	if _dialog:
		_dialog.visible = false
	for shade in _dim:
		shade.visible = false
	if _arrow:
		_arrow.visible = false


func _sync_next_button() -> void:
	if _next == null:
		return
	var dismiss := false
	var show_next := true
	if not steps.is_empty() and index >= 0 and index < steps.size():
		var step := steps[index]
		dismiss = phase == 1 and step.collapse_after_confirm
		show_next = dismiss or _waits_for_next(_active_wait(step))
	_next.visible = show_next
	_next.disabled = false if dismiss else not next_enabled
	_next.modulate = Color.WHITE if next_enabled else Game.DISABLED_COLOR
	if _pulse and _pulse.is_valid():
		_pulse.kill()
	_next.scale = Vector2.ONE
	if not next_enabled or not _next.visible:
		return
	_next.pivot_offset = _next.size * 0.5
	_pulse = create_tween()
	_pulse.set_loops()
	_pulse.tween_property(_next, "scale", Vector2(1.08, 1.08), 0.35)
	_pulse.tween_property(_next, "scale", Vector2.ONE, 0.35)


func _layout_focus() -> void:
	if _dialog == null or not _dialog.visible or steps.is_empty():
		return
	var step := steps[index]
	var focus := _current_focus(step)
	var hole := _focus_rect(focus)
	if step.short_move:
		var marker := _short_move_rect()
		if marker.size.x > 4.0:
			hole = marker
	var holes: Array[Rect2] = []
	if focus != "none" and hole.size.x > 4.0:
		holes.append(hole)
	if step.focus_after_page == "rune_palette" and _page_is(step.wait_page):
		var script_page := _focus_rect("script_view")
		if script_page.size.x > 4.0:
			holes.append(script_page)
	if step.highlight_unit:
		var unit_hole := _focus_rect("unit")
		if unit_hole.size.x > 4.0:
			holes.append(unit_hole)
	if _active_wait(step) == TutorialStep.Wait.SUMMONED_UNIT:
		var field := _focus_rect("field")
		if field.size.x > 4.0:
			holes.append(field)
	var view := get_viewport().get_visible_rect()
	var on_screen: Array[Rect2] = []
	for one in holes:
		var clipped := view.intersection(one)
		if clipped.size.x > 4.0 and clipped.size.y > 4.0:
			on_screen.append(one)
	holes = on_screen
	var show := not holes.is_empty()
	var locked := step.locked and phase == 0
	var shades: Array[Rect2] = []
	if show:
		shades = _subtract_holes(view, holes)
	_ensure_shades(shades.size())
	for index_shade in _dim.size():
		var shade := _dim[index_shade]
		var used := index_shade < shades.size()
		shade.visible = used
		if not used:
			continue
		shade.position = shades[index_shade].position
		shade.size = shades[index_shade].size
		shade.mouse_filter = Control.MOUSE_FILTER_STOP if locked else Control.MOUSE_FILTER_IGNORE
	if _arrow:
		_arrow.visible = show
	if not show:
		return
	_arrow.position = Vector2(hole.position.x + hole.size.x * 0.5 - 16.0, hole.position.y - 48.0 + sin(Time.get_ticks_msec() * 0.008) * 8.0)


func _subtract_holes(view: Rect2, holes: Array[Rect2]) -> Array[Rect2]:
	var open: Array[Rect2] = [view]
	for hole in holes:
		var next: Array[Rect2] = []
		for rect in open:
			next.append_array(_subtract_one(rect, hole))
		open = next
	return open


func _subtract_one(rect: Rect2, hole: Rect2) -> Array[Rect2]:
	var overlap := rect.intersection(hole)
	if overlap.size.x <= 0.0 or overlap.size.y <= 0.0:
		return [rect]
	var parts: Array[Rect2] = []
	if overlap.position.y > rect.position.y:
		parts.append(Rect2(rect.position, Vector2(rect.size.x, overlap.position.y - rect.position.y)))
	if overlap.end.y < rect.end.y:
		parts.append(Rect2(Vector2(rect.position.x, overlap.end.y), Vector2(rect.size.x, rect.end.y - overlap.end.y)))
	if overlap.position.x > rect.position.x:
		parts.append(Rect2(Vector2(rect.position.x, overlap.position.y), Vector2(overlap.position.x - rect.position.x, overlap.size.y)))
	if overlap.end.x < rect.end.x:
		parts.append(Rect2(Vector2(overlap.end.x, overlap.position.y), Vector2(rect.end.x - overlap.end.x, overlap.size.y)))
	return parts


func _ensure_shades(count: int) -> void:
	while _dim.size() < count:
		var shade := ColorRect.new()
		shade.color = Color(0, 0, 0, 0.62)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_layer.add_child(shade)
		_layer.move_child(shade, 0)
		_dim.append(shade)


func _current_focus(step: TutorialStep) -> String:
	if step.focus_after_page != "" and _page_is(step.wait_page):
		return step.focus_after_page
	return step.focus_id


func _short_move_rect() -> Rect2:
	var battle := _battle()
	if battle == null or not battle.has_method("tutorial_move_marker"):
		return Rect2()
	var world: Vector2 = battle.call("tutorial_move_marker")
	if is_inf(world.x) or is_inf(world.y):
		return Rect2()
	var screen := _world_to_screen(world)
	return Rect2(screen - Vector2(56, 70), Vector2(112, 112))


func _world_to_screen(world: Vector2) -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return world
	return viewport.get_canvas_transform() * world


func _focus_rect(focus: String) -> Rect2:
	if focus == "unit_bars" and _minion != null and is_instance_valid(_minion):
		return _unit_bars_rect(_minion)
	if focus.begins_with("script_panel_"):
		var panel := _script_panel()
		if panel != null and panel.has_method("section_screen_rect"):
			return panel.section_screen_rect(focus.trim_prefix("script_panel_"))
	var node := _focus_node(focus)
	if node is Control:
		return _control_screen_rect(node as Control)
	if node is Node2D:
		var origin := (node as Node2D).get_global_transform_with_canvas().origin
		return Rect2(origin - Vector2(90, 110), Vector2(180, 220))
	if focus == "field":
		return get_viewport().get_visible_rect().grow(-64.0)
	return Rect2()


func _control_screen_rect(control: Control) -> Rect2:
	if control == null or not is_instance_valid(control) or not control.is_visible_in_tree():
		return Rect2()
	if control.size.x < 4.0 or control.size.y < 4.0:
		return Rect2()
	var xform := control.get_global_transform_with_canvas()
	var top_left: Vector2 = xform * Vector2.ZERO
	var bottom_right: Vector2 = xform * control.size
	return Rect2(top_left, bottom_right - top_left).abs().grow(12.0)


func _unit_bars_rect(unit: Node2D) -> Rect2:
	var origin := unit.get_global_transform_with_canvas().origin
	var rect := Rect2(origin - Vector2(80, 70), Vector2(160, 180))
	for bar_name in ["HealthBarComponent", "ThinkBarComponent", "AnimationBarComponent"]:
		var component := unit.get_node_or_null("ComponentContainer/" + bar_name)
		var piece := _bar_screen_rect(component)
		if piece.size.x > 1.0:
			rect = rect.merge(piece)
	return rect.grow(18.0)


func _bar_screen_rect(component: Node) -> Rect2:
	if component == null:
		return Rect2()
	var root: Node2D = null
	for child in component.get_children():
		if child is Node2D:
			root = child
			break
	if root == null or not root.visible:
		return Rect2()
	var raw: Variant = component.get("size")
	var bar_size := Vector2(128, 6)
	if raw is Vector2:
		bar_size = raw
	var origin := root.get_global_transform_with_canvas().origin
	return Rect2(origin - bar_size * 0.5, bar_size).grow(6.0)


func _focus_node(focus: String) -> Node:
	var tree := get_tree()
	var root := tree.root if tree else null
	match focus:
		"spell_bar":
			return root.get_node_or_null("GUI/SummonHotbar") if root else null
		"resource_bar":
			return root.get_node_or_null("GUI/PanelContainer") if root else null
		"sacrifice_button":
			return root.get_node_or_null("GUI/SacrificeButton") if root else null
		"city_progress":
			return root.get_node_or_null("GUI/CityProgress") if root else null
		"script_panel_stats", "script_panel_queue", "script_panel_ram":
			return root.get_node_or_null("GUI/ScriptPreview") if root else null
		"code_button":
			var battle := _battle()
			return battle.get_node_or_null("CanvasLayer/StateContainer/CodeButton") if battle else null
		"page_buttons":
			return _editor_unique("PageButtons")
		"summoning_page_button":
			return _editor_unique("SpecPageButton")
		"thinking_page_button":
			return _editor_unique("ScriptPageButton")
		"rune_palette":
			return _editor_unique("BlockPalette")
		"script_view":
			return _editor_unique("ScriptView")
		"unit", "unit_bars":
			return _minion if _minion != null and is_instance_valid(_minion) else null
		_:
			return null


func _editor_unique(node_name: String) -> Node:
	var editor := _editor()
	if editor == null:
		return null
	return editor.get_node_or_null("%" + node_name)
