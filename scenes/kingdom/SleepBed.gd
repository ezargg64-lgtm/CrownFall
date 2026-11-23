extends Node2D

## Royal sleeping cot inside/beside the Ruined Hall that advances the day overnight.


func get_prompt_text() -> String:
	return "[E] Sleep (Next Day)"


func interact(_player: Node2D) -> void:
	GameState.request_sleep()
