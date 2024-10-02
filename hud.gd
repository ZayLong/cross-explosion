extends PanelContainer
@export var tile_map:TileMapLayer
@export var score_label:Label
@export var lives_label:Label
@export var wave_label:Label
@export var kill_count_label:Label

func _ready() -> void:
	if tile_map == null: return
	tile_map.update_score.connect(_on_updated_score)
	tile_map.update_lives.connect(_on_updated_lives)
	tile_map.update_wave.connect(_on_updated_wave)
	tile_map.update_kill_count.connect(_on_updated_kill_count)


func _on_updated_score(score:int) -> void:
	if score_label: score_label.text = str("SCORE: ",score)
	pass

func _on_updated_lives(lives:int) -> void:
	if lives_label: lives_label.text = str("LIVES: ", lives)
	pass

func _on_updated_wave(wave:int) -> void:
	if wave_label: wave_label.text = str("WAVE: ",wave)
	pass

func _on_updated_kill_count(kill_count:int) -> void:
	if kill_count_label: kill_count_label.text = str("KILLS: ",kill_count)
	pass
