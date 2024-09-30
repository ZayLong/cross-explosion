extends Node2D

signal has_moved(direction:Vector2i)
signal move_request(_direction:Vector2i)

var current_tile:TileData
var tile_size:int = 64
var is_moving:bool = false
var buffered_inputs:Array
var astar_grid:AStarGrid2D = AStarGrid2D.new()
var movement_points:PackedVector2Array
var allowed_moves:int = 1 ## How many squares are we allowed to move towards the player

func _ready() -> void:
	_spawn_position()
	add_to_group("GridNodes")
	add_to_group("Enemies")


func _spawn_position() -> void:
	global_position = Vector2(5,5) * 64
	pass


func _movement_tween() -> void:
	var _t:Tween = create_tween()
	_t.tween_property(self.get_child(0),"scale:y",0.5,0.25).from(0.75).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	_t.parallel()
	_t.tween_property(self.get_child(0),"scale:x",0.5,0.5).from(0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	await _t.finished


func _is_tile_solid(_position:Vector2) -> bool:
	var _tile_map:TileMapLayer = get_parent()
	var _tile_data:TileData = _tile_map.get_cell_tile_data(_tile_map.local_to_map(_position))
	if _tile_data.get_custom_data("is_wall") == true:
		return true
	return false


func _astar_grid_setup() -> void:
	var tile_map:TileMapLayer = get_parent()
	var cell_size = tile_map.tile_set.tile_size
	var tile_map_rect:Rect2i = tile_map.get_used_rect()
	
	astar_grid.region = tile_map_rect
	astar_grid.cell_size = cell_size
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar_grid.update()
	for cell in tile_map.get_used_cells():
		var tile_data:TileData = tile_map.get_cell_tile_data(cell)
		if tile_data.get_custom_data('is_wall') == true:
			astar_grid.set_point_solid(cell, true)

	var our_pos:Vector2i = tile_map.local_to_map(position)
	var player_position:Vector2i = tile_map.local_to_map(get_tree().get_first_node_in_group("Player").position)

	movement_points = astar_grid.get_point_path(our_pos, player_position) 
	if movement_points.size() > 1: global_position = movement_points[1]
	await _movement_tween()
