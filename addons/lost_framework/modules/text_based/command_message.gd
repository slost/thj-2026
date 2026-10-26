class_name CommandMessage
extends Resource
## One text a [CommandDef] can show, e.g. key &"taken" with text "Taken.".
## Put it in [member CommandDef.messages] to replace the default text of that key.


@export var key := &"" ## The message key, e.g. &"not_portable".
## Placeholders: {actor}, {object}, {target}, {direction}, {verb}, and the
## extra ones the command lists (e.g. {door}, {list}).
@export_multiline var text := ""
