extends Component
class_name ContainerComponent
## Marks its host Entity as something other entities can be put in (box,
## bag). If the host also has an [OpenableComponent], it must be open.
## Its contents are its child Entities.


## True if things can be put in now (not closed).
func is_accessible() -> bool:
	var host := get_host()
	if host is Entity:
		var openable := host.get_component(OpenableComponent) as OpenableComponent
		return openable == null or openable.is_open
	return true
