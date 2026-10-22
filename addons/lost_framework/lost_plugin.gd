@tool
extends EditorPlugin


const DOCK_PATH := "res://addons/lost_framework/core/editor/lost_dock.gd"
const CORE_READY_RETRY_MAX := 120
const _ASSET_MANAGER_SCRIPT := preload("res://addons/lost_framework/modules/asset_manager/asset_manager.module.gd")

var dock: Control
var registrar: AutoloadRegistrar

# Performance Tracking
var _load_start_usec: int = 0


#region Editor Lifecycle
func _enter_tree() -> void:
	_load_start_usec = Time.get_ticks_usec()
	_register_framework_project_settings()
	_initialize_registrar()
	_register_autoloads()
	_setup_dock()
	call_deferred("_load_assigned_modules_when_core_ready")


func _exit_tree() -> void:
	# _teardown_autoloads()
	_teardown_dock()
#endregion

#region Core Initialization
func _load_assigned_modules_when_core_ready() -> void:
	for _attempt in CORE_READY_RETRY_MAX:
		var core := _get_core()
		if core and core.has_method("load_assigned_modules"):
			core.load_assigned_modules()
			print_loaded_time()
			return
		await get_tree().process_frame

	push_warning("Lost autoload not ready yet")
	print_loaded_time()


func _register_framework_project_settings() -> void:
	_ASSET_MANAGER_SCRIPT.register_project_settings()


func _initialize_registrar() -> void:
	registrar = AutoloadRegistrar.new()


func _register_autoloads() -> void:
	_setup_autoloads()
	_setup_legacy_autoloads() # intentionally temporary


func _get_core() -> Node:
	return get_node_or_null("/root/Lost")


func print_loaded_time() -> void:
	print("[LostFramework] Plugin loaded in %.3f ms" % get_loaded_time_ms())


func get_loaded_time_ms() -> float:
	return float(Time.get_ticks_usec() - _load_start_usec) / 1000.0
#endregion

#region Dock Management
func _setup_dock() -> void:
	var dock_script := load(DOCK_PATH)
	if dock_script is Script:
		dock = dock_script.new()
		dock.name = Utils.framework_model()
		if dock.has_method("set_editor_interface"):
			dock.set_editor_interface(get_editor_interface())
		add_control_to_dock(DOCK_SLOT_LEFT_UL, dock)
	else:
		push_error("Failed to load dock script")


func _teardown_dock() -> void:
	if dock:
		remove_control_from_docks(dock)
		dock.queue_free()
		dock = null
#endregion

#region Autoloads Management
func _setup_autoloads() -> void:
	registrar.register_all(self)


func _setup_legacy_autoloads() -> void:
	registrar.register_legacy(self)


func _teardown_autoloads() -> void:
	registrar.unregister_all(self)
#endregion
