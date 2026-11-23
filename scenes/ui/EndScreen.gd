extends Control

## Unified Keyboard + Gamepad navigable Title, Intro, Pause, and Victory overlay.

signal start_new_game_requested
signal resume_requested
signal continue_after_victory_requested
signal replay_requested
signal return_to_title_requested

enum Mode { HIDDEN, TITLE, INTRO, PAUSE, VICTORY }

@onready var title_label: Label = $CenterContainer/Panel/VBox/TitleLabel
@onready var subtitle_label: Label = $CenterContainer/Panel/VBox/SubtitleLabel
@onready var body_label: Label = $CenterContainer/Panel/VBox/BodyLabel
@onready var controls_card: PanelContainer = $CenterContainer/Panel/VBox/ControlsCard
@onready var buttons_vbox: VBoxContainer = $CenterContainer/Panel/VBox/ButtonsVBox
@onready var footer_hint: Label = $CenterContainer/Panel/VBox/FooterHint

var _mode: Mode = Mode.HIDDEN
var _buttons: Array[Button] = []
var _last_focus_idx: int = 0
var _input_lock_timer: float = 0.0
var _showing_controls: bool = false

var _style_normal: StyleBoxFlat
var _style_focus: StyleBoxFlat
var _style_pressed: StyleBoxFlat


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_init_styles()


func _process(delta: float) -> void:
	if visible and _input_lock_timer > 0.0:
		_input_lock_timer = maxf(0.0, _input_lock_timer - delta)


func _input(event: InputEvent) -> void:
	if not visible or _input_lock_timer > 0.0:
		return

	if _mode == Mode.PAUSE and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		if _showing_controls:
			_showing_controls = false
			controls_card.visible = false
			AudioManager.play_ui_close()
		else:
			_on_resume()
		return

	if _mode == Mode.TITLE and _showing_controls and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_showing_controls = false
		controls_card.visible = false
		AudioManager.play_ui_close()
		return

	if event.is_action_pressed("move_up") and not event.is_action_pressed("ui_up"):
		get_viewport().set_input_as_handled()
		_step_focus(-1)
		return

	if event.is_action_pressed("move_down") and not event.is_action_pressed("ui_down"):
		get_viewport().set_input_as_handled()
		_step_focus(1)
		return

	if event.is_action_pressed("interact") and not event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		var focused: Control = get_viewport().gui_get_focus_owner()
		if focused is Button:
			(focused as Button).emit_signal("pressed")


func is_open() -> bool:
	return _mode != Mode.HIDDEN


func show_title() -> void:
	_mode = Mode.TITLE
	_showing_controls = false
	_input_lock_timer = 0.14
	get_tree().paused = true
	GameState.is_ui_open = true
	visible = true

	title_label.text = "CROWNFALL: THE HUMBLED KING"
	title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.38, 1.0))
	subtitle_label.text = "Rebuild the ruined village. Bounce back the Usurper."
	body_label.visible = false
	controls_card.visible = true
	_showing_controls = true
	footer_hint.text = "[Up/Down/Stick] Navigate  •  [Enter/E/A] Select"

	_clear_buttons()
	_add_button("Play", func() -> void:
		AudioManager.play_ui_confirm()
		show_intro()
	)
	_add_button("Toggle Controls", func() -> void:
		_showing_controls = not _showing_controls
		controls_card.visible = _showing_controls
		AudioManager.play_ui_move()
	)
	_finalize_buttons()


func show_intro() -> void:
	_mode = Mode.INTRO
	_showing_controls = false
	_input_lock_timer = 0.18
	get_tree().paused = true
	GameState.is_ui_open = true
	visible = true

	title_label.text = "THE FALL OF THE CROWN"
	title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.42, 1.0))
	subtitle_label.text = "Day 1 — The Ruined Border Village"
	body_label.visible = true
	body_label.text = (
		"In a single night, the Usurper shattered your crown and cast you into a wrecked border village with only a rusty sword and a cracked shield.\n\n"
		+ "Instead of rushing blindly back into battle, tend the soil, welcome your people home, and rebuild the realm one ruin at a time.\n\n"
		+ "When you are ready, raise your shield — and bounce the Usurper's dark magic right back in his face."
	)
	controls_card.visible = false
	footer_hint.text = "[Enter / E / A] Begin Your Comeback"

	_clear_buttons()
	_add_button("Begin Your Comeback", func() -> void:
		AudioManager.play_ui_confirm()
		_close_overlay()
		start_new_game_requested.emit()
	)
	_finalize_buttons()


func show_pause() -> void:
	_mode = Mode.PAUSE
	_showing_controls = false
	_input_lock_timer = 0.14
	get_tree().paused = true
	GameState.is_ui_open = true
	visible = true
	AudioManager.play_ui_open()

	title_label.text = "PAUSED"
	title_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.82, 1.0))
	subtitle_label.text = "Day %d • Kingdom %d/4" % [GameState.day_number, GameState.kingdom_level]
	body_label.visible = false
	controls_card.visible = false
	footer_hint.text = "[Esc / Start / B] Resume  •  [Enter / E / A] Select"

	_clear_buttons()
	_add_button("Resume", func() -> void: _on_resume())
	_add_button("Controls", func() -> void:
		_showing_controls = not _showing_controls
		controls_card.visible = _showing_controls
		AudioManager.play_ui_move()
	)
	_add_button("Return to Title", func() -> void:
		AudioManager.play_ui_close()
		_close_overlay()
		return_to_title_requested.emit()
	)
	_finalize_buttons()


func show_victory() -> void:
	_mode = Mode.VICTORY
	_showing_controls = false
	_input_lock_timer = 0.25
	get_tree().paused = true
	GameState.is_ui_open = true
	visible = true
	AudioManager.play_rebuild()

	title_label.text = "THE KINGDOM BOUNCED BACK!"
	title_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.35, 1.0))
	subtitle_label.text = "The Usurper has fallen. Your crown is restored!"
	body_label.visible = true
	body_label.text = (
		"Days Taken: %d\n" % GameState.day_number
		+ "Crops Harvested: %d\n" % GameState.total_crops_harvested
		+ "Projectiles Bounced: %d\n" % GameState.total_projectiles_bounced
		+ "Kingdom Rebuilt: %d / 4" % GameState.kingdom_level
	)
	controls_card.visible = false
	footer_hint.text = "[Up/Down/Stick] Select  •  [Enter/E/A] Confirm"

	_clear_buttons()
	_add_button("Continue Playing", func() -> void:
		AudioManager.play_ui_confirm()
		_close_overlay()
		continue_after_victory_requested.emit()
	)
	_add_button("Replay", func() -> void:
		AudioManager.play_ui_confirm()
		_close_overlay()
		replay_requested.emit()
	)
	_finalize_buttons()


func _on_resume() -> void:
	AudioManager.play_ui_close()
	_close_overlay()
	resume_requested.emit()


func _close_overlay() -> void:
	_mode = Mode.HIDDEN
	visible = false
	get_tree().paused = false
	await get_tree().process_frame
	GameState.is_ui_open = false


func _clear_buttons() -> void:
	for child: Node in buttons_vbox.get_children():
		buttons_vbox.remove_child(child)
		child.queue_free()
	_buttons.clear()
	_last_focus_idx = 0


func _add_button(label_text: String, callback: Callable) -> void:
	var btn := Button.new()
	var idx: int = _buttons.size()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(0, 20)
	btn.focus_mode = Control.FOCUS_ALL
	btn.add_theme_font_size_override("font_size", 7)
	btn.add_theme_stylebox_override("normal", _style_normal)
	btn.add_theme_stylebox_override("hover", _style_focus)
	btn.add_theme_stylebox_override("focus", _style_focus)
	btn.add_theme_stylebox_override("pressed", _style_pressed)
	btn.add_theme_color_override("font_color", Color(0.95, 0.94, 0.9, 1.0))
	btn.add_theme_color_override("font_focus_color", Color(1.0, 0.92, 0.42, 1.0))

	btn.focus_entered.connect(func() -> void:
		_last_focus_idx = idx
		AudioManager.play_ui_move()
	)
	btn.pressed.connect(func() -> void:
		_last_focus_idx = idx
		callback.call()
	)

	buttons_vbox.add_child(btn)
	_buttons.append(btn)


func _finalize_buttons() -> void:
	var count: int = _buttons.size()
	if count == 0:
		return
	for i: int in range(count):
		var prev_btn: Button = _buttons[(i - 1 + count) % count]
		var next_btn: Button = _buttons[(i + 1) % count]
		_buttons[i].focus_neighbor_top = _buttons[i].get_path_to(prev_btn)
		_buttons[i].focus_neighbor_bottom = _buttons[i].get_path_to(next_btn)
	_buttons[0].call_deferred("grab_focus")


func _step_focus(dir: int) -> void:
	if _buttons.is_empty():
		return
	var next_idx: int = (_last_focus_idx + dir + _buttons.size()) % _buttons.size()
	_buttons[next_idx].grab_focus()


func _init_styles() -> void:
	_style_normal = StyleBoxFlat.new()
	_style_normal.bg_color = Color(0.14, 0.12, 0.20, 1.0)
	_style_normal.border_width_left = 1
	_style_normal.border_width_top = 1
	_style_normal.border_width_right = 1
	_style_normal.border_width_bottom = 1
	_style_normal.border_color = Color(0.36, 0.31, 0.42, 1.0)
	_style_normal.content_margin_left = 8.0
	_style_normal.content_margin_right = 8.0

	_style_focus = _style_normal.duplicate() as StyleBoxFlat
	_style_focus.bg_color = Color(0.24, 0.20, 0.32, 1.0)
	_style_focus.border_color = Color(1.0, 0.86, 0.36, 1.0)

	_style_pressed = _style_focus.duplicate() as StyleBoxFlat
	_style_pressed.bg_color = Color(0.32, 0.27, 0.40, 1.0)
