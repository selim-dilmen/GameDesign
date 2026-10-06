extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var lamp_light: OmniLight3D = $Lamp/Light
@onready var lamp_body: MeshInstance3D = $Lamp/LampBody
@onready var switch_node: Node3D = $Switch
@onready var stick: Node3D = $Stick
@onready var stick_mesh: MeshInstance3D = $Stick/StickMesh
@onready var held_stick: MeshInstance3D = $Player/CarryBone/StickHeld
@onready var player_body: MeshInstance3D = $Player/Body
@onready var message_label: Label = $CanvasLayer/HUD/MessageLabel
@onready var finish_panel: PanelContainer = $CanvasLayer/FinishPanel
@onready var finish_label: Label = $CanvasLayer/FinishPanel/MarginContainer/VBoxContainer/FinishLabel
@onready var main_menu_button: Button = $CanvasLayer/FinishPanel/MarginContainer/VBoxContainer/MainMenuButton
@onready var next_level_button: Button = $CanvasLayer/FinishPanel/MarginContainer/VBoxContainer/NextLevelButton

var has_stick: bool = false
var finished: bool = false
var current_target: String = ""
var left_click_held: bool = false
var can_attack: bool = true
var attack_timer: float = 0.0

func _ready() -> void:
	finish_panel.visible = false
	message_label.visible = false
	main_menu_button.pressed.connect(_go_to_main_menu)
	next_level_button.pressed.connect(_go_to_next_level)
	held_stick.visible = false
	stick.visible = true
	lamp_light.visible = true

func _process(delta: float) -> void:
	if finished:
		return

	if not can_attack:
		attack_timer -= delta
		if attack_timer <= 0.0:
			can_attack = true
			player_body.rotation.z = 0.0

	var mouse_pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var just_clicked := mouse_pressed and not left_click_held
	left_click_held = mouse_pressed

	var dist_to_switch := player.global_position.distance_to(switch_node.global_position)
	var dist_to_stick := player.global_position.distance_to(stick.global_position)
	var dist_to_lamp := player.global_position.distance_to($Lamp.global_position)

	if dist_to_switch < 2.0:
		current_target = "switch"
	elif dist_to_stick < 1.5 and not has_stick:
		current_target = "stick"
	elif dist_to_lamp < 2.2 and has_stick:
		current_target = "lamp"
	else:
		current_target = ""

	if just_clicked:
		_handle_interaction()

func _handle_interaction() -> void:
	if finished:
		return

	match current_target:
		"switch":
			if can_attack:
				_perform_attack()
		"stick":
			if has_stick:
				return
			has_stick = true
			stick.visible = false
			held_stick.visible = true
			_animate_pickup()
		"lamp":
			if has_stick and can_attack:
				_perform_attack()
				await get_tree().create_timer(0.18).timeout
				lamp_light.visible = false
				lamp_body.visible = false
				_finish_level()

func _perform_attack() -> void:
	if not can_attack:
		return
	can_attack = false
	attack_timer = 0.45
	player_body.rotation.z = deg_to_rad(25)
	await get_tree().create_timer(0.08).timeout
	player_body.rotation.z = deg_to_rad(-25)
	await get_tree().create_timer(0.08).timeout
	player_body.rotation.z = 0.0
	if current_target == "lamp" and has_stick and player.global_position.distance_to($Lamp.global_position) < 2.2:
		lamp_light.visible = false
		lamp_body.visible = false
		_finish_level()

func _animate_pickup() -> void:
	var tween := create_tween()
	tween.tween_property(held_stick, "rotation_degrees", Vector3(0, 0, -60), 0.15)
	tween.tween_property(held_stick, "rotation_degrees", Vector3(0, 0, -30), 0.15)

func _finish_level() -> void:
	finished = true
	finish_label.text = "Level 1 finished"
	finish_panel.visible = true

func _go_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://MainMenu.tscn")

func _go_to_next_level() -> void:
	get_tree().change_scene_to_file("res://Levels/Level_2.tscn")
