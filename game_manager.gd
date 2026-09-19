extends Node


signal health_changed(new_health: int, max_health: int)
signal score_updated(score: int, coins: int)
signal game_over
signal game_reset

const MAX_HEALTH: int = 5
const INVINCIBILITY_DURATION: float = 1.5

var health: int = MAX_HEALTH
var is_game_over: bool = false
var is_invincible: bool = false
var score: int = 0
var coins: int = 0
var checkpoint_position: Vector2 = Vector2.ZERO
var has_checkpoint: bool = false


func _ready() -> void:
	_setup_input_map()
	process_mode = Node.PROCESS_MODE_ALWAYS
	reset_game()


func _setup_input_map() -> void:
	_add_action_key(&"ui_left", KEY_A)
	_add_action_key(&"ui_right", KEY_D)
	_add_action_key(&"ui_up", KEY_W)
	_add_action_key(&"ui_accept", KEY_SPACE)


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


func add_coin(amount: int = 1, score_val: int = 10) -> void:
	coins += amount
	score += score_val
	score_updated.emit(score, coins)


func add_score(amount: int) -> void:
	score += amount
	score_updated.emit(score, coins)


func take_damage(amount: int = 1) -> void:
	if is_invincible or is_game_over:
		return

	health = max(0, health - amount)
	health_changed.emit(health, MAX_HEALTH)

	if health <= 0:
		trigger_game_over()
	else:
		_start_invincibility()


func heal(amount: int = 1) -> void:
	health = min(MAX_HEALTH, health + amount)
	health_changed.emit(health, MAX_HEALTH)


func set_checkpoint(pos: Vector2) -> void:
	checkpoint_position = pos
	has_checkpoint = true


func _start_invincibility() -> void:
	is_invincible = true
	await get_tree().create_timer(INVINCIBILITY_DURATION).timeout
	is_invincible = false


func trigger_game_over() -> void:
	if is_game_over:
		return
	is_game_over = true
	game_over.emit()


func reset_game() -> void:
	health = MAX_HEALTH
	is_game_over = false
	is_invincible = false
	score = 0
	coins = 0
	has_checkpoint = false
	checkpoint_position = Vector2.ZERO
	health_changed.emit(health, MAX_HEALTH)
	score_updated.emit(score, coins)
	game_reset.emit()
