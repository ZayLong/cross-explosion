extends TileMapLayer

signal move_response(_new_position:Vector2, _requester:Node2D)
signal took_damage()
enum ExplosionPattern {CROSS, SQUARE, DIAMOND, PATCH}

@export var explosion_node:PackedScene
@export var enemy_node:PackedScene
@export var starting_position:Vector2i = Vector2i.ONE

var player:Node2D
var grid_nodes:Dictionary
var virtual_tile_map:Dictionary
var explosion_interval:int = 3
var astar_grid:AStarGrid2D = AStarGrid2D.new()
var enemy_count:int = 5
var turns:int = 0
var is_exploding:bool = false
func _ready() -> void:
	for cell in self.get_used_cells():
		virtual_tile_map[cell] = {
			"grid_node": null,
			"is_wall": get_cell_tile_data(cell).get_custom_data("is_wall"),
			"explosion_interval": explosion_interval, 
			"moves_per_turn": 2
		}
	for child in get_children():
		if child.is_in_group(&"GridNodes"):
			child.move_request.connect(_on_move_request.bind(child))
			var center_coord:Vector2i = self.local_to_map(child.position)
			#if child.is_in_group(&"Enemies"): connect("took_damage")
			if child.is_in_group(&"Player"): 
				center_coord = starting_position
				child.position = self.map_to_local(center_coord)
			virtual_tile_map[center_coord].grid_node = child
	player = get_tree().get_first_node_in_group("Player")
	_astar_grid_setup()
	for n in enemy_count:
		_spawn_enemies()


## Evaluate whether or not the requester can move and to where.
func _on_move_request(_direction:Vector2i, _node:Node2D):
	var center_coord:Vector2i = self.local_to_map(_node.position)
	var new_center_coord:Vector2i = center_coord + _direction
	if _is_tile_valid(new_center_coord) == false: return
	
	virtual_tile_map[new_center_coord] = virtual_tile_map[center_coord].duplicate()
	virtual_tile_map[center_coord].grid_node = null
	move_response.emit(self.map_to_local(new_center_coord), _node)
	
	_move_enemies()
	## Everyone has finished moving, now lets EXPLODE (maybe)
	_evaluate_explosion(new_center_coord)
	


func _evaluate_explosion(_center_coord:Vector2i, _pattern:ExplosionPattern = ExplosionPattern.SQUARE, _explosion_range:int = 3) -> void:
	is_exploding = true
	virtual_tile_map[_center_coord].explosion_interval -= 1
	if virtual_tile_map[_center_coord].explosion_interval > 0: return
	_explosion_range = _explosion_range if _explosion_range % 2 != 0 else _explosion_range + 1 # make sure it's fairly odd!
	var offset:Vector2i = Vector2i.ONE * ( _explosion_range - 1 ) / 2
	for r in _explosion_range if _explosion_range % 2 != 0 else _explosion_range + 1:
		for c in _explosion_range:
			var cell:Vector2i = (_center_coord - Vector2i(r,c)) + offset
			if _pattern == ExplosionPattern.PATCH: if (r + c) % 2 == 0: continue ## This makes a cool patchwork kind of pattern!
			if _pattern == ExplosionPattern.CROSS: if cell.x != _center_coord.x && cell.y != _center_coord.y: continue ## This will make a cross pattern
			if _pattern == ExplosionPattern.DIAMOND: if abs(r - ((_explosion_range - 1)/2)) + abs(c - ((_explosion_range - 1)/2)) > ((_explosion_range - 1)/2): continue ## this makes a diamond pattern!
			_instance_explosion(cell)
			_hurt_enemies(cell)
	virtual_tile_map[_center_coord].explosion_interval = explosion_interval
	is_exploding = false


func _hurt_enemies(cell) -> void:
	if virtual_tile_map.has(cell) == false: return
	if virtual_tile_map[cell].grid_node == null: return
	if virtual_tile_map[cell].grid_node.is_in_group("Enemies") == false: return
	virtual_tile_map[cell].grid_node.queue_free()


func _instance_explosion(cell:Vector2i) -> void:
	if explosion_node == null || explosion_node.can_instantiate() == false: return
	var instance = explosion_node.instantiate()
	instance.position = map_to_local(cell)
	add_child(instance)


## ENEMY MOVEMENT
func _astar_grid_setup() -> void:
	var cell_size = self.tile_set.tile_size
	var tile_map_rect:Rect2i = self.get_used_rect()
	
	astar_grid.region = tile_map_rect
	astar_grid.cell_size = cell_size
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	if astar_grid.is_dirty(): astar_grid.update()
	for cell in self.get_used_cells():
		var tile_data:TileData = self.get_cell_tile_data(cell)
		if tile_data.get_custom_data('is_wall') == true:
			astar_grid.set_point_solid(cell, true)


## Enemies have x change of exploding, creating a chain reaction
func _explode_enemies() -> void:
	pass


func _sort_by_distance(a:Node2D, b:Node2D):
	var player_tile:Vector2i = local_to_map(player.position)
	var a_tile:Vector2i = a.position
	var b_tile:Vector2i = b.position
	
	var a_distance = abs((a_tile.x + player_tile.x) - (a_tile.y + player_tile.y))
	var b_distance = abs((b_tile.x + player_tile.x) - (b_tile.y + player_tile.y))
	
	if a_distance < b_distance:
		return false
	else:
		return true


func _move_enemies() -> void:
	var enemies:Array[Node] = get_tree().get_nodes_in_group("Enemies")
	enemies.sort_custom(_sort_by_distance) ## enemies move in the order of closest to farthest from the player
	for enemy in enemies:
		var our_pos:Vector2i = self.local_to_map(enemy.position)
		var player_position:Vector2i = self.local_to_map(player.position)
		var movement_points = astar_grid.get_point_path(our_pos, player_position)
		var new_center_coord:Vector2i = local_to_map(movement_points[1])

		if _is_tile_valid(new_center_coord) == false: return
		if movement_points.size() > 1: enemy.global_position = movement_points[1]
		virtual_tile_map[new_center_coord] = virtual_tile_map[our_pos].duplicate()
		virtual_tile_map[our_pos].grid_node = null


func _get_random_tile_away_from(target_pos: Vector2, min_distance:int = 8) -> Vector2:
	var picked_tiles:Array[Vector2i] = []
	var valid_tiles:Array[Vector2i] = []
	for cell in get_used_cells():
		if abs(cell.x - target_pos.x) + abs(cell.y - target_pos.y) >= min_distance:
			picked_tiles.append(cell)

	# Select a random tile from the valid tiles
	for tile in picked_tiles:
		if _is_tile_valid(tile) == false: continue
		valid_tiles.append(tile)
	if valid_tiles.size() > 0:
		var selected_tile:Vector2i = valid_tiles[randi() % valid_tiles.size()]
		
		return selected_tile
	else:
		return -Vector2i.ONE


func _is_tile_valid(coord:Vector2i) -> bool:
	if virtual_tile_map.has(coord) == false: return false
	if virtual_tile_map[coord].grid_node != null: return false
	if virtual_tile_map[coord].is_wall: return false
	return true


func _spawn_enemies() -> void:
	if enemy_node.can_instantiate() == false: return
	var player_map_position:Vector2i = local_to_map(player.position)
	var spawn_map_position:Vector2i = _get_random_tile_away_from(player_map_position)
	var i:Node2D = enemy_node.instantiate()
	i.position = map_to_local(spawn_map_position)
	add_child(i)
	virtual_tile_map[spawn_map_position].grid_node = i
	
