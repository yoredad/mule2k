extends SceneTree

func _init() -> void:
	var img: Image = Image.load_from_file("res://assets/mule_sheet.png")
	var x0 := 284
	var x1 := 440
	var y0 := 97
	var y1 := 244
	var w := x1 - x0
	var h := y1 - y0
	var cw := w / 40.0
	var ch := h / 32.0
	for gy in 32:
		var line := ""
		for gx in 40:
			var lum := 0.0
			var count := 0
			for yy in range(int(y0 + gy * ch), int(y0 + (gy + 1) * ch), 2):
				for xx in range(int(x0 + gx * cw), int(x0 + (gx + 1) * cw), 2):
					var px: Color = img.get_pixel(xx, yy)
					if px.a > 0.2:
						lum += px.r + px.g + px.b
						count += 1
			if count == 0:
				line += "."
			else:
				var avg := lum / count
				line += "D" if avg < 1.2 else ("L" if avg > 2.2 else "m")
		print(line)
	quit(0)
