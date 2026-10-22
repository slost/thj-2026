## Base class for all logic rules used by components.
## Rules are pure logic containers and should not depend on scene state.
extends Resource
class_name Rule


## Called by a component to apply this rule.
## Subclasses should override this with a clear, deterministic contract.
func apply(context):
	## Default implementation does nothing.
	## 'context' can be a structured object or primitive arguments,
	## depending on the specific rule type.
	return context


func validate() -> bool:
	## Optional validation hook.
	## Can be used by editors or runtime systems
	## to ensure this rule is configured correctly.
	return true


func describe() -> String:
	## Returns a human-readable description of this rule.
	## Useful for debugging tools, editors, or logs.
	return ""
