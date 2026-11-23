extends Node2D

## Floating damage, parry, and loot text popup.


func setup(text_val: String, color_val: Color, scale_mult: float = 1.0) -> void:
	var lbl: Label = $Label as Label
	lbl.text = text_val
	lbl.add_theme_color_override("font_color", color_val)
	scale = Vector2.ONE * scale_mult

	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:y", position.y - 18.0, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, 0.45).set_delay(0.22)
	tw.chain().tween_callback(queue_free)
