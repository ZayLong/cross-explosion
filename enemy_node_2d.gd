class_name EnemyNode extends Node2D


var current_tile:TileData
var tile_size:int = 64
var is_moving:bool = false
var buffered_inputs:Array
var astar_grid:AStarGrid2D = AStarGrid2D.new()
var movement_points:PackedVector2Array
var allowed_moves:int = 1 ## How many squares are we allowed to move towards the player

func _ready() -> void:
	add_to_group(&"GridNodes")
	add_to_group(&"Enemies")


func _movement_tween() -> void:
	var _t:Tween = create_tween()
	_t.tween_property(self.get_child(0),"scale:y",0.5,0.25).from(0.75).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	_t.parallel()
	_t.tween_property(self.get_child(0),"scale:x",0.5,0.5).from(0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	await _t.finished


func _on_took_damage(_node:Node2D) -> void:
	if self != _node: return
	# hurt_animation
	pass
