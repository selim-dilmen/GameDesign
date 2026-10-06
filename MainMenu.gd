extends Control

@onready var main_panel: PanelContainer = $MainPanel
@onready var level_panel: PanelContainer = $LevelPanel
@onready var play_button: Button = $MainPanel/VBoxContainer/PlayButton
@onready var exit_button: Button = $MainPanel/VBoxContainer/ExitButton
@onready var back_button: Button = $LevelPanel/VBoxContainer/BackButton
@onready var level_grid: GridContainer = $LevelPanel/VBoxContainer/GridContainer

const LEVELS: Array[String] = [
	"res://Levels/Level_1.tscn",
	"res://Levels/Level_2.tscn",
	"res://Levels/Level_3.tscn",
	"res://Levels/Level_4.tscn",
	"res://Levels/Level_5.tscn",
]

func _ready() -> void:
	main_panel.visible = true
	level_panel.visible = false

	play_button.pressed.connect(_on_play_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	back_button.pressed.connect(_on_back_pressed)

	for i in range(min(level_grid.get_child_count(), LEVELS.size())):
		var button: Button = level_grid.get_child(i) as Button
		if button:
			button.pressed.connect(_on_level_selected.bind(i))

func _on_play_pressed() -> void:
	main_panel.visible = false
	level_panel.visible = true

func _on_back_pressed() -> void:
	main_panel.visible = true
	level_panel.visible = false

func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_level_selected(index: int) -> void:
	if index >= 0 and index < LEVELS.size():
		get_tree().change_scene_to_file(LEVELS[index])
