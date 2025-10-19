extends CanvasLayer

var synergy_system: Node
var rune_system: RuneSystem

var ui_container: Control
var synergy_panel: Panel
var synergy_list: VBoxContainer
var selected_synergy = null

signal synergy_confirmed(rune_types: Array)

func _ready():
	synergy_system = get_node("../RuneSynergy")
	rune_system = get_node("../RuneSystem")
	_create_ui()
	hide_ui()

func _create_ui():
	ui_container = Control.new()
	ui_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_container.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(ui_container)

	var overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.92)
	ui_container.add_child(overlay)

	synergy_panel = Panel.new()
	synergy_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	synergy_panel.offset_left = -400
	synergy_panel.offset_right = 400
	synergy_panel.offset_top = -300
	synergy_panel.offset_bottom = 300
	ui_container.add_child(synergy_panel)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.1, 0.95)
	panel_style.border_color = Color(0.15, 0.15, 0.18)
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.border_width_top = 1
	panel_style.border_width_bottom = 1
	synergy_panel.add_theme_stylebox_override("panel", panel_style)

	var title = Label.new()
	title.text = "synergy"
	title.position = Vector2(20, 20)
	var title_font = load("res://assets/fonts/Federant-Regular.ttf")
	if title_font:
		title.add_theme_font_override("font", title_font)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	synergy_panel.add_child(title)

	var skull = Label.new()
	skull.text = "☠"
	skull.position = Vector2(730, 12)
	skull.add_theme_font_size_override("font_size", 32)
	skull.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45, 0.6))
	synergy_panel.add_child(skull)

	var scroll = ScrollContainer.new()
	scroll.position = Vector2(20, 60)
	scroll.size = Vector2(760, 520)
	synergy_panel.add_child(scroll)

	synergy_list = VBoxContainer.new()
	synergy_list.add_theme_constant_override("separation", 15)
	scroll.add_child(synergy_list)

func show_synergy_menu():
	if not synergy_system:
		return

	for child in synergy_list.get_children():
		child.queue_free()

	if synergy_system.has_active_synergy():
		_show_active_synergy()
		ui_container.visible = true
		return

	var check_result = synergy_system.can_create_synergy()

	if not check_result.can_synergize:
		print(check_result.reason)
		return

	for synergy_option in check_result.synergies:
		_add_synergy_option(synergy_option)

	ui_container.visible = true

func _show_active_synergy():
	"""Show the currently active synergy"""
	var active = synergy_system.get_active_synergy()
	var uses = synergy_system.get_synergy_uses_remaining()

	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(740, 200)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.08, 0.95)
	style.border_color = Color(0.3, 0.2, 0.3)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	panel.add_theme_stylebox_override("panel", style)

	synergy_list.add_child(panel)

	var title = Label.new()
	title.text = "active synergy"
	title.position = Vector2(15, 12)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.6, 0.5, 0.6))
	panel.add_child(title)

	var name_label = Label.new()
	name_label.text = active.name.to_lower()
	name_label.position = Vector2(15, 38)
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	panel.add_child(name_label)

	var uses_label = Label.new()
	uses_label.text = str(uses) + " use" + ("s" if uses > 1 else "") + " remaining"
	uses_label.position = Vector2(15, 68)
	uses_label.add_theme_font_size_override("font_size", 13)
	uses_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.5))
	panel.add_child(uses_label)

	var buffs_label = Label.new()
	var buff_texts = []
	for buff in active.buffs:
		buff_texts.append(buff.display)
	buffs_label.text = "active:\n" + "\n".join(buff_texts)
	buffs_label.position = Vector2(15, 95)
	buffs_label.size = Vector2(350, 90)
	buffs_label.add_theme_font_size_override("font_size", 13)
	buffs_label.add_theme_color_override("font_color", Color(0.65, 0.75, 0.65))
	panel.add_child(buffs_label)

	if synergy_system.is_corrupted():
		var corruption_label = Label.new()
		var debuff_texts = []
		for debuff in active.debuffs:
			debuff_texts.append(debuff.display)
		corruption_label.text = "corruption:\n" + "\n".join(debuff_texts)
		corruption_label.position = Vector2(380, 95)
		corruption_label.size = Vector2(340, 90)
		corruption_label.add_theme_font_size_override("font_size", 13)
		corruption_label.add_theme_color_override("font_color", Color(0.75, 0.55, 0.55))
		panel.add_child(corruption_label)

func _add_synergy_option(synergy_option: Dictionary):
	var runes = synergy_option.runes
	var synergy_data = synergy_option.synergy

	var option_panel = Panel.new()
	option_panel.custom_minimum_size = Vector2(740, 160)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.08, 0.9)
	style.border_color = Color(0.12, 0.12, 0.14)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	option_panel.add_theme_stylebox_override("panel", style)

	synergy_list.add_child(option_panel)

	var name_label = Label.new()
	name_label.text = synergy_data.name.to_lower()
	name_label.position = Vector2(15, 12)
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	option_panel.add_child(name_label)

	var uses_label = Label.new()
	uses_label.text = str(synergy_data.uses) + " use" + ("s" if synergy_data.uses > 1 else "")
	uses_label.position = Vector2(15, 40)
	uses_label.add_theme_font_size_override("font_size", 12)
	uses_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	option_panel.add_child(uses_label)

	var buffs_label = Label.new()
	var buff_texts = []
	for buff in synergy_data.buffs:
		buff_texts.append(buff.display)
	buffs_label.text = "\n".join(buff_texts)
	buffs_label.position = Vector2(15, 65)
	buffs_label.size = Vector2(350, 80)
	buffs_label.add_theme_font_size_override("font_size", 13)
	buffs_label.add_theme_color_override("font_color", Color(0.65, 0.75, 0.65))
	option_panel.add_child(buffs_label)

	var debuffs_label = Label.new()
	var debuff_texts = []
	for debuff in synergy_data.debuffs:
		debuff_texts.append(debuff.display)
	debuffs_label.text = "\n".join(debuff_texts)
	debuffs_label.position = Vector2(380, 65)
	debuffs_label.size = Vector2(280, 80)
	debuffs_label.add_theme_font_size_override("font_size", 13)
	debuffs_label.add_theme_color_override("font_color", Color(0.75, 0.55, 0.55))
	option_panel.add_child(debuffs_label)

	var runes_label = Label.new()
	var rune_names = []
	for rune_type in runes:
		var rune_info = rune_system.get_rune_info(rune_type)
		rune_names.append(rune_info.name)
	runes_label.text = "costs: " + ", ".join(rune_names)
	runes_label.position = Vector2(380, 40)
	runes_label.add_theme_font_size_override("font_size", 11)
	runes_label.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
	option_panel.add_child(runes_label)

	var accept_btn = Button.new()
	accept_btn.text = "accept"
	accept_btn.position = Vector2(670, 120)
	accept_btn.size = Vector2(60, 28)
	accept_btn.pressed.connect(_on_synergy_selected.bind(runes, synergy_data))
	option_panel.add_child(accept_btn)

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.1, 0.1, 0.12)
	btn_style.border_color = Color(0.2, 0.2, 0.22)
	btn_style.border_width_left = 1
	btn_style.border_width_right = 1
	btn_style.border_width_top = 1
	btn_style.border_width_bottom = 1
	accept_btn.add_theme_stylebox_override("normal", btn_style)
	accept_btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	accept_btn.add_theme_font_size_override("font_size", 12)

	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.15, 0.15, 0.17)
	btn_hover.border_color = Color(0.3, 0.3, 0.32)
	btn_hover.border_width_left = 1
	btn_hover.border_width_right = 1
	btn_hover.border_width_top = 1
	btn_hover.border_width_bottom = 1
	accept_btn.add_theme_stylebox_override("hover", btn_hover)

func _on_synergy_selected(runes: Array, synergy_data: Dictionary):
	var success = synergy_system.activate_synergy(runes, synergy_data)
	if success:
		hide_ui()

func hide_ui():
	ui_container.visible = false
	selected_synergy = null

func _input(event):
	if event.is_action_pressed("ui_cancel") and ui_container.visible:
		hide_ui()
