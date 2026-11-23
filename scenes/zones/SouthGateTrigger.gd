extends Area2D

## Gate trigger returning from WildFrontier to KingdomHub (supports walk-through after grace timer or [E]).

var _grace_timer: float = 0.55
var _triggered: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _grace_timer > 0.0:
		_grace_timer = maxf(0.0, _grace_timer - delta)


func get_prompt_text() -> String:
	return "[E] Return to Kingdom Hub"


func interact(_player: Node2D) -> void:
	if _triggered:
		return
	_triggered = true
	GameState.request_zone_change("kingdom_hub", "from_north")


func _on_body_entered(body: Node2D) -> void:
	if _triggered or _grace_timer > 0.0:
		return
	if body.is_in_group("player"):
		_triggered = true
		GameState.request_zone_change("kingdom_hub", "from_north")
