class_name PlayerNode extends Node2D

signal request_move(_direction:Vector2i)
signal explosion_request()

@export var explosion_node:PackedScene

var is_moving:bool = false


func _ready() -> void:
	add_to_group(&"Player", true)
	add_to_group(&"GridNodes")


func _unhandled_key_input(event: InputEvent) -> void:
	var x_axis:int = Input.get_axis("ui_left", "ui_right")
	var y_axis:int = Input.get_axis("ui_up", "ui_down")
	if is_moving == true: false
	if Vector2i(x_axis, y_axis) == Vector2i.ZERO: return
	request_move.emit(Vector2i(x_axis,y_axis))


func on_move_response(_new_position:Vector2, _requester:Node2D) -> void:
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
