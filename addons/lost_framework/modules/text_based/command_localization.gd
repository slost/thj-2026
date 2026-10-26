class_name CommandLocalization
extends TextLocalization
## A [CommandDef] in one language: its verb, the words players type for it,
## its help and its messages (see [member TextLocalization.messages]). Put
## it in [member CommandDef.localizations]. A translation file can do the
## same with the keys "command.<id>.name", "command.<id>.aliases"
## (comma-separated), "command.<id>.help", "command.<id>.help_examples"
## (one per line) and "command.<id>.message.<key>"; the translation file wins.


## The verb in this language, used in questions and messages
## ("จะหยิบอะไร?"). Empty uses [member DataDef.name].
@export var name := ""
## Words players type for the command in this language, e.g. "หยิบ",
## "เก็บ". Every language's words are always understood; help lists only
## those of the output language.
@export var aliases: PackedStringArray = []
@export_multiline var help_text := "" ## Replaces [member CommandDef.help_text]. The first line is the summary.
@export var help_examples: Array[String] = [] ## Replaces [member CommandDef.help_examples] when not empty.
