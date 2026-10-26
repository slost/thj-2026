# AGENTS.md: Lost IF (modules/text_based)

Parser interactive fiction on top of Lost Entities/Components. Read the root `AGENTS.md` first: plan first, no commits, English code, tests with every change.
Demo and tests: `addon_workspace/tests/interactive_fiction_demo/`.

## Direction (design for this)
- **MUD later.** Keep world logic free of UI and engine singletons. Pass the world, actor and match explicitly; refer to entities by id; keep state plain (saveable, sendable). Rooms may later cache their passages at load: only `FictionWorld.get_exits()` would change.
- **An editor dock for non-programmer designers** comes later. Data lives in Inspector-editable Resources and nodes; avoid rules that only work in code.
- **Save/load** goes through components owning their state plus `Entity.state`. Wiring them to `SaveParticipantComponent` is planned future work; keep that state plain.
- **Base verbs are built in; teams add their own** as data (a `CommandDef` `.tres`, optionally a subclass script) without changing the module.

## Naming
- No `IF` prefix anywhere. IF-only types use `Fiction…` (`FictionWorld`, `FictionEvent`, `FictionReaction`…) or `Command…`.
- Generic components live in `modules/entities/components/` with no prefix: `LocationComponent`, `MoverComponent`, `PortableComponent`, `ContainerComponent`, `OpenableComponent`, `LockableComponent`, `PassageComponent`. Don't put IF rules in them.

## Pipeline
```
line ─ CommandParser (Vocabulary, Thai segmentation) ─> ParsedCommand(s)
     ─ CommandMatcher (EntityResolver, scope) ─> CommandMatch READY | ASK | FAILED
     ─ FictionWorld.run(m, actor) ─> reactions BEFORE ─ CommandDef.execute ─ reactions AFTER ─> Array[FictionEvent]
CommandSession: queue of commands per line, pending question (ASK) and its answer, run_ready.
```
- **Vocabulary** (`parser/`) maps words to typed tokens (VERB id = command id, NOUN = entity id, ADJECTIVE, DIRECTION, PREPOSITION, CONJUNCTION, FILLER, NUMBER).
  - `FictionWorld.get_vocabulary()` = `base_vocabulary` (directions, prepositions, fillers; the game supplies these) + every command's words + every entity's names, aliases and adjectives in **all** languages.
  - It is rebuilt lazily; call `invalidate_vocabulary()` after changing words.
- **Thai has no spaces.** `CommandParser` segments by vocabulary (fewest unknown characters, then fewest tokens). Compound verbs are plain aliases (`มองไป`, `ดูไป`).
  - Directions get `ทาง…` forms in the demo (`ไปทางเหนือ`). `ทาง` alone is *not* a filler (it would split `ทางเดิน`).
  - Thai digits and `อันที่ 2` answer "which?" questions.
- **CommandMatch**:
  - `status` READY/ASK/FAILED.
  - `ask` is OBJECT/TARGET/DIRECTION/WHICH_OBJECT/WHICH_TARGET.
  - `failure` is UNKNOWN_WORDS, NO_VERB, UNKNOWN_VERB, NOT_HERE, NOT_FOUND, SELF, NO_*_EXPECTED, WRONG_PREPOSITION.
  - It also carries `locale` and `texts`, which the matcher stamps.
- **EntityResolver** narrows a noun phrase within `FictionWorld.get_scope(actor)`: FOUND / AMBIGUOUS (ask which) / NOT_HERE / NOT_FOUND.

## FictionWorld
- Registers every Entity below it by id (`get_entity`, `get_entities`). `player` is the default actor.
- `commands: Array[CommandDef]` (`CommandDef.load_base_commands()` gives the base set). `get_command(id)`.
- `state` + `get_world_value`/`set_world_value`: world flags (ValueCondition subject WORLD). `make_condition_context_for(entity, actor)`.
- **Exits are computed live from passages**: `get_exits(room_id)`, `get_exit(room_id, dir)`, sorted by `direction_order` (default n, ne, e, se, s, sw, w, nw, up, down, in, out; unknown directions last). `validate_passages()` warns at ready.
- **Scope**: location, its contents, open containers' contents, what the actor carries, the actor, and the named passages (doors) of the location's exits.
- `run()` handles reactions, `action_count` and `action_performed`. An `is_meta` command (help) skips reactions and counting.
- Language: `get_output_locale()`, `get_texts()`, `signal output_locale_changed` (see Language).

## Passages and doors
- A connection is **one entity with `PassageComponent`**, kept under a plain `World/Connectors` node (it belongs to neither room).
  - `a_id`/`a_direction` lead from a to b; `b_id`/`b_direction` lead back. Directions are free (not forced opposites). An **empty `b_direction` = one-way**.
- **Door** = a passage + `OpenableComponent` (+ `LockableComponent` with `key_id`). Unnamed passages (no def/name) are plain openings: not in scope, no words.
- `go` refuses closed or locked doors (message keys `door_closed`/`door_locked`), moves the actor, sets `LocationComponent.visited`, then runs `look`.

## Commands
- `CommandDef` (Resource, `DataDef` domain `command`): `id` = verb id; `aliases` = **source-language (English) words only**. Its fields:
  - object/target `Requirement` (NONE/OPTIONAL/REQUIRED) and `Scope` (VISIBLE/NOT_CARRIED/CARRIED)
  - `prepositions`, `needs_direction`/`accepts_direction`, `with_object_command` (look box → examine)
  - questions, help fields, `is_meta`, `accepts_command`, `localizations`
- **Evennia-style**: a subclass overrides `execute(m, actor, world) -> Array[FictionEvent]` (or `_execute_object` with `_execute_each_object`).
  - Commands are shared Resources: keep **no per-run state** on them.
- **Messages**: every text has a key.
  - `_default_messages()` lists the keys with English defaults (subclasses `merge` into `super()`).
  - `messages: Array[CommandMessage]` in the `.tres` overrides them and must stay equal to the script defaults (action_test checks this).
  - Use `_event(key, m, actor, success, object, extra)`. Placeholders: `{actor} {object} {target} {direction} {verb}` + extras.
- `FictionEvent`: text, actor, success, key, command_id, object. A failed action has `success = false` (AFTER reactions don't fire).
- Base commands (`commands/*.tres` + `commands/scripts/*_command_def.gd`): take, drop, open, close, put, look, examine, go, inventory, unlock, lock, help. The demo adds `read.tres` (a plain CommandDef; reactions give it meaning).

## Reactions and descriptions
- `FictionReactionComponent.reactions: Array[FictionReaction]`. A reaction has:
  - `command_ids` (empty = all), `role` OBJECT/TARGET/ANY (ANY includes the actor's location)
  - `when`/`conditions` (ValueCondition), `timing` BEFORE/AFTER
  - `stop` (BEFORE only), `once` (remembered in the host's `state`, so it is saved), `key`
  - `text` (passed through `tr()`), `effects` (`FictionEffect`: `SetStateEffect`, `MoveEntityEffect`; refer to entities by id)
- AFTER reactions fire only on success, per object for multi-object commands.
- Descriptions: `DataDef.description` + `DescriptionVariant` (REPLACE: first match wins; APPEND: all matches add), conditions via `when` or `ValueCondition`s.

## look <direction>
- `look north`:
  - nothing that way → `nothing_that_way` (fails)
  - a closed door → `view_blocked` (fails; AFTER reactions don't fire)
  - otherwise → the room's `LocationComponent.distant_description` (`{room}`, `{direction}`) or `view_room`, then its contents unless `hide_contents_from_afar`, then "beyond" (`LookCommandDef.beyond`: SAME_DIRECTION / ALL_EXITS / NONE) unless `blocks_view`.
- The exits line shows door state: `north (a locked door)`.

## Help
- `HelpCommandDef` (`help.tres`) lists commands by `help_category` (`category_order`; others after; empty = "Other"). `help <command>` shows details.
- CommandDef fields:
  - `help_text` (first line = summary), `help_examples`, `help_category`
  - `show_in_help`, `is_meta`, `accepts_command` (the next word is a command id: `CommandMatch.argument_command`/`argument_text`)
- Names line = **id first**, then the command's words in the output language only:
  - English: `take (get)`
  - Thai: `take (หยิบ, เก็บ)`
- `hint_on_unknown` adds "Type help…" to unknown-word and unknown-verb failures (`CommandMatcher.help_command`).

## Language (decided; don't reintroduce per-world language settings)
- **Output follows Settings**: `TranslationServer` locale → `LocaleText.get_locale()` (`th_TH` → `th`).
  - The matcher stamps `m.locale`; all messages, questions and failures resolve through `TextLocalization.resolve_message`.
  - `FictionWorld` handles `NOTIFICATION_TRANSLATION_CHANGED`: on a real language change it emits `output_locale_changed` and rebuilds the vocabulary. `CommandSession` re-asks a pending question and emits `question_changed(m)`.
- **Input accepts every language, always.** Source-language words go in `CommandDef.aliases`; other languages go in `CommandLocalization` (`locale`, `name` = verb, `aliases`, `help_text`, `help_examples`, `messages`).
- **Lookup order** for any text: translation file key → `localizations` entry → source text (also tried as a translation key) → English with **one `push_warning`** per key and language. Texts with no letters outside `{placeholders}` (e.g. `{room}`) never warn.
- **Translation keys**:
  - `command.<id>.name|aliases|help|help_examples|message.<key>|question.<object|target|direction>`
  - `fiction.message.<key>`
  - `entity.<id>.name|desc|desc.<variant>`
  - Aliases in files are comma-separated and add to the Inspector ones.
- **FictionTexts** (`fiction_texts.tres`, `FictionWorld.texts`, default when empty) holds parser failures, which/object/target/direction questions, `object_name` ("the {name}"; Thai has no article), `object_it`, `object_and`, `direction_<id>`, `preposition_<id>`.
- **Entity names and descriptions come only from CSV translations** (`entity.<id>.name/.desc`). There are no per-language fields on DataDef.
  - Names in every loaded language are vocabulary words.
  - The demo loads `if_demo_text.csv` (keys,en,th) at runtime; `/lang en|th` in the demo calls `Settings.set_language`.

## Tests (all must pass; add or extend tests with every change)
Suites live in `tests/interactive_fiction_demo/<suite>_test.gd` and run headless with `-s` (commands in the root AGENTS.md):

| suite | covers |
|---|---|
| parser | vocabulary, normalizer, tokenizer (Thai segmentation), ParsedCommand, noun phrases |
| entity | Entity/DataDef values, descriptions, variants |
| scope | scope, passages/exits, `validate_passages`, direction order |
| command | matcher: READY/ASK/FAILED, questions, which?, base commands |
| action | `execute` of every base verb, messages vs script defaults, multi-command lines |
| reaction | reactions, effects, once/stop, roles |
| condition | ValueCondition, contexts, variants with conditions |
| look | look, exits line, look <direction>, beyond rules |
| help | help list/details, per-language names, hints, meta |
| language | output locale switching, re-asked questions, fallback + warnings, translation precedence |
| thai_coverage | every base command and FictionTexts key has Thai (with matching placeholders) |

- **Pin the locale** in every suite (Settings sets `th`): `var old_locale := TranslationServer.get_locale(); TranslationServer.set_locale("en")` at the start, restore it before `quit()`. Restore anything else global you change (translations, `LocaleText.clear_warnings()`).
- Suites that need `_ready` build their world in `_process` on the first frame (see `entity_test.gd`).
- Style: `_check_eq(label, actual, expected)`, then print `N/M passed` and `quit(1 if failures else 0)`.

## Recipes
- **New command**:
  1. Add `commands/<id>.tres` (or a game's own folder) with `id`, `name`, English `aliases`, requirements and scopes, help fields, and a `CommandLocalization` for `th` (name, aliases, help, messages).
  2. If it needs rules: add `commands/scripts/<id>_command_def.gd` (`extends CommandDef`, `class_name <Id>CommandDef`), override `execute`, list keys in `_default_messages()`, and mirror them in the `.tres` `messages`.
  3. For a base command, add the path to `CommandDef.BASE_COMMAND_PATHS`; otherwise append it to `FictionWorld.commands`.
  4. Tests: action (+ command/help counts), thai_coverage.
- **New component**:
  - Generic → `modules/entities/components/`, `extends Component`, typed `@export`s, report values via `_state_values()`/`_set_state_value()`, no IF imports.
  - IF-only → this module, `Fiction` prefix.
  - Add tests (entity/scope/action).
- **New message**: add the key and English text to `_default_messages()`, the same `CommandMessage` to the `.tres` `messages`, the Thai text to its `Localization_th`, and use it via `_event`/`get_message(key, "", values, locale)`. thai_coverage will fail if Thai is missing.
- **New parser text / question / direction**: add it to `FictionTexts._default_messages()` and the Thai entry in `fiction_texts.tres`.
- **Translate game content**: CSV `keys,en,th` with `entity.<id>.name/.desc`, `command.<id>.…` and `fiction.message.…` keys; register it in the game's project settings (localization). Never hard-code Thai in scripts.
- **Edit .tres by hand** only in Godot's text format, keeping `ext_resource`/`sub_resource` ids consistent. Prefer the Inspector when the resource is open in the editor.
