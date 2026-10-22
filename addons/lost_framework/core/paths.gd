## Centralized paths for Lost Framework
@tool
class_name Paths


#region Framework Paths
const LOST_ROOT := "res://addons/lost_framework/"

const MODULES := LOST_ROOT + "modules/"
const LOST_MODULES_BUILTIN := MODULES + "builtin/"

const LOST_RUNTIME := LOST_ROOT + "runtime/"
const LOST_AUTOLOADS := LOST_RUNTIME + "autoloads/"

const RESOURCES := LOST_ROOT + "resources/"
const LOST_ASSETS := RESOURCES + "assets/"
const THEMES := LOST_ASSETS + "themes/"

const DEFAULT_THEME: String = "lost_theme.tres"
const MAIN_THEME: String = THEMES + DEFAULT_THEME
#endregion


#region Runtime Data Paths
const DEFAULT_DATA_ROOT := "res://lost/"
static var _data_root: String = DEFAULT_DATA_ROOT # TODO: Will change this later to base on user configurable path
const DATA_ASSETS_FOLDER := "assets/"
const DATA_ASSET_ENTRIES_FOLDER := DATA_ASSETS_FOLDER

## Returns the path to the data root folder
static func data_root() -> String:
	# TODO: if user configurable path is set, return that
	return _data_root

## Returns the path to the data assets folder
static func data_assets() -> String:
	return data_root() + DATA_ASSETS_FOLDER


## Returns the path to the asset entries folder
static func data_asset_entries() -> String:
	return data_root() + DATA_ASSET_ENTRIES_FOLDER
#endregion
