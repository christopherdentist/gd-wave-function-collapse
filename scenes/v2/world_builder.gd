class_name WorldBuilder

enum TileType {
	NONE = -1,
	DIRT = 0,
	GRASS,
	SAND,
	WATER_SHALLOW,
	WATER_DEEP,
}

const TileScenes = {
	TileType.DIRT: preload("res://scenes/v2/tile/tile_dirt.tscn"),
	TileType.GRASS: preload("res://scenes/v2/tile/tile_grass.tscn"),
	TileType.SAND: preload("res://scenes/v2/tile/tile_sand.tscn"),
	TileType.WATER_SHALLOW: preload("res://scenes/v2/tile/tile_water_shallow.tscn"),
	TileType.WATER_DEEP: preload("res://scenes/v2/tile/tile_water_deep.tscn"),
}
const HOTSHOT_CHANCE = 0.05


func generate_random_grid(size_x: int, size_z: int):
	var rng := RandomNumberGenerator.new()
	var result: Array[Array] = []

	var placing_x: int = 0
	while placing_x < size_x:
		var row: Array[Node3D] = []
		var placing_z: int = 0
		while placing_z < size_z:
			# Pick a random tile from the list of tiles:
			var tile_type: TileType = rng.randi_range(0, TileScenes.size() - 1) as TileType
			row.push_back(TileScenes.get(tile_type).instantiate())
			placing_z += 1
		result.push_back(row)
		placing_x += 1
	return result


# TODO: support Y dimension
func _convert_coefficient_map_to_scenes(coefficient_map: Grid3D) -> Array:
	var dimensions := coefficient_map.dimensions
	var result := []
	for x_pos in range(dimensions.x):
		var row := []
		for z_pos in range(dimensions.z):
			var coefficients: Array = coefficient_map.get_value(Vector3(x_pos, 0, z_pos))
			var type: TileType = coefficients[0] if coefficients.size() > 0 else TileType.NONE
			if type == TileType.NONE or type == null:
				push_error("Placing NULL tile")
				row.push_back(null)
			else:
				row.push_back(TileScenes.get(type).instantiate())
		result.push_back(row)
	return result


# Returns a 2D Array where the nested values are each an instantiated Tile Scene.
# The Y dimension must be 1.
func generate_neighbor_respecting_random_grid(dimensions: Vector3):
	assert(dimensions.y == 1, "Grid requires a Y size of exactly 1")
	var neighbor_map := {
#		TileType.NONE: TileType.keys(),
		TileType.DIRT: [TileType.DIRT, TileType.GRASS, TileType.SAND],
		TileType.GRASS: [TileType.GRASS, TileType.DIRT, TileType.SAND],
		TileType.SAND: [TileType.SAND, TileType.DIRT, TileType.GRASS, TileType.WATER_SHALLOW],
		TileType.WATER_SHALLOW: [TileType.WATER_SHALLOW, TileType.SAND, TileType.WATER_DEEP],
		TileType.WATER_DEEP: [TileType.WATER_DEEP, TileType.WATER_SHALLOW],
	}
	var rng := RandomNumberGenerator.new()
	var coefficient_grid := Grid3D.new(dimensions, neighbor_map.keys())
	
	
	
	var get_tile_weight = func get_tile_weight(_tile_type: TileType) -> float:
		return 1.0
	
	var get_entropy_for = func get_entropy_for(coordinates: Vector3) -> float:
		# TODO: implement me
		return coefficient_grid.get_value(coordinates).size()
	
	
	# Searches the entire grid to find the tile with the lowest non-1 entropy. Tiebreaker is RNG.
	var find_lowest_entropy = func find_lowest_entropy():
		var lowest_coords: Array[Vector3] = [] # no need to initialize a point yet
		var lowest_entropy: float = TileType.size() # initialize to highest possible value
		for x in range(dimensions.x):
			for y in range(dimensions.y):
				for z in range(dimensions.z):
					var coords := Vector3(x, y, z)
					var valid_coefficients: Array = coefficient_grid.get_value(coords)
					var entropy: float = get_entropy_for.call(coords)
					if entropy <= 1:
						# an entropy of 1 is the same as an entropy of 0, and can't be collapsed
						pass
					elif entropy == lowest_entropy or (lowest_entropy > 2 and rng.randf() < HOTSHOT_CHANCE):
						lowest_coords.push_back(coords)
					elif entropy < lowest_entropy:
						lowest_entropy = entropy
						lowest_coords = [coords]
#		print_debug("lowest entropy is shared by these " + str(lowest_coords.size()) + " points: " + str(lowest_coords))
		print_debug("lowest entropy of " + str(lowest_entropy) + " is shared by " + str(lowest_coords.size()) + " points")
		return \
			lowest_coords[rng.randi_range(0, lowest_coords.size() - 1)] \
			if lowest_coords.size() > 0 \
			else null
	
	# Collapse a specific tile to a single value
	var get_collapsed_type = func get_collapsed_type(coordinates: Vector3) -> TileType:
		var valid_coefficients: Array = coefficient_grid.get_value(coordinates)
		# Keys are TileType, values are floats representing how likely they should be chosen.
		var weighted_options := {}
		
		# Initialize the weighted options
		for tile_type in neighbor_map.keys():
			if tile_type != TileType.NONE:
				weighted_options[tile_type] = 0.0
		for coefficient in valid_coefficients:
			# Default weight for all tiles is 1... at least for now
			weighted_options[coefficient] += get_tile_weight.call(coefficient)
			
			# Some semi-fancy logic to make tiles more likely to pick values based on their neighbors
			var neighbors := coefficient_grid.get_value_neighbors(coordinates)
			var num_neighbors = neighbors.size()
			for neighbor_coefficient_array in neighbors:
				var num_neighbor_options := (neighbor_coefficient_array as Array).size()
				for neighbor_coefficient in neighbor_coefficient_array:
					if weighted_options[neighbor_coefficient] > 0:
						# If all neighbors are the same type, then this tile is 3x as likely to be that type
						weighted_options[neighbor_coefficient] += get_tile_weight.call(coefficient) / num_neighbors
		
		# Pick a random coefficient based on the weighted options
		var sum_of_weights = weighted_options.values().reduce(
			func summation(active_sum, val): return active_sum + val, 0)
		var desired_coefficient = rng.randf() * sum_of_weights
		for coefficient in weighted_options.keys():
			desired_coefficient -= weighted_options[coefficient]
			if desired_coefficient < 0:
				print_debug("Tile " + str(coordinates) \
					+ " is " + str(coefficient) \
					+ " based on probability distribution " + str(weighted_options))
				return coefficient
		return TileType.NONE
	
	var is_fully_collapsed = func is_fully_collapsed() -> bool:
		return coefficient_grid.get_all_values().all(func is_collapsed(val): return val.size() <= 1)
	
	print_debug("<--  Beginning loops  -->")
	var coords_of_tile_to_update = find_lowest_entropy.call()
	while not is_fully_collapsed.call() and coords_of_tile_to_update != null:
		var collapsed_type: TileType = get_collapsed_type.call(coords_of_tile_to_update)
		print_debug("Collapsing " + str(coords_of_tile_to_update) + " to " + TileType.find_key(collapsed_type))
		var acceptable_neighbor_coefficients: Array = neighbor_map.get(collapsed_type)
		coefficient_grid.set_value(coords_of_tile_to_update, [collapsed_type])
		# Update neighbor coefficients
		for neighbor in coefficient_grid.get_value_neighbors(coords_of_tile_to_update):
			var prev_coefficients = (neighbor as Array).duplicate()
			for prev_coefficient in prev_coefficients:
				if not prev_coefficient in acceptable_neighbor_coefficients:
					(neighbor as Array).erase(prev_coefficient)
		coords_of_tile_to_update = find_lowest_entropy.call()
		
	return _convert_coefficient_map_to_scenes(coefficient_grid)


class WaveFunctionCollapse:
	var dimensions: Vector3
	var bypass_entropy_factor: float
	var NeighborMap := {
		TileType.NONE: TileType.keys(),
		TileType.DIRT: [TileType.DIRT, TileType.GRASS, TileType.SAND],
		TileType.GRASS: [TileType.GRASS, TileType.DIRT, TileType.SAND],
		TileType.SAND: [TileType.SAND, TileType.DIRT, TileType.GRASS, TileType.WATER_SHALLOW],
		TileType.WATER_SHALLOW: [TileType.WATER_SHALLOW, TileType.SAND, TileType.WATER_DEEP],
		TileType.WATER_DEEP: [TileType.WATER_DEEP, TileType.WATER_SHALLOW],
	}
	var rng: RandomNumberGenerator
	var superposition_grid: Grid3D
	
	
	func _init(dimensions: Vector3, bypass_entropy_factor: float = HOTSHOT_CHANCE):
		assert(dimensions.y == 1, "Grid requires a Y size of exactly 1")
		self.dimensions = dimensions
		self.bypass_entropy_factor = bypass_entropy_factor
		self.rng = RandomNumberGenerator.new()
		superposition_grid = _get_new_grid()
		_iter_init()
	
	
	# Creates a new Grid3D object
	func _get_new_grid() -> Grid3D:
		return Grid3D.new(dimensions, TileScenes.keys())
	
	
	# Returns the weight for a given tile type, factoring in its location and neighbors
	func _get_tile_weight(grid: Grid3D, coords: Vector3, tile_type: TileType) -> float:
		var superposition_values: Array = grid.get_value(coords)
		var num_options = superposition_values.size()
		return 1.0 / num_options
	
	
	# Computes the "shannon entropy" for the superstate of a specific coordinate.
	# Smaller values means the tile has fewer options to choose from.
	func _get_tile_entropy(grid: Grid3D, coords: Vector3) -> float:
		var superposition_values: Array = grid.get_value(coords)
		var num_options = superposition_values.size()
		var shannon_entropy = 0
		for option in superposition_values:
			var weight = _get_tile_weight(grid, coords, option)
			shannon_entropy -= weight * log(weight)
		return shannon_entropy
	
	
	func _find_points_with_lowest_entropy(grid: Grid3D) -> Array[Vector3]:
		var lowest_coords: Array[Vector3] = [] # no need to initialize a point yet
		var lowest_entropy: float = TileType.size() # initialize to highest possible value
		for x in range(dimensions.x):
			for y in range(dimensions.y):
				for z in range(dimensions.z):
					var coords := Vector3(x, y, z)
					var superpositions: Array = grid.get_value(coords)
					if superpositions.size() == 0:
						# We never want to touch fully-collapsed points
						continue
					var entropy: float = _get_tile_entropy(grid, coords)
					var let_rng_decide: bool = rng.randf() <= bypass_entropy_factor
					if entropy == lowest_entropy:
						lowest_coords.push_back(coords)
					elif entropy < lowest_entropy or let_rng_decide:
						lowest_entropy = entropy if not let_rng_decide else -1
						lowest_coords = [coords]
		return lowest_coords
	
	
	func _is_fully_collapsed(grid: Grid3D) -> bool:
		return grid.get_all_values().all(func is_collapsed(val): return val.size() <= 1)
	
	
	var _iterating_grid: Grid3D
	var _next_type:
		get:
			if _next_type != null:
				return _next_type
			_next_type = _get_collapsed_tile_type(_iterating_grid, _next_point)
			return _next_type
	var _next_point:
		get:
			if _next_point != null:
				return _next_point
			var lowest_entropy_points := _find_points_with_lowest_entropy(_iterating_grid)
			_next_point = lowest_entropy_points[
				rng.randi_range(0, lowest_entropy_points.size() - 1)]
			return _next_point
	
	
	func has_next() -> bool:
		return !_is_fully_collapsed(_iterating_grid) and _next_point != null
	
	
	func _iter_init():
		_iterating_grid = _get_new_grid()
		_next_point = null
		_next_type = null
		return has_next()
	func _iter_next():
		next()
		return has_next()
	func _iter_get():
		if _next_type < 0:
			return null
		var node: Node3D = TileScenes[_next_type].instantiate()
		node.translate(_next_point)
		return node
	
	
	# Returns a node representing the next tile to be placed.
	# Also updates internal variables to prepare for the next iteration.
	func next() -> Node3D:
		var grid = _iterating_grid
		var next_point = _next_point
		var next_type = _next_type
		
		# Collapse the point and update its neighbors
		grid.set_value(next_point, [next_type]) # set to 1 value to propagate
		_propagate_changes(grid, next_point)
		grid.set_value(next_point, []) # and later set to [] to mark it as full collapsed
		
		# The below code is old, and replaced with the _propagate_changes method
#		var valid_neighbors: Array = NeighborMap.get(next_type)
#		var all_neighbors = grid.get_value_neighbors(next_point)
#		for neighbor_superposition in all_neighbors:
#			if neighbor_superposition.size() == 1:
#				# Don't try to update the superposition for super-collapsed neighbors
#				continue
#			for neighbor_type in neighbor_superposition.duplicate():
#				if neighbor_type not in valid_neighbors:
#					neighbor_superposition.erase(neighbor_type)
		var node = _iter_get()
		
		# Finally, prepare for the next iteration
		_next_point = null
		_next_type = null
		
		return node
	
	
	# Given a specific tile, update all neighboring superpositions.
	# Recursively updates neighbors-of-neighbors too, up to a maximum of n_propagation_iterations
	func _propagate_changes(grid: Grid3D, point: Vector3, n_propagation_iterations: int = 2):
		if n_propagation_iterations <= 0:
			# Recursive escape hatch
			return
		var current_superposition = grid.get_value(point) as Array[TileType]
		
		# For each type that the current point can be, build a list of all potential neighbor types
		var append_with_valid_neighbors: Callable \
			= func append_with_valid_neighbors(accumulator: Array[TileType], type: TileType):
				accumulator.append_array(NeighborMap.get(type))
				return accumulator
		var acceptable_neighbor_types: Array[TileType] \
			= current_superposition.reduce(append_with_valid_neighbors, [] as Array[TileType])
		
		# Get the <=6 adjacent neighbors and remove impossible types from their superposition
		var all_neighbors = grid.get_neighboring_points(point) as Array[Vector3]
		for neighbor in all_neighbors:
			var is_changed := false
			var neighbor_supertypes = grid.get_value(neighbor)
			if neighbor_supertypes.size() == 1:
				# This might be a problem, I'll have to revisit
				continue
			for neighbor_type in neighbor_supertypes.duplicate():
				if neighbor_type not in acceptable_neighbor_types:
					neighbor_supertypes.erase(neighbor_type)
					is_changed = true
			if is_changed:
				# If we updated this neighbor's supertypes, propagate that change to its neighbors
				_propagate_changes(grid, neighbor, n_propagation_iterations - 1)
	
	
	func generate():
		var grid = _get_new_grid()
		var lowest_entropy_points = _find_points_with_lowest_entropy(grid)
		while not _is_fully_collapsed(grid) and lowest_entropy_points.size() > 0:
			# Find the lowest entropy point (RNG on tiebreaker) and collapse it to a single TileType
			var point_to_collapse: Vector3 = lowest_entropy_points[ \
				rng.randi_range(0, lowest_entropy_points.size() - 1)]
			var collapsed_type := _get_collapsed_tile_type(grid, point_to_collapse)
			grid.set_value(point_to_collapse, [collapsed_type])
			
			# Update neighbors based on valid neighboring rules based on this tile's collapsed type
			var valid_neighbors: Array = NeighborMap.get(collapsed_type)
			grid.get_value_neighbors(point_to_collapse).all(func(neighbor: Array):
				neighbor = neighbor.filter(func collapse_neighbor(neighbor_superposition):
					return neighbor_superposition in valid_neighbors))
			
			# Finally, prepare for the next loop be re-fetching the lowest entropy points
			lowest_entropy_points = _find_points_with_lowest_entropy(grid)
			print_debug("Set " + str(point_to_collapse) + " to " + str(TileType.find_key(collapsed_type)))
		return _convert_coefficient_map_to_scenes(grid)
	
	
	func _get_collapsed_tile_type(grid: Grid3D, next_point_to_collapse: Vector3) -> TileType:
		var collapsable_superpositions = grid.get_value(next_point_to_collapse)
		var superposition_weights := {}
		
		# Initialize the weighted options
		for potential_tile_type in collapsable_superpositions:
			# Default weight for all tiles is 1... at least for now
			superposition_weights[potential_tile_type] = _get_tile_weight(grid, next_point_to_collapse, potential_tile_type)
			
		# Pick a random coefficient based on the weighted options
		var suggested_tile = _pick_random_weighted(collapsable_superpositions, superposition_weights)
		if suggested_tile == null or suggested_tile == TileType.NONE:
			# This would make for a good recursive escape hatch, I think
			print_debug("Encountered impossible position!")
			var neighbors = grid.get_value_neighbors(next_point_to_collapse, true)
			print("\t" + str(neighbors[0]))
			print(str(neighbors[1]) + "\t" + str(collapsable_superpositions) + "\t" + str(neighbors[2]))
			print("\t" + str(neighbors[3]))
			return TileType.NONE
		return suggested_tile
	
	
	# Given an Array<T> and a Dictionary<T, float>, picks a random value from the array.
	# The weights in the Dictionary dictate how likely each value in the Array will be picked.
	# A weight of 0 (or an omitted key) means the corresponding value will never be picked.
	# Otherwise, the weights are considered relative to each other and can be any positive number.
	func _pick_random_weighted(values_to_pick_from: Array, weight_per_value: Dictionary):
		var sum_of_weights = weight_per_value.values().reduce(
			func summation(active_sum, val): return active_sum + max(0, val), 0)
		# Short circuit and return null when we can't pick anything from the input
		if sum_of_weights == 0 or values_to_pick_from.size() == 0:
			return null
		
		var random_value: float = rng.randf() * sum_of_weights
		for value in values_to_pick_from:
			random_value -= weight_per_value[value] if weight_per_value.has(value) else 0
			if random_value < 0:
				return value
		
		# This line probably shouldn't ever get run, unless weights weren't provided
		push_error("Failed to pick a weighted value from " + str(values_to_pick_from))
		return values_to_pick_from[rng.randi_range(0, values_to_pick_from.size())]
	
	
	func _convert_coefficient_map_to_scenes(grid: Grid3D):
		var dimensions := grid.dimensions
		var result := []
		for x_pos in range(dimensions.x):
			var row := []
			for z_pos in range(dimensions.z):
				var coefficients: Array = grid.get_value(Vector3(x_pos, 0, z_pos))
				var type: TileType = coefficients[0] if coefficients.size() > 0 else TileType.NONE
				if type == TileType.NONE or type == null:
					push_error("Placing NULL tile")
					row.push_back(null)
				else:
					row.push_back(TileScenes.get(type).instantiate())
			result.push_back(row)
		return result
	
	
	func convert_to_labels(grid: Grid3D = _iterating_grid):
		const LABEL_OFFSET_Y = 1
		var labels := []
		var internal_grid = grid.grid
		for x_pos in range(internal_grid.size()):
			for y_pos in range(internal_grid[x_pos].size()):
				for z_pos in range(internal_grid[x_pos][y_pos].size()):
					var label = Label3D.new()
					label.translate(Vector3(x_pos, y_pos + LABEL_OFFSET_Y, z_pos))
					label.text = str(internal_grid[x_pos][y_pos][z_pos])
					var coords = Vector3(x_pos, y_pos, z_pos)
					if _next_point != null and coords.is_equal_approx(_next_point):
						label.text = TileType.find_key(_next_type)
						label.font_size += 8
						label.translate(Vector3(0, 0.5, 0))
					labels.push_back(label)
		return labels


class Grid3D:
	# grid has the structure of grid[x_coord][y_coord][z_coord]
	var grid: Array[Array]
	# dimensions can be inferred from the grid's shape, but this Vector3 is easier
	var dimensions: Vector3
	
	
	func _init(dimensions: Vector3, default_value = null):
		self.dimensions = dimensions
		_set_all_values_of_grid_to(default_value)
	
	
	func _set_all_values_of_grid_to(default_value):
		var x_rows: Array[Array] = []
		for x in range(dimensions.x):
			var y_rows: Array[Array] = []
			for y in range(dimensions.y):
				var z_rows: Array = []
				for z in range(dimensions.z):
					var val_to_assign = (default_value as Array).duplicate()
					if val_to_assign == null:
						val_to_assign = default_value
					z_rows.push_back(val_to_assign)
				y_rows.push_back(z_rows)
			x_rows.push_back(y_rows)
		grid = x_rows
	
	
	func get_value(pos: Vector3):
		if pos.x < 0 or pos.x >= dimensions.x \
			or pos.y < 0 or pos.y >= dimensions.y \
			or pos.z < 0 or pos.z >= dimensions.z:
			return null
		return grid[pos.x][pos.y][pos.z]
	
	
	func set_value(pos: Vector3, new_value) -> void:
		if pos.x < 0 or pos.x >= dimensions.x \
			or pos.y < 0 or pos.y >= dimensions.y \
			or pos.z < 0 or pos.z >= dimensions.z:
			return
		grid[pos.x][pos.y][pos.z] = new_value
	
	
	# Returns the <=6 adjacent neighbors to this tile, filtering out any null neighbors
	func get_value_neighbors(pos: Vector3, include_nulls = false) -> Array:
		return get_neighboring_points(pos, include_nulls) \
			.map(func map_point_to_superposition(point): return get_value(point))
	
	# Returns the <=6 adjacent points relative to the passed point.
	func get_neighboring_points(pos: Vector3, include_nulls = false) -> Array:
		var neighbors = []
		var x_offset = Vector3(1, 0, 0)
		var y_offset = Vector3(0, 1, 0)
		var z_offset = Vector3(0, 0, 1)
		neighbors.push_back(pos + x_offset)
		neighbors.push_back(pos - x_offset)
		neighbors.push_back(pos + y_offset)
		neighbors.push_back(pos - y_offset)
		neighbors.push_back(pos + z_offset)
		neighbors.push_back(pos - z_offset)
		return neighbors if include_nulls \
			else neighbors.filter(func keep_in_bounds(point): return get_value(point) != null)

	# Returns a 1D list of all values. Order is not guaranteed.
	func get_all_values() -> Array:
		var result := []
		for x_col in grid:
			for y_col in x_col:
				for z_col in y_col:
					result.append(z_col)
		return result
	
	
	func duplicate() -> Grid3D:
		var other_grid: Grid3D = Grid3D.new(dimensions)
		for x_index in range(grid.size()):
			for y_index in range(grid[x_index].size()):
				for z_index in range(grid[x_index][y_index].size()):
					other_grid.grid[x_index][y_index][z_index] = \
						grid[x_index][y_index][z_index].duplicate()
		return other_grid
