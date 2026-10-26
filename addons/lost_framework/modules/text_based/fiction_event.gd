class_name FictionEvent
extends RefCounted
## Something that happened when a command ran, with the text to show.
## [method FictionWorld.run] returns these; the game decides how to show them.
## [member text] is the actor's sentence in [member locale]. [method render]
## builds the sentence again for another observer or language from [member key]
## and [member values].


## Who should see the event (for a future multi-player world).
enum Visibility {
	ACTOR, ## Only the one who acted ("Taken.").
	ROOM, ## Everyone in [member location_id] ("Ada takes the key.").
	WORLD, ## Everyone ("A bell rings in the distance.").
}

var text := "" ## The actor's sentence in [member locale].
var actor: Entity ## Who acted.
var visibility := Visibility.ACTOR
## When false, the actor does not hear this event (a leave line for the room
## they left). The sentence is still in [member text] for other observers.
var include_actor := true
## Room whose occupants hear a [constant Visibility.ROOM] event. Empty uses
## the actor's location at render time.
var location_id := &""
var command_id := &"" ## The command that made it, e.g. &"take".
var key := &"" ## The message key the text came from, e.g. &"taken" (see [CommandMessage]).
## Message key for someone who is not the actor, e.g. &"taken_seen". Empty
## reuses [member key].
var seen_key := &""
var success := true ## False when the command did not do what was asked ("You can't take that.").
var object: Entity ## The object the event is about, if any (set by [method CommandDef._event]).
var target: Entity
var locale := "" ## Language [member text] was rendered in.
var values: Dictionary = {} ## Placeholders used to render [member text].
var direction_id := &"" ## Direction id, so another language can name it again.
var texts: FictionTexts
## Source sentence for a reaction or agenda line (before placeholders). Empty
## for command messages, which [method render] loads by [member key].
var template := ""
## True when several objects each got a line ("box: Taken."). [method render]
## puts the object's name in front again.
var group_name := false


func _init(p_text := "", p_actor: Entity = null, p_success := true, p_key := &"", p_command_id := &"") -> void:
	text = p_text
	actor = p_actor
	success = p_success
	key = p_key
	command_id = p_command_id


## True if [param observer] should be shown this event. Null means the actor.
func hears(observer: Entity, world: FictionWorld = null) -> bool:
	if visibility == Visibility.ACTOR:
		return observer == null or observer == actor
	if not include_actor and (observer == null or observer == actor):
		return false
	if visibility == Visibility.WORLD:
		return true
	if observer == null or observer == actor:
		return include_actor
	var room_id := location_id
	if room_id == &"" and actor and actor.get_location():
		room_id = actor.get_location().get_id()
	var here := observer.get_location()
	return here != null and here.get_id() == room_id


## The sentence for [param observer] in [param locale_override] (empty: [member locale]).
## The actor in the original language gets [member text].
func render(world: FictionWorld, observer: Entity = null, locale_override := "") -> String:
	var use_locale := locale if locale_override.is_empty() else LocaleText.language_of(locale_override)
	var for_actor := observer == null or observer == actor
	if for_actor and (locale_override.is_empty() or LocaleText.same_language(use_locale, locale)):
		return text
	var line := ""
	if template.is_empty():
		var command := world.get_command(command_id) if world and command_id != &"" else null
		if command == null:
			line = text
		else:
			var message_key := seen_key if not for_actor and seen_key != &"" else key
			line = command.get_message(message_key, "", command.rebuild_values(self, use_locale), use_locale)
	else:
		var source := LocaleText.translate(template, use_locale)
		if source.is_empty():
			source = template
		line = source.format(values) if not source.is_empty() else ""
	if group_name and object:
		line = "%s: %s" % [object.get_display_name(use_locale), line]
	return line


func _to_string() -> String:
	return text
