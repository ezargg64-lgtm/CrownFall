extends Area2D

## Exit gate at the south of BossArena returning to WildFrontier.

var _grace_timer: float = 0.55
var _triggered: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _grace_timer > 0.0:
		_grace_timer = maxf(0.0, _grace_timer - delta)


func get_prompt_text() -> String:
	return "[E] Exit to Wild Frontier"


func interact(_player: Node2D) -> void:
	if _triggered:
		return
	_triggered = true
	GameState.boss_hp_changed.emit(0, 350, false)
	GameState.request_zone_change("wild_frontier", "from_boss")


func _on_body_entered(body: Node2D) -> void:
	if _triggered or _grace_timer > 0.0:
		return
	if body.is_in_group("player"):
		_triggered = true
		GameState.boss_hp_changed.emit(0, 350, false)
		GameState.request_zone_change("wild_frontier", "from_boss")
