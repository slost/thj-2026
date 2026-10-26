class_name CommandSession
extends RefCounted
## Turns lines of player input into [CommandMatch]es, remembering a question
## between lines. A line can hold several commands ("take sword then open
## box"); when one of them needs an answer (ASK), the rest of the line waits
## in a queue. The next line is the answer if it has no verb (a noun phrase,
## an adjective, a number like "2" or "อันที่ ๑", or a direction for "Which
## way?"); the answered command and the queued ones then continue. A line
## with a verb drops the question and the queue and starts over.
## A FAILED command also drops the rest of its line.
## With [member run_ready], each READY command is run as soon as it is
## matched, so the next command of the line sees its effects ("open box
## then take key").

## The pending question was asked again ([member CommandMatch.question] of
## [param m]) because the output language changed. Show it to the player.
signal question_changed(m: CommandMatch)

var parser: CommandParser
var matcher: CommandMatcher
var pending: CommandMatch ## The ASK match waiting for an answer, or null.
## When true, each READY match is run with [method FictionWorld.run] right
## after it is matched (before the next command of the line is matched);
## what happened is in [member CommandMatch.events].
var run_ready := false
## Language this session's texts use. Empty follows the world's output language,
## so each player of a shared world can have their own.
var locale := ""
var _queue: Array[ParsedCommand] = [] ## Commands of the line waiting behind [member pending].


func _init(p_world: FictionWorld, p_actor: Entity = null, p_parser: CommandParser = null) -> void:
	parser = p_parser if p_parser else CommandParser.new(p_world.get_vocabulary())
	matcher = CommandMatcher.new(p_world, p_actor)
	if p_world:
		p_world.output_locale_changed.connect(_on_output_locale_changed)


func is_waiting() -> bool:
	return pending != null


## Commands still queued behind the pending question.
func get_queue() -> Array[ParsedCommand]:
	return _queue.duplicate()


## Drops the pending question and the queued commands.
func reset() -> void:
	pending = null
	_queue.clear()


## Processes one line. Returns a match per command handled, in order; the
## last one is ASK if the session now waits for an answer.
func submit(line: String) -> Array[CommandMatch]:
	var results: Array[CommandMatch] = []
	matcher.locale = LocaleText.language_of(locale) if not locale.is_empty() else ""
	if matcher.world:
		matcher.world.get_vocabulary() # Rebuilds it now if words changed this frame (e.g. the language)
	var parts := parser.parse_all(line)
	if parts.is_empty():
		return results

	if pending and _is_answer(parts[0]):
		var answered := matcher.answer(pending, parts.pop_front())
		pending = null
		_queue.append_array(parts) # The rest of this line runs after the old queue
		results.append(answered)
		if not _settle(answered):
			return results
	else:
		reset()
		_queue = parts
	_run_queue(results)
	return results


func _run_queue(results: Array[CommandMatch]) -> void:
	while not _queue.is_empty():
		var m := matcher.match_command(_queue.pop_front())
		results.append(m)
		if not _settle(m):
			return


## Updates the pending state after [param m]. Returns true to keep going.
func _settle(m: CommandMatch) -> bool:
	match m.status:
		CommandMatch.Status.ASK:
			pending = m
			return false
		CommandMatch.Status.FAILED:
			_queue.clear()
			return false
	if run_ready and matcher.world:
		m.events = matcher.world.run(m, matcher.actor)
	if m.is_ready():
		matcher.remember(m)
	return true


## Asks the pending question again in the new output language.
func _on_output_locale_changed(new_locale: String) -> void:
	if pending == null or not locale.is_empty():
		return # A session language does not follow the global one
	pending.locale = new_locale
	pending.question = matcher.render_question(pending)
	question_changed.emit(pending)


## A reply answers the question unless it has a verb. A bare direction is a
## new "go" command, except when the question is "Which way?".
func _is_answer(reply: ParsedCommand) -> bool:
	if reply.verb:
		return false
	if reply.direction and pending.ask != CommandMatch.Ask.DIRECTION:
		return false
	return true
