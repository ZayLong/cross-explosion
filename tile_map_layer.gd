extends TileMapLayer

signal move_response(_new_position:Vector2, _requester:Node2D)
enum ExplosionPattern {CROSS, SQUARE, DIAMOND, PATCH}

@export var explosion_node:PackedScene
@export var starting_position:Vector2i = Vector2i.ONE

var grid_nodes:Dictionary
var virtual_tile_map:Dictionary
var explosion_interval:int = 3


func _ready() -> void:
	for cell in self.get_used_cells():
		virtual_tile_map[cell] = {
			"grid_node": null,
			"is_wall": get_cell_tile_data(cell).get_custom_data("is_wall"),
			"explosion_interval": 3
		}
	for child in get_children():
		if child.is_in_group(&"GridNodes"):
			child.move_request.connect(_on_move_request.bind(child))
			var center_coord:Vector2i = self.local_to_map(child.position)
			if child.is_in_group(&"Player"): 
				center_coord = starting_position
				child.position = self.map_to_local(center_coord)
			virtual_tile_map[center_coord].grid_node = child
	pass


func _on_move_request(_direction:Vector2i, _node:Node2D):
	var center_coord:Vector2i = self.local_to_map(_node.position)
	var new_center_coord:Vector2i = center_coord + _direction
	
	if virtual_tile_map.has(new_center_coord) == false: return 
	if virtual_tile_map[new_center_coord].grid_node != null: return
	if virtual_tile_map[new_center_coord].is_wall: return
	
	virtual_tile_map[new_center_coord] = virtual_tile_map[center_coord].duplicate()
	virtual_tile_map[center_coord].grid_node = null
	if _node.is_in_group("Player"):
		_evaluate_explosion(new_center_coord)
	move_response.emit(self.map_to_local(new_center_coord), _node)


func _evaluate_explosion(_center_coord:Vector2i, _pattern:ExplosionPattern = ExplosionPattern.SQUARE, _explosion_range:int = 3) -> void:
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
	virtual_tile_map[_center_coord].explosion_interval = 3


func _hurt_enemies(cell) -> void:
	if virtual_tile_map.has(cell) == false: return
	if virtual_tile_map[cell].grid_node == null: return
	if virtual_tile_map[cell].grid_node.is_in_group("Enemies") == false: return
	virtual_tile_map[cell].grid_node.queue_free()


func _instance_explosion(cell:Vector2i) -> void:
	if explosion_node == null || explosion_node.can_instantiate() == false: return
	var instance = explosion_node.instantiate()
	instance.position = map_to_local(cell)
	get_tree().root.add_child(instance)


func _is_cell_empty() -> void:
	pass


func _on_gridnode_spawned() -> void:
	pass

func _on_gridnode_despawned() -> void:
	pass
