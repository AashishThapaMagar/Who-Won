extends RichTextEffect
## [slam start=<seconds>]NAME[/slam]: a fighter's name lands one letter at a
## time, each dropping in hard with a white-gold flash, then a gold shine
## sweeps across it every few seconds. "start" is Time.get_ticks_msec() / 1000
## at the moment the name was picked.

var bbcode := "slam"

## Delay between one letter and the next.
const STAGGER := 0.045
## Time for a letter to fall into place.
const DROP := 0.24
## How far above its place a letter starts.
const HEIGHT := 30.0
## How long the landing flash takes to fade.
const FLASH := 0.4
const FLASH_COLOR := Color(1.0, 0.93, 0.62)
## The shine: one pass every PERIOD seconds, crossing SPEED letters a second.
const PERIOD := 3.6
const SPEED := 16.0
const SHINE_COLOR := Color(1.0, 0.84, 0.36)

func _process_custom_fx(fx: CharFXTransform) -> bool:
	var start := float(fx.env.get("start", 0.0))
	var since := Time.get_ticks_msec() / 1000.0 - start
	var i := float(fx.relative_index)
	var t := since - i * STAGGER
	if t <= 0.0:
		fx.color.a = 0.0
		return true
	# Fall with a small overshoot past the line, then settle (ease-out-back).
	var k := clampf(t / DROP, 0.0, 1.0)
	var back := 1.0 + 2.7 * pow(k - 1.0, 3.0) + 1.7 * pow(k - 1.0, 2.0)
	fx.offset.y -= (1.0 - back) * HEIGHT
	fx.color.a *= clampf(t / (DROP * 0.4), 0.0, 1.0)
	var base := fx.color
	fx.color = FLASH_COLOR.lerp(base, clampf(t / FLASH, 0.0, 1.0))
	fx.color.a = base.a
	# The shine starts once every letter has landed.
	var cycle := fmod(since - 0.9, PERIOD)
	if since > 0.9:
		var head := cycle * SPEED - 2.0
		var glow := clampf(1.0 - absf(i - head) / 1.6, 0.0, 1.0)
		fx.color = fx.color.lerp(SHINE_COLOR, glow * 0.85)
		fx.color.a = base.a
	return true
