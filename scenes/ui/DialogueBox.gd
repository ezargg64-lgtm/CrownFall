extends Control

## Keyboard & Gamepad-navigable bottom dialogue panel with typewriter reveal.

signal dialogue_finished(follow_up_shop_id: String)

@onready var panel: PanelContainer = $DialoguePanel
@onready var portrait_frame: PanelContainer = $DialoguePanel/HBox/PortraitFrame
@onready var portrait_rect: TextureRect = $DialoguePanel/HBox/PortraitFrame/PortraitRect
@onready var speaker_label: Label = $DialoguePanel/HBox/VBox/SpeakerLabel
@onready var text_label: Label = $DialoguePanel/HBox/VBox/TextLabel
@onready var hint_label: Label = $DialoguePanel/HBox/VBox/HintLabel

var _lines: PackedStringArray = []
var _line_index: int = 0
var _follow_up_shop_id: String = ""
var _visible_chars_float: float = 0.0
var _is_typing: bool = false
var _input_lock_timer: float = 0.0


func _ready() -> void:
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	if _input_lock_timer > 0.0:
		_input_lock_timer = maxf(0.0, _input_lock_timer - delta)
	if _is_typing:
		_visible_chars_float += delta * 55.0
		var total_chars: int = text_label.get_total_character_count()
		text_label.visible_characters = mini(total_chars, int(_visible_chars_float))
		if text_label.visible_characters >= total_chars:
			_is_typing = false
			text_label.visible_characters = -1


func _input(event: InputEvent) -> void:
	if not visible or _input_lock_timer > 0.0:
		return

	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_dialogue()
		return

	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		if _is_typing:
			_is_typing = false
			text_label.visible_characters = -1
			return
		_line_index += 1
		if _line_index < _lines.size():
			AudioManager.play_ui_confirm()
			_show_current_line()
		else:
			_close_dialogue()


func open_dialogue(
	speaker_name: String,
	portrait_path: String,
	lines: PackedStringArray,
	follow_up_shop_id: String = ""
) -> void:
	if lines.is_empty():
		return

	_lines = lines
	_line_index = 0
	_follow_up_shop_id = follow_up_shop_id
	_input_lock_timer = 0.14
	GameState.is_ui_open = true

	speaker_label.text = speaker_name
	if portrait_path.is_empty():
		portrait_frame.visible = false
	else:
		portrait_frame.visible = true
		portrait_rect.texture = load(portrait_path) as Texture2D

	visible = true
	AudioManager.play_ui_open()
	_show_current_line()


func _show_current_line() -> void:
	text_label.text = _lines[_line_index]
	text_label.visible_characters = 0
	_visible_chars_float = 0.0
	_is_typing = true
	if _line_index == _lines.size() - 1 and not _follow_up_shop_id.is_empty():
		hint_label.text = "[E / Enter / A] Open Menu  •  [Esc / B] Close"
	elif _line_index == _lines.size() - 1:
		hint_label.text = "[E / Enter / A] Finish"
	else:
		hint_label.text = "[E / Enter / A] Next  •  [Esc / B] Skip"


func _close_dialogue() -> void:
	var next_shop: String = _follow_up_shop_id
	_follow_up_shop_id = ""
	visible = false
	_is_typing = false
	AudioManager.play_ui_close()
	dialogue_finished.emit(next_shop)

	if not next_shop.is_empty():
		GameState.request_shop(next_shop)
	else:
		await get_tree().process_frame
		GameState.is_ui_open = false
		GameState.dialogue_closed.emit()
