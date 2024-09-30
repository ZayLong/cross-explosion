extends Node2D


func _ready() -> void:
	_explode_tween()


func _explode_tween() -> void:
	var _t:Tween = create_tween()
	_t.tween_property(self.get_child(0),"scale:y",0.5,0.25).from(0.75).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	_t.parallel()
	_t.tween_property(self.get_child(0),"scale:x",0.5,0.5).from(0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	await _t.finished
	queue_free()
