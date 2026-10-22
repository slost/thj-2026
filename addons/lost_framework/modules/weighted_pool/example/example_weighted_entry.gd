## This is a simple example of a WeightedEntry implementation for testing and demonstration purposes.
@tool
extends WeightedEntry
class_name ExampleWeightedEntry


## In this example, the WeightedEntry is designed to return an integer value when resolved.
## The expected_type() method is overridden to indicate that the value should be of type int.
## This allows for testing the functionality of the WeightedPool and ensuring that it can handle entries with different types of values.
func expected_type() -> Variant:
    return TYPE_INT
