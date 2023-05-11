@tool
extends Node

@export var dimensions: Vector2 = Vector2(10, 10)
@export var generate: bool = false:
	set(value):
		previous_generate = generate
		generate = value
var previous_generate = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if generate != previous_generate:
		var generated_map = load("res://scenes/map/generated_map.tscn")
		previous_generate = generate
