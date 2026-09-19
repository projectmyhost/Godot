class_name GameUI
extends CanvasLayer

const HEART_SIZE: int = 32
const HEART_SPACING: int = 6

@onready var hearts_container: HBoxContainer = $HUD/HeartsContainer
@onready var coin_label: Label = $HUD/ScorePanel/HBoxContainer/CoinContainer/CoinLabel
@onready var score_label: Label = $HUD/ScorePanel/HBoxContainer/ScoreLabel
@onready var game_over_overlay: ColorRect = $GameOver
@onready var game_over_panel: Panel = $GameOver/Panel
@onready var game_over_stats: Label = $GameOver/Panel/VBoxContainer/StatsLabel
@onready var restart_button: Button = $GameOver/Panel/VBoxContainer/RestartButton

var _heart_textures: Array[TextureRect] = []
var _can_restart: bool = false


func _gm() -> Node:
	return get_node_or_null("/root/GameManager")


func _ready() -> void:
	var gm: Node = _gm()
	if gm:
		gm.health_changed.connect(_on_health_changed)
		gm.score_updated.connect(_on_score_updated)
		gm.game_over.connect(_on_game_over)
		gm.game_reset.connect(_on_game_reset)

	_create_hearts()
	_update_hearts(gm.MAX_HEALTH if gm else 5)
	_on_score_updated(gm.score if gm else 0, gm.coins if gm else 0)
	game_over_overlay.visible = false
	restart_button.pressed.connect(_on_restart_pressed)


func _create_hearts() -> void:
	for child: Node in hearts_container.get_children():
		child.queue_free()
	_heart_textures.clear()

	var max_hp: int = _gm().MAX_HEALTH if _gm() else 5
	var heart_tex: Texture2D = load("res://assets/generated/heart_icon_frame_0.png")
	for i: int in range(max_hp):
		var heart: TextureRect = TextureRect.new()
		heart.texture = heart_tex
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heart.custom_minimum_size = Vector2(HEART_SIZE, HEART_SIZE)
		hearts_container.add_child(heart)
		_heart_textures.append(heart)


func _update_hearts(current: int) -> void:
	for i: int in range(_heart_textures.size()):
		if i < current:
			_heart_textures[i].modulate = Color.WHITE
		else:
			_heart_textures[i].modulate = Color(0.2, 0.2, 0.2, 1.0)


func _on_health_changed(new_health: int, _max_health: int) -> void:
	_update_hearts(new_health)


func _on_score_updated(new_score: int, new_coins: int) -> void:
	if score_label:
		score_label.text = "SKOR: %d" % new_score
	if coin_label:
		coin_label.text = "x %d" % new_coins


func _on_game_over() -> void:
	var gm: Node = _gm()
	if game_over_stats:
		game_over_stats.text = "Skor: %d  |  Koin: %d" % [gm.score if gm else 0, gm.coins if gm else 0]
	game_over_overlay.visible = true
	_can_restart = false
	await get_tree().create_timer(0.5).timeout
	_can_restart = true


func _on_game_reset() -> void:
	game_over_overlay.visible = false
	_can_restart = false
	var gm: Node = _gm()
	_update_hearts(gm.MAX_HEALTH if gm else 5)
	_on_score_updated(gm.score if gm else 0, gm.coins if gm else 0)


func _process(_delta: float) -> void:
	if not game_over_overlay.visible or not _can_restart:
		return
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up"):
		_do_restart()
		return
	if Input.is_action_just_pressed("ui_left") or Input.is_action_just_pressed("ui_right"):
		_do_restart()
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_do_restart()
		return


func _do_restart() -> void:
	if not _can_restart:
		return
	_can_restart = false
	var gm: Node = _gm()
	if gm:
		gm.reset_game()
	get_tree().call_deferred("reload_current_scene")


func _on_restart_pressed() -> void:
	_do_restart()
