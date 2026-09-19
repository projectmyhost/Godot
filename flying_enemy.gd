class_name FlyingEnemy
extends Area2D

enum PatrolMode { VERTICAL_SINE, HORIZONTAL_PATROL, FIGURE_EIGHT }

@export var patrol_mode: PatrolMode = PatrolMode.VERTICAL_SINE
@export var move_speed: float = 80.0
@export var patrol_amplitude: float = 60.0
@export var patrol_frequency: float = 2.0
@export var move_direction: int = -1

var is_dead: bool = false
var _time: float = 0.0
var _start_position: Vector2

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var death_sound: AudioStreamPlayer2D = $DeathSound


func _ready() -> void:
	_start_position = global_position
	_time = randf() * TAU
	body_entered.connect(_on_body_entered)
	animated_sprite.play("subtle_motion")


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_time += delta

	match patrol_mode:
		PatrolMode.VERTICAL_SINE:
			global_position.x += move_speed * move_direction * delta
			global_position.y = _start_position.y + sin(_time * patrol_frequency) * patrol_amplitude

		PatrolMode.HORIZONTAL_PATROL:
			global_position.x = _start_position.x + sin(_time * patrol_frequency) * patrol_amplitude
			global_position.y += move_speed * move_direction * delta * 0.5

		PatrolMode.FIGURE_EIGHT:
			global_position.x = _start_position.x + sin(_time * patrol_frequency) * patrol_amplitude
			global_position.y = _start_position.y + sin(_time * patrol_frequency * 2.0) * patrol_amplitude * 0.6

	if patrol_mode != PatrolMode.VERTICAL_SINE:
		animated_sprite.flip_h = sin(_time * patrol_frequency) > 0
	else:
		animated_sprite.flip_h = move_direction > 0


func _on_body_entered(body: Node2D) -> void:
	if is_dead:
		return

	if body is Player:
		var player: Player = body as Player
		var gm: Node = get_node_or_null("/root/GameManager")
		if gm and (gm.is_invincible or gm.is_game_over):
			return

		if player.velocity.y > 0 and player.global_position.y < global_position.y - 5:
			player.velocity.y = -280.0
			die()
		else:
			player.take_damage(1)


func die() -> void:
	if is_dead:
		return
	is_dead = true
	death_sound.play()
	animated_sprite.play("subtle_motion")
	animated_sprite.modulate = Color.RED

	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	await get_tree().create_timer(0.5).timeout
	queue_free()
