# ui_kit.gd — UI 构建工具：像素风主题（中文字体走系统字体回退）、通用控件工厂
class_name UIKit
extends RefCounted

static var _theme: Theme


static func theme() -> Theme:
	if _theme == null:
		var f := SystemFont.new()
		f.font_names = ["Microsoft YaHei UI", "Microsoft YaHei", "SimHei", "sans-serif"]
		_theme = Theme.new()
		_theme.default_font = f
		_theme.default_font_size = 11
	return _theme


static func label(text: String, size := 11, color := Color(0.86, 0.91, 0.90)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func center(text: String, size := 11, color := Color(0.86, 0.91, 0.90)) -> Label:
	var l := label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func panel_style(bg := Color(0.09, 0.12, 0.12, 0.94), border := Color(0.38, 0.71, 0.66, 0.6)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = border
	sb.corner_radius_top_left = 2
	sb.corner_radius_top_right = 2
	sb.corner_radius_bottom_left = 2
	sb.corner_radius_bottom_right = 2
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	return sb


static func bar(root: Control, name: String, pos: Vector2, size: Vector2, bg_c: Color, fg_c: Color) -> Dictionary:
	var bg := ColorRect.new()
	bg.name = name + "_bg"
	bg.position = pos
	bg.size = size
	bg.color = Color(0.06, 0.08, 0.08, 0.8)
	bg.z_index = 0
	root.add_child(bg)
	var border := ColorRect.new()
	border.name = name + "_bd"
	border.position = pos - Vector2.ONE
	border.size = size + Vector2(2, 2)
	border.color = Color(0.35, 0.45, 0.44, 0.5)
	border.z_index = -1
	root.add_child(border)
	var fg := ColorRect.new()
	fg.name = name + "_fg"
	fg.position = pos + Vector2.ONE
	fg.size = Vector2(size.x - 2, size.y - 2)
	fg.color = fg_c
	fg.z_index = 1
	root.add_child(fg)
	return {"bg": bg, "fg": fg, "fg_color": fg_c, "full_w": size.x - 2}


static func set_bar(bar: Dictionary, ratio: float, color: Color = Color(0, 0, 0, 0)) -> void:
	var fg: ColorRect = bar.fg
	fg.size.x = maxf(0.0, bar.full_w * clampf(ratio, 0.0, 1.0))
	if color.a > 0.0:
		fg.color = color
