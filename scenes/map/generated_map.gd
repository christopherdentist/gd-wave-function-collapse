@tool
extends Node3D

var world_cube_scene = load("res://scenes/worldcube/world_cube.tscn")
const WorldCubeScenes = {
	WorldCube.Type.DIRT: preload("res://scenes/worldcube/dirt/dirt.tscn"),
	WorldCube.Type.GRASS: preload("res://scenes/worldcube/grass/grass.tscn"),
	WorldCube.Type.SAND: preload("res://scenes/worldcube/sand/sand.tscn"),
}

const BLOCK_NAME_PREFIX = "WorldCube"

@export var size_x = 10
@export var size_z = 10

@export_group("Editor Only")
@export var generate = false:
	set(value):
		if not Engine.is_editor_hint():
			return
		generate = value
		if value:
			generate_map()
			if commit:
				queue_commit = true
		else:
			delete_map()
@export var commit = false:
	set(value):
		if not Engine.is_editor_hint():
			return
		commit = value
		queue_commit = true
var queue_commit := false

@export_group("", "")

var rng = RandomNumberGenerator.new()


func _ready():
	if Engine.is_editor_hint():
		return
	generate_map()


func _process(_delta):
	if Engine.is_editor_hint():
		if queue_commit:
			commit_children(commit)
			queue_commit = false
		return
	elif Input.is_action_just_pressed("regenerate"):
		delete_map()
		generate_map()


func generate_map():
	var new_blocks := generate_blocks()
	for node in new_blocks:
		add_child(node)


func generate_blocks() -> Array[CollisionObject3D]:
	var instantiated_nodes = _get_cubes_as_nodes()

	var nodes: Array[CollisionObject3D] = []
	var placing_x: float = -size_x / 2.0
	while placing_x < size_x / 2.0:
		var placing_z: float = -size_z / 2.0
		while placing_z < size_z / 2.0:
			var destination := transform.translated_local(Vector3(placing_x, 0, placing_z))
			var desired_type := _get_desired_block_type(destination)
##			var original_block: Area3D = BLOCKS[BLOCKS.keys()[desired_type]]
#			var original_block: WorldCube = world_cube_scene.instantiate()
#			original_block.variant = desired_type as WorldCube.Type
##			var block: Area3D = original_block.duplicate()
#			var block = original_block
			var block: WorldCube = instantiated_nodes.get(desired_type).duplicate()
			block.transform = destination
			var type_str = WorldCube.Type.find_key(desired_type)
			block.name = BLOCK_NAME_PREFIX + type_str + "[" + str(placing_x) + "," + str(placing_z) + "]"
			nodes.push_back(block)
			placing_z += 1
		placing_x += 1
	return nodes


func delete_map():
	for child in get_children():
		if child is CollisionObject3D:
			child.queue_free()
			remove_child(child)


func _get_desired_block_type(_destination: Transform3D) -> int:
	return rng.randi_range(0, WorldCubeScenes.size() - 1)


func _get_cubes_as_nodes() -> Dictionary:
	var instantiated_nodes = {}
	for world_cube_type in WorldCubeScenes.keys():
		instantiated_nodes[world_cube_type] = WorldCubeScenes.get(world_cube_type).instantiate()
	return instantiated_nodes


func commit_children(should_commit: bool):
	if not Engine.is_editor_hint() or get_tree() == null:
		return
	var root_node = get_tree().edited_scene_root
	for child in get_children():
		if child is WorldCube:
			child.owner = root_node if should_commit else null
		else:
			print_debug("Child " + child.name + " was not a WorldCube!")
