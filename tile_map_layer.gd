extends TileMapLayer


signal update_score(score:int)
#signal update_wave(wave:int)
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
var virtual_tile_map:Dictionary[Vector2i,VirtualTile]

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
var explosion_chain_chance:float = 0.30 # probability that an enemy will blow up and cause a chain reaction
var score_bonus:int = 1
var upgrade_discount:float = 1

var current_upgrades:Dictionary = {
	'explosion_pattern': explosion_pattern,
	'explosion_range': explosion_range,
	'explosion_interval': explosion_interval,
	'explosion_power': explosion_power,
	'explosion_chain': explosion_chain_chance,
	"score_bonus": score_bonus,
	"upgrade_discount": upgrade_discount,
	"steps_per_turn": steps_per_turn
}

func _ready() -> void:
	var my_seed:int = "Godot Rocks".hash()
	seed(my_seed)
	for cell in self.get_used_cells():
		var virtual_tilemap:VirtualTile = VirtualTile.new(null, self.map_to_local(cell), self.get_cell_tile_data(cell).get_custom_data(&"is_wall"), false, false, false)
		virtual_tile_map[cell] = virtual_tilemap
	for child in get_children():
		if child.is_in_group(&"GridNodes"):
			var map_pos:Vector2i = self.local_to_map(child.position)
			child.position = virtual_tile_map[map_pos].local
			virtual_tile_map[map_pos].grid_node = child
			if child.is_in_group(&"Walls"): virtual_tile_map[map_pos].is_wall = true
			if child.is_in_group(&"Hazards"): virtual_tile_map[map_pos].is_hazard = true
			if child.is_in_group(&"Enemies"): virtual_tile_map[map_pos].is_enemy = true
			if child.is_in_group(&"Player"):
				virtual_tile_map[map_pos].is_player = true
				child.request_move.connect(_on_request_move.bind(child))
				player_map_pos = map_pos
		if child is EntitySpawner: 
			child.request_spawn.connect(_on_request_spawn.bind(child))
			child.update_virtual_tile_map.connect(update_virtual_tile_map_entry)
	player = get_tree().get_first_node_in_group(&"Player")
	_astar_grid_setup()


func _on_request_spawn(entity_spawner:EntitySpawner) -> void:
	entity_spawner.spawn(player_map_pos,get_used_cells(),virtual_tile_map)


## Evaluate whether or not the requester can move and to where.
func _on_request_move(_direction:Vector2i, _node:Node2D) -> void:
	if is_processing_turn: return
	if _node.is_in_group(&"Player") == false: return
	
	var new_map_pos:Vector2i = player_map_pos + _direction
	if virtual_tile_map.has(new_map_pos) == false: return
	if virtual_tile_map[new_map_pos].is_wall: return
	is_processing_turn = true
	
	await _node.on_move_response(virtual_tile_map[new_map_pos].local, _node)
	if virtual_tile_map[new_map_pos].is_hazard || virtual_tile_map[new_map_pos].is_enemy:
		player_map_pos = new_map_pos
		await _hurt_player()
		await get_tree().create_timer(0.5).timeout
	move_virtual_tile_map_entry(player_map_pos, new_map_pos)
	player_map_pos = new_map_pos
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
			if _pattern == ExplosionPattern.DIAMOND: if abs(r - ((_explosion_range as float - 1)/2)) + abs(c - ((_explosion_range as float - 1)/2)) > ((_explosion_range as float - 1)/2): continue ## this makes a diamond pattern!
			_instance_explosion(cell)
			await _hurt_enemies(cell)
		if r == _explosion_range - 1:
			_instance_explosion(_center_coord)
			await _hurt_enemies(_center_coord)
			## Simulate some fancy explosion animation
			await get_tree().create_timer(0.15).timeout
			completed.emit()
			has_emitted = true


	explosion_interval = current_upgrades.explosion_interval
	is_exploding = false
	if has_emitted == false: await completed


func _hurt_enemies(cell:Vector2i) -> void:
	if virtual_tile_map.has(cell) == false: return
	if virtual_tile_map[cell].grid_node == null: return
	if virtual_tile_map[cell].is_enemy == false: return
	## await grid_node.hurt_animation
	if virtual_tile_map[cell].grid_node.is_queued_for_deletion() == false: 
		virtual_tile_map[cell].grid_node.queue_free()
		clear_virtual_tile_map_entry(cell)
		await _explode_enemies(cell)
	score += 1
	kill_count += 1
	update_score.emit(score)
	update_kill_count.emit(kill_count)


func _instance_explosion(cell:Vector2i) -> void:
	if explosion_node == null || explosion_node.can_instantiate() == false: return
	var instance = explosion_node.instantiate()
	instance.position = virtual_tile_map[cell].local
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
		if tile_data.get_custom_data('is_wall') == true: astar_grid.set_point_solid(cell, true)
		if virtual_tile_map.has(cell):
			if virtual_tile_map[cell].grid_node != null:
				if virtual_tile_map[cell].is_wall: astar_grid.set_point_solid(cell, true)


## Enemies have x change of exploding, creating a chain reaction
func _explode_enemies(cell:Vector2i) -> void:
	if randf() > explosion_chain_chance: return
	await _evaluate_explosion(cell, true)


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
		if enemy == null:continue
		var enemy_map_pos:Vector2i = self.local_to_map(enemy.position)
		var movement_points = astar_grid.get_point_path(enemy_map_pos, player_map_pos)
		if movement_points.size() < 2: continue
		var new_map_pos:Vector2i = self.local_to_map(movement_points[1])
		
		if virtual_tile_map.has(new_map_pos) == false: continue
		if virtual_tile_map[new_map_pos].grid_node != null:
			if virtual_tile_map[new_map_pos].is_enemy: continue
			if virtual_tile_map[new_map_pos].is_wall: continue
		if movement_points.size() > 1: enemy.global_position = movement_points[1]
		if virtual_tile_map[new_map_pos].is_player:
			await _hurt_player()
			continue
		if virtual_tile_map[new_map_pos].is_hazard: _hurt_enemies(enemy_map_pos)
		if virtual_tile_map[new_map_pos].is_player == false:
			move_virtual_tile_map_entry(enemy_map_pos,new_map_pos)

		await get_tree().create_timer(0.1).timeout	


func _hurt_player() -> void:
	lives -= 1
	update_lives.emit(lives)
	if lives >= 0:
		await _evaluate_explosion(player_map_pos, true)
	else:
		pass
	# some hurt feedback


func update_virtual_tile_map_entry(cell:Vector2i, props:Array[String], data_set:Array[Variant]) -> void:
	if virtual_tile_map.has(cell) == false: return

	if props.size() != data_set.size(): push_warning("update virtual_tilemap: props and data_set are different sizes.")
	var iterate:int = 0
	for prop in props:
		virtual_tile_map[cell][prop] = data_set[iterate]
		iterate += 1
	#virtual_tile_map[cell][prop] = data
	pass


func clear_virtual_tile_map_entry(cell:Vector2i) -> void:
	var local:Vector2 = virtual_tile_map[cell].local
	virtual_tile_map[cell] = VirtualTile.new()
	virtual_tile_map[cell].local = local
	pass


func move_virtual_tile_map_entry(from:Vector2i, to:Vector2i) -> void:
	for prop in virtual_tile_map[from].get_property_list():
		if prop.name != "local":
			virtual_tile_map[to].set(prop.name,virtual_tile_map[from].get(prop.name))
	clear_virtual_tile_map_entry(from)


class VirtualTile:
	var grid_node:Node2D
	var local:Vector2
	var is_wall:bool
	var is_hazard:bool
	var is_enemy:bool
	var is_player:bool
	func _init(_grid_node:Node2D = null, _local:Vector2 = Vector2(0,0), _is_wall:bool = false, _is_hazard:bool = false, _is_enemy:bool = false, _is_player:bool = false):
		grid_node = _grid_node
		local = _local
		is_wall = _is_wall
		is_hazard = _is_hazard
		is_enemy = _is_enemy
		is_player = _is_player
		pass
