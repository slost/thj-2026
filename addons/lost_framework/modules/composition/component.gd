## Abstract base class for all scene-based components.
## Do not instantiate this directly.
@icon("res://addons/lost_framework/resources/assets/icons/component.svg")
extends Node
class_name Component


@export var enabled: bool = true ## Whether this component is currently active.
@export var explicit_host: Node  ## Overide host by the selecting host

var host_node: Node ## Cached reference to the owning node (optional, but common).


#region Public API
## Returns the node that owns this component.
func get_host() -> Node:
	return host_node


## Returns whether this component should currently operate.
## Systems should respect this flag.
func is_enabled() -> bool:
	return enabled


## Enables or disables this component.
## Override in subclasses if extra behavior is required.
func set_enabled(value: bool) -> void:
	enabled = value

## Sets the node that owns this component.
func set_host(node: Node) -> void:
	if not node:
		host_node = null
		return
		
	# Disallow component as host
	if node is Component:
		return

	# Disallow container as host
	if node is ComponentContainer:
		return

	host_node = node

#endregion


#region Godot Callbacks
## Called when the component enters the scene tree.
## Use this to cache references or register to systems.
func _enter_tree() -> void:
	_resolve_host()


func _ready() -> void:
	_setup()


func _resolve_host() -> void:
	if explicit_host:
		set_host(explicit_host)

	if not host_node:
		if explicit_host:
			push_error("Explicit host is invalid. Falling back to auto-scan.")
		_scan_host()


func _scan_host() -> void:
	var current: Node = get_parent()

	while current:
		set_host(current)

		# If host_node was accepted, stop
		if host_node:
			return

		current = current.get_parent()


## Called when the component leaves the scene tree.
## Use this to unregister from systems or clean up references.
func _exit_tree() -> void:
	set_host(null)
	_teardown()

#endregion


#region Helper
func get_host_component(script: Script) -> Component:
	return Utils.get_component(get_host(), script)

#endregion


#region Overridable Hooks
## Initial setup
func _setup() -> void:
	pass

## Called when exit tree 
func _teardown() -> void:
	pass

#endregion