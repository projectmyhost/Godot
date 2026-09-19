class_name SpikeHazard
extends Area2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		var player: Player = body as Player
		player.take_damage(1)
