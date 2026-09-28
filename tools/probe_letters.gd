extends SceneTree

func _init() -> void:
	var img: Image = Image.load_from_file("res://assets/mule_sheet.png")
	var bands := [[284, 440], [462, 620], [637, 796], [810, 971], [987, 1147]]
	for c in 5:
		var x0: int = bands[c][0]
		var x1: int = bands[c][1]
		var w: int = x1 - x0
		var cw := w / 24.0
		print("--- icon ", c, " ---")
		for gy in 26:
			var line := ""
			for gx in 24:
				var lum := 0.0
				var count := 0
				for yy in range(97 + gy * 6, 97 + (gy + 1) * 6, 2):
					for xx in range(x0 + int(gx * cw), x0 + int((gx + 1) * cw), 2):
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
