extends Area2D

## Northern Boss Gate: locked with hint until Gatehouse is rebuilt, then transitions to BossArena.

var _grace_timer: float = 0.55
var _triggered: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _grace_timer > 0.0:
		_grace_timer = maxf(0.0, _grace_timer - delta)


func get_prompt_text() -> String:
	if bool(GameState.rebuilt_buildings.get("gatehouse", false)):
		return "[E] Enter Boss Arena (The Usurper)"
	return "[E] Sealed Boss Gate (Rebuild Gatehouse)"


func interact(_player: Node2D) -> void:
	if _triggered:
		return
	if bool(GameState.rebuilt_buildings.get("gatehouse", false)):
		_triggered = true
		GameState.request_zone_change("boss_arena", "default")
	else:
		AudioManager.play_ui_close()
		GameState.show_toast("Sealed! Rebuild The Gatehouse in KingdomHub to break the seal.")


func _on_body_entered(body: Node2D) -> void:
	if _triggered or _grace_timer > 0.0:
		return
	if not body.is_in_group("player"):
		return
	if bool(GameState.rebuilt_buildings.get("gatehouse", false)):
		_triggered = true
		GameState.request_zone_change("boss_arena", "default")
	else:
		GameState.show_toast("Sealed Boss Gate! Rebuild The Gatehouse (Captain Vance) first.")
