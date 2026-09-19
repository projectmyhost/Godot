class_name Goal
extends Area2D

var _reached: bool = false
@onready var label: Label = $Label


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _reached:
		return
	if body is Player:
		_reached = true
		var gm: Node = get_node_or_null("/root/GameManager")
		if gm and gm.has_method("add_score"):
			gm.add_score(500)
		label.visible = true
