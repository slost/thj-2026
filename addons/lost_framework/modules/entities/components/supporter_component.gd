extends Component
class_name SupporterComponent
## Marks its host Entity as a surface other entities can be put on (table,
## shelf). If the host also has an [OpenableComponent], it must be open.
## What is on it are its child Entities.


## True if things can be put on now (not closed).
func is_accessible() -> bool:
	var host := get_host()
	if host is Entity:
		var openable := host.get_component(OpenableComponent) as OpenableComponent
		return openable == null or openable.is_open
	return true
