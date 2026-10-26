extends Component
class_name FictionReactionComponent
## Gives its host Entity [FictionReaction]s: scripted responses to commands
## (a sign that can be read, a moth flying out of a box the first time it is
## opened). [method FictionWorld.run] finds and runs them.


@export var reactions: Array[FictionReaction] = []
