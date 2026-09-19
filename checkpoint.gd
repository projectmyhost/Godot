class_name Checkpoint
extends Area2D

var _activated: bool = false
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	animated_sprite.play("idle")


func _on_body_entered(body: Node2D) -> void:
	if _activated:
		return
	if body is Player:
		_activated = true
		var gm: Node = get_node_or_null("/root/GameManager")
		if gm and gm.has_method("set_checkpoint"):
			gm.set_checkpoint(global_position)
		animated_sprite.modulate = Color(0.4, 1.0, 0.4, 1.0)
