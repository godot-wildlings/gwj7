"""
Ranged Enemy

Requires:
	- Hitbox Area2D
	- AttackTimer Timer
	- AttackRadius Area2D
"""

extends KinematicBody2D

signal health_changed
signal shoot(projectile_scene, pos, rot, vel)

enum States { ALIVE, DEAD }
var _state = States.ALIVE

export var health : float = 3 setget _set_health
#onready var projectile_container : Node2D = util.get_main_node().get_node("ProjectileContainer")
onready var _player : KinematicBody2D = global.player
onready var _attack_timer : Timer = $AttackTimer

export var projectile_tscn : PackedScene = preload("res://Projectiles/Fireball/Fireball.tscn") as PackedScene
#warning-ignore:unused_class_variable
export var spawn_distance : float = 10
export var speed : float = 100
#warning-ignore:unused_class_variable
export var on_hit_dmg : float = 1
export var max_health : float = 3
export var attack_pause_time : float = 1.5

var _hitstun : int = 0
var _move_timer : int = 0
var _move_timer_length : int = 30
var _knock_dir : Vector2 = Vector2.ZERO
var _move_dir : Vector2
var _is_in_attack_range : bool = false
var _initial_modulate : Color
var _can_attack : bool = true
var motion : Vector2

"""
walk up until in range (determined by area2d collisionshape)
start attacking (timer based cooldown)

"""

func _ready():
	if health == null:
		health = max_health
	if health < 0:
		die()
		
	
	if has_node("Label"):
		$Label.text = "Health: " + str(health)
	_initial_modulate = modulate

	
	_attack_timer.wait_time = attack_pause_time
	#warning-ignore:return_value_discarded
	_attack_timer.connect("timeout", self, "_on_AttackTimer_timeout")
	#warning-ignore:return_value_discarded
	connect("health_changed", self, "_on_health_change")
	#warning-ignore:return_value_discarded
	
	if has_node("AttackRadius"):
		$AttackRadius.connect("body_entered", self, "_on_AttackRadius_body_entered")
		#warning-ignore:return_value_discarded
		$AttackRadius.connect("body_exited", self, "_on_AttackRadius_body_exited")

#warning-ignore:unused_argument
func _physics_process(delta : float):

	if is_instance_valid(_player) and _state == States.ALIVE:
		_damage_loop()
		if not _is_in_attack_range:
			_movement_loop()
			if _move_timer > 0:
				_move_timer -= 1
			if _move_timer == 0 || is_on_wall():
				_move_dir = _player.position - position
				_move_timer = _move_timer_length
		else:
			if _can_attack:
				_attack()
				_can_attack = false
				_attack_timer.start()
		
func _movement_loop():
	
	if _hitstun == 0:
		motion = _move_dir.normalized() * speed 
	else:
		motion = _knock_dir.normalized() * 125
	
	#warning-ignore:return_value_discarded
	move_and_slide(motion, Vector2.ZERO)
	
func _damage_loop():
	health = min(max_health, health)
	if _hitstun > 0:
		_hitstun -= 1
		modulate = Color.red
	else:
		modulate = _initial_modulate
		if health <= 0:
			queue_free()

	if health > 0:
		for body in $Hitbox.get_overlapping_bodies():
			if body.is_in_group("projectiles"):
				if _hitstun == 0 and body.damage != 0:
					self.health -= body.damage
					_hitstun = 10
					_knock_dir = get_global_transform().origin - body.get_global_transform().origin 
					body.queue_free()

func _attack():
	
#	var projectile_instance : Node2D = projectile_tscn.instance()
#	projectile_container.add_child(projectile_instance)
#	if projectile_instance.has_method("shoot"):
#		projectile_instance.shoot(global_position, (_player.global_position - global_position))
##		$AudioStreamPlayer.play()
	var my_pos = get_global_position()
	if is_instance_valid(global.player):
		var player_pos = global.player.get_global_position()
		var _err = connect("shoot", global.current_level, "_on_projectile_requested")
		if _err: push_warning(_err)
		emit_signal("shoot", projectile_tscn, my_pos, Vector2(1,0).angle_to(player_pos - my_pos), motion)
		disconnect("shoot", global.current_level, "_on_projectile_requested")

func _on_level_initialized():
	_player = global.player
	
func _on_AttackRadius_body_entered(body : PhysicsBody2D):
	if body == global.player:
		_is_in_attack_range = true

func _on_AttackRadius_body_exited(body : PhysicsBody2D):
	if body == global.player:
		_is_in_attack_range = false

func _on_health_change():
	$Label.text = "Health: " + str(health)

func _on_AttackTimer_timeout():
	_can_attack = true

func _set_health(new_health : float):
	if new_health != health:
		health = new_health
		emit_signal("health_changed")
		
func disable_hitboxes():
	$CollisionShape2D.call_deferred("set_disabled", true)
	$Hitbox/CollisionShape2D.call_deferred("set_disabled", true)


func die():
	# spawn corpse and bloodstain
	# queue_free after a timer, if desired
	disable_hitboxes()
	$Sprite.hide()
	
	if has_node("DeadBody"):
		$DeadBody.show()
		if $DeadBody.has_node("CorposeDuration"):
			$DeadBody/CorpseDuration.start() # disappear later
	_state = States.DEAD
	
func _on_hit(damage): # signal from BigArrow.tscn
	if has_node("HitNoise"):
		$HitNoise.play()
	health -= damage
	if health < 0:
		die()


func _on_CorpseDuration_timeout():
	call_deferred("queue_free")