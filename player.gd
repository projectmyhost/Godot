class_name Player
extends CharacterBody2D


enum State { IDLE, RUN, JUMP, DOUBLE_JUMP, FALL, WALL_SLIDE, HIT, DASH }

@export var speed: float = 270.0
@export var jump_velocity: float = -520.0
@export var double_jump_velocity: float = -470.0
@export var wall_jump_vertical: float = -480.0
@export var wall_jump_horizontal: float = 320.0
@export var wall_slide_speed: float = 50.0
@export var acceleration: float = 1900.0
@export var friction: float = 1300.0
@export var coyote_time: float = 0.15
@export var jump_buffer_time: float = 0.15
@export var stomp_bounce_velocity: float = -340.0
@export var max_jumps: int = 2
@export var dash_speed: float = 540.0
@export var dash_duration: float = 0.16

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var current_state: State = State.IDLE
var _current_animation: String = ""
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _facing_right: bool = true
var _hit_blink_timer: float = 0.0
var _footstep_timer: float = 0.0
var _w_jump_queued: bool = false
var _jumps_left: int = 2
var _can_dash: bool = true
var _dash_timer: float = 0.0
var _dash_dir: float = 1.0
var _dash_cooldown: float = 0.0
var _dash_queued: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var jump_sound: AudioStreamPlayer2D = $JumpSound
@onready var hit_sound: AudioStreamPlayer2D = $HitSound
@onready var footstep_sound: AudioStreamPlayer2D = $FootstepSound
@onready var wall_detector_left: RayCast2D = $WallDetectorLeft
@onready var wall_detector_right: RayCast2D = $WallDetectorRight
@onready var start_position: Vector2 = global_position
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_setup_input_map()
	_jumps_left = max_jumps
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		gm.game_reset.connect(_on_game_reset)
		gm.game_over.connect(_on_game_over)
		if gm.has_checkpoint:
			global_position = gm.checkpoint_position


func _physics_process(delta: float) -> void:
	if _gm().is_game_over:
		return

	if current_state == State.HIT:
		_handle_hit_state(delta)
		return

	if current_state == State.DASH:
		_handle_dash_state(delta)
		return

	_update_timers(delta)
	_handle_dash_input()
	_apply_gravity(delta)

	var direction: float = _get_horizontal_axis()
	_handle_movement(direction, delta)
	_handle_jump()
	_handle_wall_slide(direction)

	move_and_slide()

	_update_state(direction)
	_update_animations(direction)
	_handle_footstep(direction, delta)

	if global_position.y > 750:
		take_damage(5)


func _update_timers(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = coyote_time
		_jumps_left = max_jumps
		_can_dash = true
	else:
		_coyote_timer = max(0.0, _coyote_timer - delta)

	if _jump_buffer_timer > 0.0:
		_jump_buffer_timer = max(0.0, _jump_buffer_timer - delta)

	if _dash_cooldown > 0.0:
		_dash_cooldown = max(0.0, _dash_cooldown - delta)


func _handle_dash_input() -> void:
	var pressed: bool = _dash_queued or Input.is_action_just_pressed("dash")
	_dash_queued = false
	if pressed and _can_dash and _dash_cooldown <= 0.0:
		_start_dash()


func _start_dash() -> void:
	_dash_timer = dash_duration
	_dash_cooldown = 0.5
	_can_dash = false
	current_state = State.DASH
	_dash_dir = 1.0 if _facing_right else -1.0
	velocity = Vector2(_dash_dir * dash_speed, 0.0)
	jump_sound.pitch_scale = 1.6
	jump_sound.play()
	animated_sprite.modulate = Color(1.6, 1.6, 2.2, 0.8)


func _handle_dash_state(delta: float) -> void:
	_dash_timer -= delta
	velocity = Vector2(_dash_dir * dash_speed, 0.0)
	move_and_slide()
	if _dash_timer <= 0.0:
		animated_sprite.modulate = Color.WHITE
		current_state = State.FALL if not is_on_floor() else State.IDLE


func _apply_gravity(delta: float) -> void:
	if current_state == State.WALL_SLIDE:
		velocity.y = min(velocity.y + gravity * 0.25 * delta, wall_slide_speed)
	elif not is_on_floor():
		velocity.y += gravity * delta
		if velocity.y < -150.0 and not _is_jump_held():
			velocity.y += gravity * 0.45 * delta


func _handle_movement(direction: float, delta: float) -> void:
	if direction != 0:
		velocity.x = move_toward(velocity.x, direction * speed, acceleration * delta)
		_facing_right = direction > 0
	else:
		velocity.x = move_toward(velocity.x, 0, friction * delta)


func _handle_jump() -> void:
	var jump_pressed: bool = _is_jump_just_pressed()
	if jump_pressed:
		_jump_buffer_timer = jump_buffer_time

	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		_perform_jump(jump_velocity)
		_coyote_timer = 0.0
		_jump_buffer_timer = 0.0
		_jumps_left = max_jumps - 1
		return

	if _jump_buffer_timer > 0.0 and current_state == State.WALL_SLIDE:
		_perform_wall_jump()
		_jump_buffer_timer = 0.0
		_jumps_left = 1
		return

	if _jump_buffer_timer > 0.0 and _jumps_left > 0:
		_perform_double_jump()
		_jump_buffer_timer = 0.0
		_jumps_left -= 1
		return


func _perform_jump(vel_y: float) -> void:
	velocity.y = vel_y
	jump_sound.pitch_scale = 1.0
	jump_sound.play()
	current_state = State.JUMP


func _perform_double_jump() -> void:
	velocity.y = double_jump_velocity
	jump_sound.pitch_scale = 1.35
	jump_sound.play()
	current_state = State.DOUBLE_JUMP
	_current_animation = "double_jump"
	animated_sprite.play("double_jump")


func _perform_wall_jump() -> void:
	var wall_dir: float = -1.0 if _is_touching_left_wall() else 1.0
	velocity.y = wall_jump_vertical
	velocity.x = wall_dir * wall_jump_horizontal
	_facing_right = wall_dir > 0
	jump_sound.pitch_scale = 1.15
	jump_sound.play()
	current_state = State.JUMP


func _handle_wall_slide(direction: float) -> void:
	if is_on_floor():
		return
	var touching_left: bool = _is_touching_left_wall() and direction < 0
	var touching_right: bool = _is_touching_right_wall() and direction > 0
	if (touching_left or touching_right) and velocity.y > 0:
		current_state = State.WALL_SLIDE
		_jumps_left = 1


func _is_touching_left_wall() -> bool:
	return is_on_wall() and wall_detector_left.is_colliding()


func _is_touching_right_wall() -> bool:
	return is_on_wall() and wall_detector_right.is_colliding()


func _update_state(_direction: float) -> void:
	if current_state == State.HIT or current_state == State.DASH:
		return
	if current_state == State.WALL_SLIDE:
		if is_on_floor():
			current_state = State.IDLE
		elif not is_on_wall():
			current_state = State.FALL
		return
	if current_state == State.DOUBLE_JUMP:
		if velocity.y > 0:
			current_state = State.FALL
		elif is_on_floor():
			current_state = State.IDLE
		return
	if not is_on_floor():
		current_state = State.JUMP if velocity.y < 0 else State.FALL
	else:
		current_state = State.RUN if abs(velocity.x) > 10 else State.IDLE


func _update_animations(_direction: float) -> void:
	var next_anim: String
	match current_state:
		State.IDLE: next_anim = "idle"
		State.RUN: next_anim = "run"
		State.JUMP: next_anim = "jump"
		State.DOUBLE_JUMP: next_anim = "double_jump"
		State.WALL_SLIDE: next_anim = "wall_jump"
		State.DASH: next_anim = "run"
		State.FALL, State.HIT: next_anim = "fall"

	animated_sprite.flip_h = not _facing_right

	if next_anim != _current_animation:
		_current_animation = next_anim
		animated_sprite.play(next_anim)


func _handle_footstep(_direction: float, delta: float) -> void:
	if current_state == State.RUN and is_on_floor():
		_footstep_timer -= delta
		if _footstep_timer <= 0:
			_footstep_timer = 0.28
			footstep_sound.play()
	else:
		_footstep_timer = 0.0


func _handle_hit_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, friction * delta)
	if not is_on_floor():
		velocity.y += gravity * delta
	move_and_slide()

	_hit_blink_timer -= delta
	if _hit_blink_timer <= 0:
		current_state = State.IDLE
		animated_sprite.modulate = Color.WHITE
		collision_shape.disabled = false
		return

	animated_sprite.modulate.a = 0.3 + 0.7 * abs(sin(_hit_blink_timer * 12.0))


func take_damage(amount: int = 1) -> void:
	if _gm().is_invincible or _gm().is_game_over:
		return

	_gm().take_damage(amount)
	if _gm().is_game_over:
		return

	current_state = State.HIT
	_hit_blink_timer = _gm().INVINCIBILITY_DURATION
	hit_sound.play()

	var knockback_dir: float = -1.0 if _facing_right else 1.0
	velocity = Vector2(knockback_dir * 200.0, -150.0)


func die() -> void:
	take_damage(1)


func _on_game_reset() -> void:
	if _gm().has_checkpoint:
		global_position = _gm().checkpoint_position
	else:
		global_position = start_position
	velocity = Vector2.ZERO
	current_state = State.IDLE
	_current_animation = ""
	_jumps_left = max_jumps
	_can_dash = true
	_dash_timer = 0.0
	animated_sprite.modulate = Color.WHITE
	collision_shape.disabled = false
	animated_sprite.play("idle")


func _gm() -> Node:
	return get_node_or_null("/root/GameManager")


func _on_game_over() -> void:
	velocity = Vector2.ZERO
	current_state = State.IDLE
	animated_sprite.play("idle")


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_ev: InputEventKey = event as InputEventKey
		if (key_ev.keycode == KEY_W or key_ev.physical_keycode == KEY_W) and key_ev.is_pressed() and not key_ev.is_echo():
			_w_jump_queued = true
		if (key_ev.keycode == KEY_SHIFT or key_ev.physical_keycode == KEY_SHIFT or key_ev.keycode == KEY_J or key_ev.keycode == KEY_C) and key_ev.is_pressed() and not key_ev.is_echo():
			_dash_queued = true


func _get_horizontal_axis() -> float:
	var dir: float = Input.get_axis("ui_left", "ui_right")
	if dir == 0.0:
		if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_A):
			dir -= 1.0
		if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_D):
			dir += 1.0
	return clampf(dir, -1.0, 1.0)


func _is_jump_just_pressed() -> bool:
	var pressed: bool = Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up") or _w_jump_queued
	_w_jump_queued = false
	return pressed


func _is_jump_held() -> bool:
	return Input.is_action_pressed("ui_accept") or Input.is_action_pressed("ui_up") or Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_W)


func _setup_input_map() -> void:
	_add_action_key(&"ui_left", KEY_A)
	_add_action_key(&"ui_right", KEY_D)
	_add_action_key(&"ui_up", KEY_W)
	_add_action_key(&"ui_accept", KEY_SPACE)
	_add_action_key(&"dash", KEY_SHIFT)
	_add_action_key(&"dash", KEY_J)
	_add_action_key(&"dash", KEY_C)


func _add_action_key(action: StringName, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev_phys: InputEventKey = InputEventKey.new()
	ev_phys.physical_keycode = key
	if not InputMap.action_has_event(action, ev_phys):
		InputMap.action_add_event(action, ev_phys)
	var ev_key: InputEventKey = InputEventKey.new()
	ev_key.keycode = key
	if not InputMap.action_has_event(action, ev_key):
		InputMap.action_add_event(action, ev_key)
