class_name EntitySpawner extends Node2D

signal request_spawn
signal update_virtual_tile_map(cell:Vector2i, prop:String, data:Variant)
# Parameters
@export var spawn_scene: PackedScene
@export var max_spawn: int = 10
@export var pool_size: int = 20
@export var spawn_interval: float = 1.0

# Internal variables
var active_instances: int = 0
var instance_pool: int
var spawn_timer: Timer

 
func _ready():
	# Initialize the pool and timer
	instance_pool = pool_size

	spawn_timer = Timer.new()
	spawn_timer.set_wait_time(spawn_interval)
	spawn_timer.set_one_shot(false)
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)
	spawn_timer.start()


func get_quadrants(rect: Rect2) -> Array[Rect2]:
	var quadrants:Array[Rect2] = []
	
	# Calculate the center point
	var center_x = rect.position.x + rect.size.x / 2
	var center_y = rect.position.y + rect.size.y / 2

	# Create the four quadrants
	var top_left = Rect2(rect.position, Vector2(center_x - rect.position.x, center_y - rect.position.y))
	var top_right = Rect2(Vector2(center_x, rect.position.y), Vector2(rect.size.x / 2, rect.size.y / 2))
	var bottom_left = Rect2(Vector2(rect.position.x, center_y), Vector2(rect.size.x / 2, rect.size.y / 2))
	var bottom_right = Rect2(Vector2(center_x, center_y), Vector2(rect.size.x / 2, rect.size.y / 2))
	
	# Add quadrants to the array
	quadrants.append(top_left)
	quadrants.append(top_right)
	quadrants.append(bottom_left)
	quadrants.append(bottom_right)
	
	return quadrants


func _on_spawn_timer_timeout():
	if active_instances < max_spawn and instance_pool > 0:
		request_spawn.emit()


func _on_instance_freed():
	active_instances -= 1


func spawn(player_map_position:Vector2i, used_cells:Array[Vector2i], virtual_tile_map:Dictionary) -> void:
	if spawn_scene.can_instantiate() == false: return
	var spawn_map_position:Vector2i = _get_random_tile_away_from(player_map_position, used_cells,virtual_tile_map)
	var i:Node2D = spawn_scene.instantiate()
	add_child(i)
	i.position = virtual_tile_map[spawn_map_position].local + Vector2(-32,-32)
	update_virtual_tile_map.emit(spawn_map_position, "grid_node",i)
	i.tree_exited.connect(_on_instance_freed)
	active_instances += 1
	instance_pool -= 1	


func _get_random_tile_away_from(target_pos:Vector2, used_cells:Array[Vector2i], virtual_tile_map:Dictionary, min_distance:int = 8) -> Vector2:
	var picked_tiles:Array[Vector2i] = []
	var valid_tiles:Array[Vector2i] = []
	for cell in used_cells:
		if abs(cell.x - target_pos.x) + abs(cell.y - target_pos.y) >= min_distance:
			picked_tiles.append(cell)

	# Select a random tile from the valid tiles
	for tile in picked_tiles:
		if virtual_tile_map.has(tile) == false:continue
		if virtual_tile_map[tile].grid_node != null:continue
		if virtual_tile_map[tile].is_wall: continue
		valid_tiles.append(tile)
	if valid_tiles.size() > 0:
		var index:int = randi() % valid_tiles.size()
		var selected_tile:Vector2i = valid_tiles[index]
		valid_tiles.pop_at(index)
		return selected_tile
	else:
		return -Vector2i.ONE
