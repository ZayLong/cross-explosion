extends Node2D

signal has_moved(direction:Vector2i)
signal move_request(_direction:Vector2i)
signal explosion_request()

@export var explosion_node:PackedScene

var is_moving:bool = false
var tile_map:TileMapLayer = get_parent()


func _ready() -> void:
	add_to_group(&"Player", true)
	add_to_group(&"GridNodes")
	has_moved.connect(_on_has_moved)
	get_parent().move_response.connect(_on_move_response)


func _unhandled_key_input(event: InputEvent) -> void:
	var x_axis:int = Input.get_axis("ui_left", "ui_right")
	var y_axis:int = Input.get_axis("ui_up", "ui_down")
	if is_moving == true: false
	if Vector2i(x_axis, y_axis) == Vector2i.ZERO: return
	move_request.emit(Vector2i(x_axis,y_axis))


func _on_has_moved() -> void:
	# Some animation stuff
	pass


func _on_move_response(_new_position:Vector2, _requester:Node2D) -> void:
	if _requester != self: return
	if _new_position == position: 
		is_moving = false
		return
	position = _new_position
	await _movement_tween()


func _movement_tween() -> void:
	var _t:Tween = create_tween()
	_t.tween_property(self.get_child(0),"scale:y",0.5,0.25).from(0.75).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	_t.parallel()
	_t.tween_property(self.get_child(0),"scale:x",0.5,0.5).from(0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	await _t.finished
