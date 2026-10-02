extends Node2D

@onready var player = $Player
@onready var dog = $Dog
@onready var score_label = $CanvasLayer/ScoreLabel

var max_length := 120.0
var tug_strength := 180.0
var score := 0

var LureScene := preload("res://scenes/Lure.tscn")

func _ready():
    score_label.text = "Score: %d" % score

func _physics_process(delta):
    # Update dog with owner position
    dog.set_owner_position(player.global_position)

    # Enforce leash: if dog chases a lure and exceeds max_length, tug the player
    var diff := dog.global_position - player.global_position
    var dist := diff.length()
    if dist > max_length:
        var excess := dist - max_length
        var tug_dir := diff.normalized()
        # apply a proportional tug to player (so the player feels the pull)
        player.apply_tug(tug_dir * (tug_strength * (excess / max_length)) * delta)

func _input(event):
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        var click_pos := get_global_mouse_position()
        spawn_lure(click_pos)

func spawn_lure(pos: Vector2):
    var lure = LureScene.instantiate()
    add_child(lure)
    lure.global_position = pos
    dog.attract_to(lure)

func on_lure_collected(lure_node):
    # called by lure/dog when collected
    if is_instance_valid(lure_node):
        lure_node.queue_free()
    score += 1
    score_label.text = "Score: %d" % score
