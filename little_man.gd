class_name LittleMan
extends CharacterBody2D

signal little_man_died

@export var move_speed: float = 55.0
@export var move_direction: int = -1

var is_dead: bool = false
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _turn_timer: float = 0.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var death_sound: AudioStreamPlayer2D = $DeathSound
@onready var floor_detector: RayCast2D = $FloorDetector
@onready var hitbox: Area2D = $Hitbox
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	animated_sprite.play("walk")
	_update_direction_visuals()
	hitbox.body_entered.connect(_on_hitbox_body_entered)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0

	velocity.x = move_speed * move_direction
	move_and_slide()

	if _turn_timer > 0.0:
		_turn_timer = max(0.0, _turn_timer - delta)
		return

	if is_on_wall():
		_turn_around()
		return

	if is_on_floor() and not floor_detector.is_colliding():
		_turn_around()


func _turn_around() -> void:
	move_direction *= -1
	_turn_timer = 0.3
	_update_direction_visuals()


func _update_direction_visuals() -> void:
	animated_sprite.flip_h = move_direction > 0
	if floor_detector:
		floor_detector.position.x = 12.0 * move_direction
		floor_detector.force_raycast_update()


func _on_hitbox_body_entered(body: Node2D) -> void:
	if is_dead:
		return

	if body is Player:
		var player: Player = body as Player
		var gm: Node = get_node_or_null("/root/GameManager")
		if gm and (gm.is_invincible or gm.is_game_over):
			return

		if player.velocity.y > 0.0 and player.global_position.y < global_position.y - 4.0:
			player.velocity.y = -340.0
			die()
		else:
			player.take_damage(1)


func die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	if hitbox:
		hitbox.set_deferred("monitoring", false)
		hitbox.set_deferred("monitorable", false)

	death_sound.play()
	animated_sprite.play("hit")
	little_man_died.emit()

	var gm: Node = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("add_score"):
		gm.add_score(150)

	await get_tree().create_timer(0.4).timeout
	queue_free()
