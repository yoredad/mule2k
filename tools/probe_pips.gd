extends SceneTree

func runs_at(img: Image, y: int) -> void:
	var runs: Array = []
	var cur: Dictionary = {}
	for x in range(img.get_width()):
		var c := img.get_pixel(x, y)
		var key := "%02X%02X%02X" % [int(c.r * 255), int(c.g * 255), int(c.b * 255)]
		if c.a < 0.5:
			key = "."
		if cur.is_empty() or cur.color != key:
			if not cur.is_empty():
				runs.append(cur)
			cur = {"color": key, "start": x, "end": x}
		else:
			cur.end = x
	runs.append(cur)
	for r in runs:
		print("  run ", r.color, " x=", r.start, "..", r.end, " w=", r.end - r.start + 1)

func _init() -> void:
	var img := Image.load_from_file("res://assets/pip_sheet.png")
	print("size=", img.get_width(), "x", img.get_height())
	for y in [30, 500, 520, 600]:
		print("runs at y=", y)
		runs_at(img, y)
	quit()
