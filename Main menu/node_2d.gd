
extends Control

# ============================================================
# SPACE VAULT - MAIN MENU
# Godot 4.7
#
# - Fits background to the entire screen
# - Removes grey borders
# - Changes subtitle to Escape From Earth
# - Preserves original Main Menu design
# - Preserves START button animation
# - Preserves cinematic fade to black
# - Resets completed game progression
# - Opens intro scene
# ============================================================

const INTRO_SCENE_PATH: String = (
	"res://scenes/intro_scene.tscn"
)

const INTRO_SCENE: PackedScene = preload(
	"res://scenes/intro_scene.tscn"
)

const FADE_DURATION: float = 1.0
const BLACK_HOLD_DURATION: float = 0.15

@onready var background_image: TextureRect = (
	$TextureRect
)

@onready var menu_camera: Camera2D = (
	$Camera2D
)

@onready var start_button: Button = (
	$VBoxContainer/Button
)

@onready var subtitle_label: Label = (
	$VBoxContainer/subtitle
)

var transition_layer: CanvasLayer
var fade_overlay: ColorRect

var button_pulse: Tween
var transition_tween: Tween

var starting_game: bool = false


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	# Update the menu subtitle.
	subtitle_label.text = "Escape From Earth"

	# Fit the existing Main Menu to the viewport.
	_fit_menu_to_screen()

	get_viewport().size_changed.connect(
		_fit_menu_to_screen
	)

	# Reset progression if all Scientists
	# were defeated in the previous game.
	_check_completed_game_reset()

	# Set up the cinematic fade.
	_create_transition_layer()

	start_button.disabled = false
	start_button.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)

	var callback: Callable = Callable(
		self,
		"_on_button_pressed"
	)

	if not start_button.pressed.is_connected(callback):
		start_button.pressed.connect(callback)

	start_button.grab_focus()

	_start_button_pulse()

	print("SPACE VAULT: Main Menu ready.")


# ============================================================
# FIT MAIN MENU TO SCREEN
# ============================================================

func _fit_menu_to_screen() -> void:
	if not is_instance_valid(background_image):
		return

	if not is_instance_valid(menu_camera):
		return

	var viewport_size: Vector2 = (
		get_viewport_rect().size
	)

	var background_size: Vector2 = (
		background_image.size
		* background_image.scale.abs()
	)

	if (
		viewport_size.x <= 0.0
		or viewport_size.y <= 0.0
		or background_size.x <= 0.0
		or background_size.y <= 0.0
	):
		return

	# Zoom enough to completely fill the screen.
	# Using max() prevents grey borders.
	# A very small part of the background may be
	# cropped if the window aspect ratio differs.
	var zoom_x: float = (
		viewport_size.x / background_size.x
	)

	var zoom_y: float = (
		viewport_size.y / background_size.y
	)

	var target_zoom: float = max(
		zoom_x,
		zoom_y
	)

	menu_camera.zoom = Vector2(
		target_zoom,
		target_zoom
	)

	# Centre the camera on the background.
	menu_camera.position = (
		background_image.position
		+ background_image.size
		* background_image.scale
		* 0.5
	)

	menu_camera.enabled = true
	menu_camera.make_current()


# ============================================================
# RESET FINISHED GAME
# ============================================================

func _check_completed_game_reset() -> void:
	if not SpacecraftGameState.is_final_escape_unlocked():
		return

	print(
		"SPACE VAULT: Completed game detected."
	)

	SpacecraftGameState.reset_progress()

	print(
		"SPACE VAULT: Scientist battles reset."
	)


# ============================================================
# START BUTTON ANIMATION
# ============================================================

func _start_button_pulse() -> void:
	if is_instance_valid(button_pulse):
		button_pulse.kill()

	start_button.modulate.a = 1.0

	button_pulse = create_tween()
	button_pulse.set_loops()
	button_pulse.set_trans(
		Tween.TRANS_SINE
	)
	button_pulse.set_ease(
		Tween.EASE_IN_OUT
	)

	button_pulse.tween_property(
		start_button,
		"modulate:a",
		0.45,
		0.75
	)

	button_pulse.tween_property(
		start_button,
		"modulate:a",
		1.0,
		0.75
	)


# ============================================================
# CREATE CINEMATIC FADE
# ============================================================

func _create_transition_layer() -> void:
	transition_layer = CanvasLayer.new()
	transition_layer.name = "MenuTransitionLayer"
	transition_layer.layer = 100

	add_child(transition_layer)

	fade_overlay = ColorRect.new()
	fade_overlay.name = "FadeToBlack"
	fade_overlay.color = Color.BLACK
	fade_overlay.modulate.a = 0.0
	fade_overlay.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	transition_layer.add_child(fade_overlay)

	fade_overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	fade_overlay.size = get_viewport_rect().size
	fade_overlay.show()


# ============================================================
# START GAME
# ============================================================

func _on_button_pressed() -> void:
	if starting_game:
		return

	if INTRO_SCENE == null:
		push_error(
			"Introduction scene could not load: "
			+ INTRO_SCENE_PATH
		)
		return

	starting_game = true
	start_button.disabled = true

	if is_instance_valid(button_pulse):
		button_pulse.kill()

	start_button.modulate.a = 1.0

	fade_overlay.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)

	_fade_to_intro()


# ============================================================
# FADE TO BLACK
# ============================================================

func _fade_to_intro() -> void:
	fade_overlay.show()
	fade_overlay.modulate.a = 0.0

	transition_tween = create_tween()
	transition_tween.set_trans(
		Tween.TRANS_SINE
	)
	transition_tween.set_ease(
		Tween.EASE_IN_OUT
	)

	transition_tween.tween_property(
		fade_overlay,
		"modulate:a",
		1.0,
		FADE_DURATION
	)

	transition_tween.tween_interval(
		BLACK_HOLD_DURATION
	)

	await transition_tween.finished

	if not is_inside_tree():
		return

	_open_intro_scene()


# ============================================================
# OPEN INTRO
# ============================================================

func _open_intro_scene() -> void:
	var error: Error = (
		get_tree().change_scene_to_packed(
			INTRO_SCENE
		)
	)

	if error != OK:
		push_error(
			"Failed to open intro. Error code: "
			+ str(error)
		)

		_restore_main_menu()


# ============================================================
# RESTORE MENU ON ERROR
# ============================================================

func _restore_main_menu() -> void:
	starting_game = false
	start_button.disabled = false

	var restore_tween: Tween = create_tween()
	restore_tween.set_trans(
		Tween.TRANS_SINE
	)
	restore_tween.set_ease(
		Tween.EASE_IN_OUT
	)

	restore_tween.tween_property(
		fade_overlay,
		"modulate:a",
		0.0,
		0.4
	)

	await restore_tween.finished

	if not is_inside_tree():
		return

	fade_overlay.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	_start_button_pulse()
	start_button.grab_focus()
