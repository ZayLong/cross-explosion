extends Node2D

signal has_moved(direction:Vector2i)
signal move_request(_direction:Vector2i)
signal explosion_request()

@export var explosion_node:PackedScene

var tile_size:int = 64
var is_moving:bool = false
var explosion_interval:int = 3
var tile_map:TileMapLayer = get_parent()

func _ready() -> void:
	add_to_group("Player", true)
	add_to_group("GridNodes")
	has_moved.connect(_on_has_moved)
	get_parent().move_response.connect(_on_move_response)


func _unhandled_key_input(event: InputEvent) -> void:
	var x_axis:int = Input.get_axis("ui_left", "ui_right")
	var y_axis:int = Input.get_axis("ui_up", "ui_down")
	if is_moving == true: false
	if Vector2i(x_axis, y_axis) == Vector2i.ZERO: return
	move_request.emit(Vector2i(x_axis,y_axis))
	#if x_axis != 0:
		#if _is_tile_solid(Vector2(global_position.x + tile_size * x_axis, global_position.y)):
			#return
		#move_request.emit(Vector2i(x_axis,y_axis))
		#is_moving = true
		#return
	#if y_axis != 0:
		#if _is_tile_solid(Vector2(global_position.x, global_position.y + tile_size * y_axis)):
			#return
		#move_request.emit(Vector2i(x_axis,y_axis))
		#is_moving = true


func _generate_explosion_nodes() -> void:

	var instance_count:int = 4
	var range:int = 1
	var positions:PackedVector2Array = [
	(Vector2.LEFT * tile_size),
	(Vector2.RIGHT * tile_size),
	(Vector2.UP * tile_size),
	(Vector2.DOWN * tile_size),
	
	((Vector2.LEFT + Vector2.UP )* tile_size),
	((Vector2.RIGHT + Vector2.UP )* tile_size),
	((Vector2.RIGHT + Vector2.DOWN )* tile_size),
	((Vector2.LEFT + Vector2.DOWN )* tile_size),
	]
	
	for i in range(0,instance_count):
		for r in range:
			var instance = explosion_node.instantiate()
			instance.position = position + positions[i] * (r + 1)
			get_tree().root.add_child(instance)
		pass
	pass


func _on_has_moved() -> void:
	pass


func _on_move_response(_new_position:Vector2, _requester:Node2D) -> void:
	if _requester != self: return
	if _new_position == position: 
		is_moving = false
		return
	position = _new_position
	_check_explosion()
	await _movement_tween()
	pass


func _check_explosion() -> void:
	if explosion_interval <= 0:
		#_generate_explosion_nodes()
		explosion_request.emit()
		explosion_interval = 3
	else:
		explosion_interval -= 1


func _movement_tween() -> void:
	var _t:Tween = create_tween()
	_t.tween_property(self.get_child(0),"scale:y",0.5,0.25).from(0.75).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	_t.parallel()
	_t.tween_property(self.get_child(0),"scale:x",0.5,0.5).from(0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	await _t.finished


func _is_tile_solid(_position:Vector2) -> bool:
	var _tile_map:TileMapLayer = get_parent()
	var _tile_data:TileData = _tile_map.get_cell_tile_data(_tile_map.local_to_map(_position))
	if _tile_data == null: return false
	if _tile_data.get_custom_data("is_wall") == true:
		return true
	return false
