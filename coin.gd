class_name Coin
extends Area2D

@export var coin_value: int = 1
@export var score_value: int = 10

var _is_collected: bool = false
var _start_y: float = 0.0
var _time: float = 0.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collect_sound: AudioStreamPlayer2D = $CollectSound


func _ready() -> void:
	_start_y = position.y
	_time = randf() * TAU
	body_entered.connect(_on_body_entered)
	animated_sprite.play("spin")


func _process(delta: float) -> void:
	if _is_collected:
		return
	_time += delta
	position.y = _start_y + sin(_time * 3.5) * 3.5


func _on_body_entered(body: Node2D) -> void:
	if _is_collected:
		return

	if body is Player:
		_is_collected = true
		set_deferred("monitoring", false)
		var gm: Node = get_node_or_null("/root/GameManager")
		if gm and gm.has_method("add_coin"):
			gm.add_coin(coin_value, score_value)

		collect_sound.pitch_scale = randf_range(1.0, 1.25)
		collect_sound.play()
		animated_sprite.play("collected")
		await get_tree().create_timer(0.4).timeout
		queue_free()
