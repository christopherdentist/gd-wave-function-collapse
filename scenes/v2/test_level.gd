@tool
extends Node3D

@export var size_x = 10
@export var size_z = 10
@export var entropy_bypass_coefficient: float = 0.05
@export var show_labels = false:
	set(value):
		show_labels = value
		_display_labels(value)
@export var paused = false:
	set(value):
		paused = value
		_display_labels(value)

@export_group("Editor-only")
@export var generate: bool = false:
	set(value):
		reset_tiles()
		var editor_wave_function = WorldBuilder.WaveFunctionCollapse.new(Vector3(size_x, 1, size_z))
		while _place_next_tile(editor_wave_function):
			# Place all the tiles
			pass
		print_debug("Level generation complete")

@onready var TilePlacementTimer: Timer = $TilePlacementTimer
@onready var Builder: WorldBuilder = WorldBuilder.new()

var level_grid: Array
var level_grid_x = 0
var level_grid_z = 0
var wave_collapse: WorldBuilder.WaveFunctionCollapse

# Called when the node enters the scene tree for the first time.
func _ready():
#	level_grid = builder.generate_random_grid(size_x, size_z)
#	level_grid = builder.generate_neighbor_respecting_random_grid(Vector3(size_x, 1, size_z))
#	level_grid = builder.WaveFunctionCollapse.new(Vector3(size_x, 1, size_z)).generate()
	wave_collapse = Builder.WaveFunctionCollapse.new(Vector3(size_x, 1, size_z), entropy_bypass_coefficient)
	if Engine.is_editor_hint():
		var i = 0
		while i < size_x * size_z:
			_place_tile()
			i += 1
		return
	($Player/Head/CameraFPS as Camera3D).make_current()
	TilePlacementTimer.start()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Engine.is_editor_hint():
		return
	if Input.is_action_just_pressed("regenerate"):
		if not paused:
			TilePlacementTimer.stop()
			reset_tiles()
			wave_collapse = Builder.WaveFunctionCollapse.new(Vector3(size_x, 1, size_z), entropy_bypass_coefficient)
			TilePlacementTimer.wait_time = 0.05
			TilePlacementTimer.start()
		else:
			TilePlacementTimer.wait_time = 2
			TilePlacementTimer.start()
	if Input.is_action_just_pressed("pause"):
		paused = not paused
		if wave_collapse.has_next():
			TilePlacementTimer.stop() \
				if not TilePlacementTimer.is_stopped() \
				else TilePlacementTimer.start()


func _place_child(child: Node3D, offset):
	if child == null:
		return
	if offset != null:
#		child.transform = transform.translated_local(offset)
		child.translate(offset)
	add_child(child)


func _place_tile():
	return # doesnt work at the moment
	if level_grid_x >= size_x:
		print_debug("No more tiles to place")
		return
	var tile = level_grid[level_grid_x][level_grid_z]
	if tile != null:
		var offset := Vector3(-(size_x - 1) / 2.0 + level_grid_x, 0, -(size_z - 1) / 2.0 + level_grid_z)
		_place_child(tile, offset)
	
	if level_grid_z + 1 >= size_z:
		# When reaching the end of the Z axis, reset Z to 0 and increment X for the next row
		level_grid_x += 1
		level_grid_z = 0
	else:
		# Otherwise, increment Z to continue placing the same row
		level_grid_z += 1


func _on_tile_placement_timer_timeout():
#	if level_grid_x >= size_x:
#		TilePlacementTimer.stop()
#		print_debug("Breaking the loop")
#		return
#	_place_tile()
	var did_place = _place_next_tile()
	if not did_place or not wave_collapse.has_next():
		TilePlacementTimer.stop()
		print_debug("All blocks have been placed. Thank you for your cooperation.")
		return
	_display_labels(false)
	_display_labels(show_labels or paused)


func _place_next_tile(editor_wave_function = wave_collapse) -> bool:
	if editor_wave_function.has_next():
		var tile := editor_wave_function.next()
		_place_child(tile, Vector3(-size_x / 2, 0, -size_z / 2))
		return true
	return false


func reset_tiles():
	for child in get_children():
		if child is Tile:
			child.queue_free()
			remove_child(child)


func _display_labels(create):
	if not create and not show_labels:
		for child in get_children():
			if child is Label3D:
				child.queue_free()
				remove_child(child)
		return
	var labels = wave_collapse.convert_to_labels()
	for label in labels:
		_place_child(label, Vector3(-size_x / 2, 0, -size_z / 2))
	
	
