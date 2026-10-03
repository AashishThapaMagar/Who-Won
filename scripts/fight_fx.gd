extends Control
## Fighting-game flourishes over the HUD (presentation only): the big
## Tekken-style combo counter, white impact flashes on heavy hits, the K.O.
## burst, and the control hints that fade out once the fight is under way.
const UI := preload("res://scripts/ui_kit.gd")
const HINT_SECONDS := 5.0
var hud: Node
var arena: Node
var counters: Array = []
var flash: ColorRect
var burst: Control
var burst_age := -1.0
var hint: Label
var hint_clock := 0.0
var last_round := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 8
	for side in 2:
		counters.append(_build_counter(side))
	flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(flash)
	burst = Control.new()
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	burst.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	burst.draw.connect(_draw_burst)
	burst.visible = false
	add_child(burst)
	hint = arena.get_node("UI/ControlsHint")
	for side in 2:
		var fighter: Node = arena.player1 if side == 0 else arena.player2
		fighter.impact.connect(_on_impact.bind(side))

## One counter per attacker: a slanted plate with the hit count in huge
## type, "HITS" beside it and the damage underneath.
func _build_counter(side: int) -> Dictionary:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var x := 26.0 if side == 0 else 960.0 - 26.0 - 210.0
	root.position = Vector2(x, 142)
	root.size = Vector2(210, 126)
	root.modulate.a = 0.0
	add_child(root)
	var accent: Color = UI.CRIMSON if side == 0 else Color("2f6fd1")
	var plate := Polygon2D.new()
	var dir := 1.0 if side == 0 else -1.0
	var left := 0.0 if side == 0 else 210.0
	plate.polygon = PackedVector2Array([Vector2(left, 8), Vector2(left + dir * 196, 0), Vector2(left + dir * 176, 118), Vector2(left, 112)])
	plate.color = Color(0.02, 0.02, 0.05, 0.62)
	root.add_child(plate)
	var edge := Polygon2D.new()
	edge.polygon = PackedVector2Array([Vector2(left, 8), Vector2(left + dir * 6, 8), Vector2(left + dir * 6, 112), Vector2(left, 112)])
	edge.color = accent
	root.add_child(edge)
	var number := UI.heading(root, "0", Vector2(14, -6), Vector2(120, 96), 92, UI.WHITE, accent)
	number.add_theme_constant_override("outline_size", 8)
	number.add_theme_constant_override("shadow_offset_x", 5)
	number.add_theme_constant_override("shadow_offset_y", 5)
	var hits := UI.heading(root, "HITS", Vector2(128, 24), Vector2(80, 36), 28, UI.GOLD, UI.INK)
	var damage := UI.heading(root, "", Vector2(14, 82), Vector2(190, 26), 18, UI.WHITE, UI.INK)
	if side == 1:
		number.position.x = 210.0 - 14.0 - 120.0
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hits.position.x = 210.0 - 128.0 - 80.0
		hits.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		damage.position.x = 210.0 - 14.0 - 190.0
		damage.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	number.pivot_offset = number.size * 0.5
	return {"root": root, "number": number, "hits": hits, "damage": damage, "last": 0, "alpha": 0.0}

func _process(delta: float) -> void:
	if arena == null:
		return
	for side in 2:
		_update_counter(side, delta)
	flash.color.a = move_toward(flash.color.a, 0.0, delta * 2.4)
	if burst_age >= 0.0:
		burst_age += delta
		burst.queue_redraw()
		if burst_age > 0.7:
			burst_age = -1.0
			burst.visible = false
	_update_hint(delta)

func _update_counter(side: int, delta: float) -> void:
	var fighter: Node = arena.player1 if side == 0 else arena.player2
	var c: Dictionary = counters[side]
	var live: bool = fighter.combo_hits > 1 and fighter.combat_time - fighter._last_land_time < 1.1
	var root: Control = c.root
	c.alpha = move_toward(c.alpha, 1.0 if live else 0.0, delta * (9.0 if live else 2.8))
	root.modulate.a = c.alpha
	if not live:
		c.last = 0
		return
	var number: Label = c.number
	number.text = str(fighter.combo_hits)
	c.damage.text = "%d DAMAGE" % fighter.combo_damage
	# White at first, gold from four hits, hot red from seven.
	var color := UI.WHITE if fighter.combo_hits < 4 else (UI.GOLD if fighter.combo_hits < 7 else Color("ff4a3a"))
	number.add_theme_color_override("font_color", color)
	if fighter.combo_hits != c.last:
		c.last = fighter.combo_hits
		number.scale = Vector2.ONE * 1.6
		number.create_tween().tween_property(number, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Heavy clean hits flash the screen white for a few frames; guarded ones
## give a small cool flash.
func _on_impact(_point: Vector2, blocked: bool, heavy: bool, _side: int) -> void:
	if blocked:
		flash.color = Color(0.7, 0.85, 1.0, 0.07)
	elif heavy:
		flash.color = Color(1, 1, 1, 0.24)

## The K.O.: a white flash, gold rays bursting from the middle and a shove
## of camera shake. match_hud calls this as the big "K.O." slams in.
func knockout() -> void:
	flash.color = Color(1, 0.98, 0.92, 0.22)
	burst_age = 0.0
	burst.visible = true
	if "shake_3d" in arena:
		arena.shake_3d = maxf(arena.shake_3d, 0.35)

func _draw_burst() -> void:
	var t := clampf(burst_age / 0.7, 0.0, 1.0)
	var centre := Vector2(480, 262)
	var count := 22
	for i in count:
		var angle := TAU * float(i) / count + 0.11
		var reach := lerpf(60.0, 760.0, 1.0 - pow(1.0 - t, 3.0))
		var inner := reach * 0.35 + 40.0 * t
		var width := lerpf(0.09, 0.015, t)
		var colour := Color(1.0, 0.82, 0.3, (1.0 - t) * 0.9) if i % 2 == 0 else Color(1.0, 1.0, 1.0, (1.0 - t) * 0.8)
		var a := centre + Vector2.RIGHT.rotated(angle - width) * reach
		var b := centre + Vector2.RIGHT.rotated(angle + width) * reach
		burst.draw_colored_polygon(PackedVector2Array([centre + Vector2.RIGHT.rotated(angle) * inner, a, b]), colour)

## The key legend stays up for the opening seconds of a match, then gets
## out of the way (practice keeps it).
func _update_hint(delta: float) -> void:
	if hint == null or str(arena.get_script().resource_path).ends_with("practice_3d.gd"):
		return
	if arena.round_index != last_round:
		if arena.round_index == 0:
			hint_clock = 0.0
		last_round = arena.round_index
	if arena.round_active:
		hint_clock += delta
	var fade := 1.0 - clampf((hint_clock - HINT_SECONDS) / 1.5, 0.0, 1.0)
	hint.modulate.a = fade
	# The F1 move-list button stays, faint, once the legend has gone.
	var moves := arena.get_node_or_null("UI/MovesButton")
	if moves != null:
		moves.modulate.a = lerpf(0.35, 1.0, fade)
