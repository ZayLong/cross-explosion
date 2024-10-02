extends TileMapLayer

signal move_response(_new_position:Vector2, _requester:Node2D)
signal took_damage()
signal update_score(score:int)
signal update_wave(wave:int)
signal update_lives(lives:int)
signal update_kill_count(kill_count:int)
signal update_upgrades(upgrade_info:Dictionary)
enum ExplosionPattern {CROSS, SQUARE, DIAMOND, PATCH}

@export var explosion_node:PackedScene
@export var enemy_node:PackedScene
@export var starting_position:Vector2i = Vector2i.ONE

var player:Node2D
var lives:int = 3
var score:int = 0

var current_wave:int = 1
var kill_count:int = 0
var grid_nodes:Dictionary
var virtual_tile_map:Dictionary

var astar_grid:AStarGrid2D = AStarGrid2D.new()
var enemy_count:int = 5
var turns:int = 0
var is_exploding:bool = false
var whos_turn:String = "PLAYER" ## PLAYER | ENEMY | EXPLOSION?
var is_processing_turn:bool = false
var steps_per_turn:int = 1
var player_map_pos:Vector2i

## UPGRADES AND POWERUPS
var explosion_pattern:ExplosionPattern = ExplosionPattern.CROSS
var explosion_range:int = 3
var explosion_interval:int = 3
var explosion_power:int = 1
var explosion_chain:float = 1 # probability that an enemy will blow up and cause a chain reaction
var score_bonus:int = 1
var upgrade_discount:float = 1

var current_upgrades:Dictionary = {
	'explosion_pattern': explosion_pattern,
	'explosion_range': explosion_range,
	'explosion_interval': explosion_interval,
	'explosion_power': explosion_power,
	'explosion_chain': explosion_chain,
	"score_bonus": score_bonus,
	"upgrade_discount": upgrade_discount,
	"steps_per_turn": steps_per_turn
}

func _ready() -> void:
	var my_seed:int = "Godot Rocks".hash()
	seed(my_seed)

	for cell in self.get_used_cells():
		virtual_tile_map[cell] = {
			"grid_node": null,
			"is_wall": self.get_cell_tile_data(cell).get_custom_data(&"is_wall"),
			"is_hazardous": false,
			"is_enemy": false,
			"is_player": false
		}
	for child in get_children():
		if child.is_in_group(&"GridNodes"):
			
			var map_pos:Vector2i = self.local_to_map(child.position)
			if child.is_in_group(&"Walls"): virtual_tile_map[map_pos].is_wall = true
			if child.is_in_group(&"Hazards"): virtual_tile_map[map_pos].is_hazardous = true
			child.position = map_to_local(map_pos)
			if child.is_in_group(&"Player"):
				#virtual_tile_map[map_pos].is_player = true
				child.move_request.connect(_on_move_request.bind(child))
				player_map_pos = map_pos
				#map_pos = starting_position
				#child.position = self.map_to_local(map_pos)
			virtual_tile_map[map_pos].grid_node = child
	player = get_tree().get_first_node_in_group(&"Player")
	_astar_grid_setup()
	for n in enemy_count:
		_spawn_enemies()



func _get_powerup(upgrade_type) -> void:
	
	pass


func _get_upgrade() -> void:
	
	update_upgrades.emit(current_upgrades)
	pass


## Evaluate whether or not the requester can move and to where.
func _on_move_request(_direction:Vector2i, _node:Node2D) -> void:
	if is_processing_turn: return
	if _node.is_in_group(&"Player") == false: return
	
	var new_map_pos:Vector2i = player_map_pos + _direction
	if virtual_tile_map.has(new_map_pos) == false: return
	if virtual_tile_map[new_map_pos].is_wall: return
	is_processing_turn = true
	if virtual_tile_map[new_map_pos].is_hazardous:
		_hurt_player()
	virtual_tile_map[new_map_pos] = virtual_tile_map[player_map_pos].duplicate()
	virtual_tile_map[player_map_pos].grid_node = null
	player_map_pos = new_map_pos
	move_response.emit(self.map_to_local(new_map_pos), _node)
	
	await _evaluate_explosion(new_map_pos)
	if steps_per_turn <= 0:
		_move_enemies()
		steps_per_turn = 1
	else:
		steps_per_turn -= 1
	## Everyone has finished moving, now lets EXPLODE (maybe)
	is_processing_turn = false
	update_upgrades.emit(current_upgrades)
	

signal completed
func _evaluate_explosion(_center_coord:Vector2i, forced:bool = false, _pattern:ExplosionPattern = ExplosionPattern.CROSS, _explosion_range:int = 3) -> void:
	var has_emitted:bool = false
	is_exploding = true
	
	if forced == false: explosion_interval -= 1
	if explosion_interval > 0 && forced == false: 
		is_exploding = false
		return
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
		if r == _explosion_range - 1:
			## Simulate some fancy explosion animation
			get_tree().create_timer(0.25).timeout.connect(
				func():
					completed.emit()
					has_emitted = true
					)

	explosion_interval = current_upgrades.explosion_interval
	is_exploding = false
	if has_emitted == false: await completed


func _hurt_enemies(cell:Vector2i) -> void:
	if virtual_tile_map.has(cell) == false: return
	if virtual_tile_map[cell].grid_node == null: return
	if virtual_tile_map[cell].grid_node.is_in_group(&"Enemies") == false: return
	## await grid_node.hurt_animation
	if virtual_tile_map[cell].grid_node.is_queued_for_deletion() == false: 
		virtual_tile_map[cell].grid_node.queue_free()
		virtual_tile_map[cell].grid_node = null
		_explode_enemies(cell)
	score += 1
	kill_count += 1
	update_score.emit(score)
	update_kill_count.emit(kill_count)


func _instance_explosion(cell:Vector2i) -> void:
	if explosion_node == null || explosion_node.can_instantiate() == false: return
	var instance = explosion_node.instantiate()
	instance.position = self.map_to_local(cell)
	self.add_child(instance)


## ENEMY MOVEMENT
func _astar_grid_setup() -> void:
	var cell_size = self.tile_set.tile_size
	var tile_map_rect:Rect2i = self.get_used_rect()
	
	astar_grid.region = tile_map_rect
	astar_grid.cell_size = cell_size
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	if astar_grid.is_dirty(): astar_grid.update()


func _astar_update_solids() -> void:
	for cell in self.get_used_cells():
		var tile_data:TileData = self.get_cell_tile_data(cell)
		#if _is_tile_valid(cell) == false: astar_grid.set_point_solid(cell, true)
		if tile_data.get_custom_data('is_wall') == true: astar_grid.set_point_solid(cell, true)
		if virtual_tile_map.has(cell):
			if virtual_tile_map[cell].grid_node != null:
				if virtual_tile_map[cell].grid_node.is_in_group(&"Walls"): astar_grid.set_point_solid(cell, true)


## Enemies have x change of exploding, creating a chain reaction
func _explode_enemies(cell:Vector2i) -> void:
	await _evaluate_explosion(cell, true)
	pass

func _sort_by_real_distance(a:Node2D,b:Node2D) -> bool:
	
	if a.position.distance_to(player.position) < b.position.distance_to(player.position):
		return true
	else:
		return false
	
func _sort_by_grid_distance(a:Node2D, b:Node2D) -> bool:
	var player_tile:Vector2i = self.local_to_map(player.position)
	var a_tile:Vector2i = a.position
	var b_tile:Vector2i = b.position
	
	var a_distance = abs((a_tile.x + player_tile.x) - (a_tile.y + player_tile.y))
	var b_distance = abs((b_tile.x + player_tile.x) - (b_tile.y + player_tile.y))
	
	if a_distance < b_distance:
		return false
	else:
		return true


func _move_enemies() -> void:
	_astar_update_solids()
	var enemies:Array[Node] = get_tree().get_nodes_in_group(&"Enemies")
	enemies.sort_custom(_sort_by_real_distance) ## enemies move in the order of closest to farthest from the player
	
	for enemy in enemies:
		var our_pos:Vector2i = self.local_to_map(enemy.position)
		var player_position:Vector2i = self.local_to_map(player.position)
		var movement_points = astar_grid.get_point_path(our_pos, player_position)
		if movement_points.size() < 2: continue
		var new_map_pos:Vector2i = self.local_to_map(movement_points[1])
		
		if virtual_tile_map.has(new_map_pos) == false: continue
		if virtual_tile_map[new_map_pos].grid_node != null:
			if virtual_tile_map[new_map_pos].grid_node.is_in_group(&"Enemies"): 
				continue
		if virtual_tile_map[new_map_pos].is_wall: continue
		if movement_points.size() > 1: 
			enemy.global_position = movement_points[1]
		if virtual_tile_map[new_map_pos].grid_node == player:
			_hurt_player()
			continue
		if virtual_tile_map[new_map_pos].is_hazardous: _hurt_enemies(our_pos)
		if virtual_tile_map[new_map_pos].grid_node != player:
			virtual_tile_map[new_map_pos] = virtual_tile_map[our_pos].duplicate()
			virtual_tile_map[our_pos].grid_node = null
		await get_tree().create_timer(0.1).timeout


func _hurt_player() -> void:
	lives -= 1
	update_lives.emit(lives)
	if lives >= 0:
		await _evaluate_explosion(self.local_to_map(player.position), true)
	else:
		print("DEAD")
	# some hurt feedback


func _get_random_tile_away_from(target_pos: Vector2, min_distance:int = 8) -> Vector2:
	var picked_tiles:Array[Vector2i] = []
	var valid_tiles:Array[Vector2i] = []
	for cell in self.get_used_cells():
		if abs(cell.x - target_pos.x) + abs(cell.y - target_pos.y) >= min_distance:
			picked_tiles.append(cell)

	# Select a random tile from the valid tiles
	for tile in picked_tiles:
		if _is_tile_valid(tile) == false: continue
		valid_tiles.append(tile)
	if valid_tiles.size() > 0:
		var index:int = randi() % valid_tiles.size()
		var selected_tile:Vector2i = valid_tiles[index]
		valid_tiles.pop_at(index)
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
	var player_map_position:Vector2i = self.local_to_map(player.position)
	var spawn_map_position:Vector2i = _get_random_tile_away_from(player_map_position)
	var i:Node2D = enemy_node.instantiate()
	add_child(i)
	i.position = self.map_to_local(spawn_map_position )+ Vector2(-32,-32)
	virtual_tile_map[spawn_map_position].grid_node = i
	

## Example of an arbitrary await

signal _async_test_completed # Step 1: define a signal
func _async_test() -> void:
	var has_emitted:bool = false # Step 2: track if we have emitted before we've reached the end of the function
	# Add logic as usual...
	for n in 100:
		print(n)
		
		## Step 3: Add condition to finish co-routine
		if n == 99:
			## Simulate long running process that we want to wait for...
			get_tree().create_timer(1).timeout.connect(
			func(): 
				_async_test_completed.emit() ## Step 4: Call the emit
				has_emitted = true
			)
			#_async_test_completed.emit()
			#has_emitted = true
		pass
	print("AWAITING")
	# We only want to await if we've reached the end of the function BEFORE our logic has finished processing.
	if has_emitted == false: await _async_test_completed ## Step 5: at the end of the method, conditionally await the emit
	print("PASSED")
	pass
