# 시장 — 검 되팔기 + 주문서 구매.
# Sell current sword: price = SwordStore.sell_price(level) (50 + level² × 100),
# resets to +0. Buying a fresh +0 isn't a feature in classic 검강화하기 — the
# default sword is free after sell, so the only buy here is the protection scroll.
#
# Status panel echoes ProgressStore counters; transactions emit signals that
# the panel listens to so the UI updates without manual refresh.

extends Control

const SWORD_DISPLAY := preload("res://scenes/SwordDisplay.tscn")

var _tickets_label: Label
var _gold_label: Label
var _scrolls_label: Label
var _shards_label: Label
var _sell_button: Button
var _scroll_buttons: Dictionary = {}      # qty (int) → Button — 1/3/10 bundles
var _exchange_buttons: Dictionary = {}    # target_level (int) → shard-buy Button
var _gold_buy_buttons: Dictionary = {}    # target_level (int) → gold-buy Button
var _status_label: Label
var _sword_slot: Control
var _consumable_section: Control         # container that can be locked/unlocked
var _consumable_lock_label: Label        # shown when shop is locked
var _consumable_buttons: Dictionary = {} # id → Array[Button] — per-currency buttons


func _ready() -> void:
	_build_layout()
	_refresh()
	ProgressStore.weapon_changed.connect(func(_lv): _refresh())
	ProgressStore.gold_changed.connect(func(_n): _refresh())
	ProgressStore.scrolls_changed.connect(func(_n): _refresh())
	ProgressStore.tickets_changed.connect(func(_n): _refresh())
	ProgressStore.shards_changed.connect(func(_n): _refresh())
	ProgressStore.consumables_changed.connect(func(_s): _refresh())
	ProgressStore.progress_changed.connect(_refresh)


func _build_layout() -> void:
	var outer := MarginContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left", 32)
	outer.add_theme_constant_override("margin_right", 32)
	outer.add_theme_constant_override("margin_top", 18)
	outer.add_theme_constant_override("margin_bottom", 24)
	add_child(outer)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = SIZE_EXPAND_FILL
	root.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 14)
	outer.add_child(root)

	# ── Top bar
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)

	var back := Button.new()
	back.text = "← 홈"
	back.custom_minimum_size = Vector2(90, 38)
	back.pressed.connect(_go_home)
	top.add_child(back)

	var sp := Control.new()
	sp.size_flags_horizontal = SIZE_EXPAND_FILL
	top.add_child(sp)

	_tickets_label = _make_counter("강화권 0", Color(0.7, 1.0, 0.85))
	top.add_child(_tickets_label)
	_gold_label = _make_counter("골드 0", Color(1.0, 0.85, 0.3))
	top.add_child(_gold_label)
	_scrolls_label = _make_counter("주문서 0", Color(0.9, 0.75, 1.0))
	top.add_child(_scrolls_label)
	_shards_label = _make_counter("파편 0", Color(0.95, 0.6, 0.55))
	top.add_child(_shards_label)

	# ── Title
	var title := Label.new()
	title.text = "🏪  시장"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	root.add_child(title)

	# ── Body: 2-column (preview | actions)
	var body := HBoxContainer.new()
	body.size_flags_horizontal = SIZE_EXPAND_FILL
	body.size_flags_vertical = SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	root.add_child(body)

	# Left column — sword preview so the player sees what they're selling.
	var left := Control.new()
	left.size_flags_horizontal = SIZE_EXPAND_FILL
	left.size_flags_vertical = SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.0
	left.custom_minimum_size = Vector2(360, 360)
	left.clip_contents = true
	body.add_child(left)

	_sword_slot = SWORD_DISPLAY.instantiate()
	_sword_slot.set_anchors_preset(Control.PRESET_FULL_RECT)
	left.add_child(_sword_slot)

	# Right column — actions.
	var right := VBoxContainer.new()
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	right.size_flags_vertical = SIZE_FILL
	right.size_flags_stretch_ratio = 1.0
	right.add_theme_constant_override("separation", 14)
	body.add_child(right)

	# Sell row
	var sell_panel := PanelContainer.new()
	right.add_child(sell_panel)
	var sell_margin := MarginContainer.new()
	sell_margin.add_theme_constant_override("margin_left", 16)
	sell_margin.add_theme_constant_override("margin_right", 16)
	sell_margin.add_theme_constant_override("margin_top", 12)
	sell_margin.add_theme_constant_override("margin_bottom", 12)
	sell_panel.add_child(sell_margin)
	var sell_box := VBoxContainer.new()
	sell_box.add_theme_constant_override("separation", 8)
	sell_margin.add_child(sell_box)

	var sell_title := Label.new()
	sell_title.text = "검 되팔기"
	sell_title.add_theme_font_size_override("font_size", 18)
	sell_box.add_child(sell_title)

	var sell_desc := Label.new()
	sell_desc.text = "현재 검을 팔고 +0 새 검으로 다시 시작합니다.\n등급이 높을수록 가격이 크게 오릅니다."
	sell_desc.add_theme_font_size_override("font_size", 13)
	sell_desc.modulate = Color(0.7, 0.75, 0.85)
	sell_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sell_box.add_child(sell_desc)

	_sell_button = Button.new()
	_sell_button.custom_minimum_size = Vector2(280, 50)
	_sell_button.add_theme_font_size_override("font_size", 16)
	_sell_button.pressed.connect(_on_sell)
	sell_box.add_child(_sell_button)

	# Scroll row
	var scroll_panel := PanelContainer.new()
	right.add_child(scroll_panel)
	var scroll_margin := MarginContainer.new()
	scroll_margin.add_theme_constant_override("margin_left", 16)
	scroll_margin.add_theme_constant_override("margin_right", 16)
	scroll_margin.add_theme_constant_override("margin_top", 12)
	scroll_margin.add_theme_constant_override("margin_bottom", 12)
	scroll_panel.add_child(scroll_margin)

	var scroll_box := VBoxContainer.new()
	scroll_box.add_theme_constant_override("separation", 8)
	scroll_margin.add_child(scroll_box)

	var scroll_title := Label.new()
	scroll_title.text = "보호 주문서 (1회용)"
	scroll_title.add_theme_font_size_override("font_size", 18)
	scroll_box.add_child(scroll_title)

	var scroll_desc := Label.new()
	scroll_desc.text = "강화 실패 시 등급 하락(-2)을 막아 +N 그대로 유지.\n+6 이상에서만 효과 있음."
	scroll_desc.add_theme_font_size_override("font_size", 13)
	scroll_desc.modulate = Color(0.7, 0.75, 0.85)
	scroll_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scroll_box.add_child(scroll_desc)

	# Bundle buttons — 1 / 3 / 10. Bigger bundles get progressively cheaper
	# per-scroll so a player camped at +9~+12 doesn't click-spam single buys.
	var bundle_qtys: Array = ProgressStore.SCROLL_BUNDLES.keys()
	bundle_qtys.sort()
	for qty in bundle_qtys:
		var b := Button.new()
		b.custom_minimum_size = Vector2(280, 44)
		b.add_theme_font_size_override("font_size", 15)
		b.pressed.connect(func(): _on_buy_scroll(qty))
		scroll_box.add_child(b)
		_scroll_buttons[qty] = b

	# Shard exchange — pre-enhanced sword tiers paid in shards. The shop
	# wholesale-replaces the current sword (the existing one is wiped), so the
	# UI calls it out as "교환" not "구매" to discourage the player from
	# expecting their +10 to coexist with a freshly-bought +6.
	var exchange_panel := PanelContainer.new()
	right.add_child(exchange_panel)
	var ex_margin := MarginContainer.new()
	ex_margin.add_theme_constant_override("margin_left", 16)
	ex_margin.add_theme_constant_override("margin_right", 16)
	ex_margin.add_theme_constant_override("margin_top", 12)
	ex_margin.add_theme_constant_override("margin_bottom", 12)
	exchange_panel.add_child(ex_margin)
	var ex_box := VBoxContainer.new()
	ex_box.add_theme_constant_override("separation", 8)
	ex_margin.add_child(ex_box)

	var ex_title := Label.new()
	ex_title.text = "검 교환소 (파편)"
	ex_title.add_theme_font_size_override("font_size", 18)
	ex_box.add_child(ex_title)

	var ex_desc := Label.new()
	ex_desc.text = "강화 실패로 파괴된 검에서 회수한 파편으로\n사전 강화된 검을 교환합니다. 현재 검은 사라집니다."
	ex_desc.add_theme_font_size_override("font_size", 13)
	ex_desc.modulate = Color(0.7, 0.75, 0.85)
	ex_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ex_box.add_child(ex_desc)

	# Tier buttons in ascending order — sorted dict keys, no surprises.
	var tiers: Array = ProgressStore.SHARD_EXCHANGE.keys()
	tiers.sort()
	for tier in tiers:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(280, 44)
		btn.add_theme_font_size_override("font_size", 15)
		btn.pressed.connect(func(): _on_exchange(tier))
		ex_box.add_child(btn)
		_exchange_buttons[tier] = btn

	# Gold-only shop — same tier ladder but paid in gold. Strictly more
	# expensive than direct enhancement on a gold basis (see SWORD_GOLD_PRICE
	# comment) so this never strictly dominates the grind; it's an "insurance"
	# path when the player has gold but can't bear another destroy.
	var gold_panel := PanelContainer.new()
	right.add_child(gold_panel)
	var gp_margin := MarginContainer.new()
	gp_margin.add_theme_constant_override("margin_left", 16)
	gp_margin.add_theme_constant_override("margin_right", 16)
	gp_margin.add_theme_constant_override("margin_top", 12)
	gp_margin.add_theme_constant_override("margin_bottom", 12)
	gold_panel.add_child(gp_margin)
	var gp_box := VBoxContainer.new()
	gp_box.add_theme_constant_override("separation", 8)
	gp_margin.add_child(gp_box)

	var gp_title := Label.new()
	gp_title.text = "검 구매소 (골드)"
	gp_title.add_theme_font_size_override("font_size", 18)
	gp_box.add_child(gp_title)

	var gp_desc := Label.new()
	gp_desc.text = "골드로 사전 강화된 검을 구매합니다.\n파괴 없이 단계를 점프하고 싶을 때.\n같은 등급 직접 강화보다 비쌉니다 — 운빨 회피 보험용."
	gp_desc.add_theme_font_size_override("font_size", 13)
	gp_desc.modulate = Color(0.7, 0.75, 0.85)
	gp_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gp_box.add_child(gp_desc)

	var gold_tiers: Array = ProgressStore.SWORD_GOLD_PRICE.keys()
	gold_tiers.sort()
	for tier in gold_tiers:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(280, 44)
		btn.add_theme_font_size_override("font_size", 15)
		btn.pressed.connect(func(): _on_gold_buy(tier))
		gp_box.add_child(btn)
		_gold_buy_buttons[tier] = btn

	# Consumable shop — level-gated at Lv5 (whole section) and Lv10 (xp_boost).
	var consumable_panel := PanelContainer.new()
	right.add_child(consumable_panel)
	var cp_margin := MarginContainer.new()
	cp_margin.add_theme_constant_override("margin_left", 16)
	cp_margin.add_theme_constant_override("margin_right", 16)
	cp_margin.add_theme_constant_override("margin_top", 12)
	cp_margin.add_theme_constant_override("margin_bottom", 12)
	consumable_panel.add_child(cp_margin)
	var cp_box := VBoxContainer.new()
	cp_box.add_theme_constant_override("separation", 8)
	cp_margin.add_child(cp_box)

	var cp_title := Label.new()
	cp_title.text = "소비 아이템"
	cp_title.add_theme_font_size_override("font_size", 18)
	cp_box.add_child(cp_title)

	_consumable_lock_label = Label.new()
	_consumable_lock_label.add_theme_font_size_override("font_size", 13)
	_consumable_lock_label.modulate = Color(0.7, 0.75, 0.85)
	cp_box.add_child(_consumable_lock_label)

	_consumable_section = cp_box

	var consumable_items: Array = [
		["luck_charm",  "행운 부적",   Economy.LUCK_CHARM_COST],
		["xp_boost",    "XP 부스터",   Economy.XP_BOOST_COST],
		["combo_insure","콤보 보험",   Economy.COMBO_INSURE_COST],
	]
	for entry in consumable_items:
		var row := _make_consumable_row(entry[0], entry[1], entry[2])
		cp_box.add_child(row)

	# Status text
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 15)
	right.add_child(_status_label)


func _make_counter(initial: String, color: Color) -> Label:
	var l := Label.new()
	l.text = initial
	l.add_theme_font_size_override("font_size", 16)
	l.modulate = color
	return l


func _make_consumable_row(id: String, item_name: String, cost: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var color: Color = { "luck_charm": Color(0.5, 0.9, 0.5), "xp_boost": Color(1.0, 0.85, 0.3), "combo_insure": Color(1.0, 0.5, 0.35) }.get(id, Color.WHITE)
	row.add_child(Icons.make(id, color, 22))
	var lbl := Label.new()
	lbl.text = item_name
	lbl.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(lbl)
	var btns: Array = []
	if cost.has("shards"):
		var b := Button.new()
		b.text = "파편 %d" % int(cost["shards"])
		b.pressed.connect(func(): _buy_consumable(id, "shards"))
		row.add_child(b)
		btns.append(b)
	if cost.has("gold"):
		var b2 := Button.new()
		b2.text = "골드 %d" % int(cost["gold"])
		b2.pressed.connect(func(): _buy_consumable(id, "gold"))
		row.add_child(b2)
		btns.append(b2)
	_consumable_buttons[id] = btns
	return row


func _buy_consumable(id: String, pay: String) -> void:
	var r := ProgressStore.buy_consumable(id, pay)
	if r.get("ok", false):
		_status_label.text = "✅ 구매 완료"
		_status_label.modulate = Color(0.6, 1.0, 0.7)
	else:
		_status_label.text = "구매 실패: %s" % str(r.get("reason", ""))
		_status_label.modulate = Color(1, 0.6, 0.6)
	_refresh()


# Returns the minimum player level at which `tier` becomes purchasable.
# Mirrors the thresholds in Economy.max_buyable_sword_level().
func _sword_unlock_level(tier: int) -> int:
	if tier <= 5:
		return 5
	if tier <= 9:
		return 10
	return 20


func _refresh() -> void:
	var lv := ProgressStore.get_weapon_level()
	var gold := ProgressStore.get_gold()
	var shards := ProgressStore.get_shards()
	_tickets_label.text = "강화권 %d" % ProgressStore.get_enhance_tickets()
	_gold_label.text = "골드 %d" % gold
	_scrolls_label.text = "주문서 %d" % ProgressStore.get_protection_scrolls()
	_shards_label.text = "파편 %d" % shards

	var price := SwordStore.sell_price(lv)
	_sell_button.text = "+%d 검 팔기  (+%d G)" % [lv, price]
	_sell_button.disabled = false

	# Scroll bundles — per-scroll unit price shown in parentheses so the
	# discount is visible at a glance.
	for qty in _scroll_buttons.keys():
		var b: Button = _scroll_buttons[qty]
		var cost: int = int(ProgressStore.SCROLL_BUNDLES[qty])
		var unit_g: float = float(cost) / float(qty)
		b.text = "주문서 %d개 구매  (-%d G  /  장당 %dG)" % [qty, cost, roundi(unit_g)]
		b.disabled = gold < cost

	# Refresh exchange + gold buttons with level gating.
	var player_level: int = ProgressStore.get_level()
	var max_sword: int = Economy.max_buyable_sword_level(player_level)

	# Tiers below player's current sword are still clickable (a downgrade the
	# player chose to pay for). Tiers above max_buyable_sword_level are locked.
	for tier in _exchange_buttons.keys():
		var ebtn: Button = _exchange_buttons[tier]
		var cost_e: int = int(ProgressStore.SHARD_EXCHANGE[tier])
		if tier > max_sword:
			var unlock_lv: int = _sword_unlock_level(tier)
			ebtn.text = "+%d 검 교환  (-%d 파편)  🔒 Lv%d 해금" % [tier, cost_e, unlock_lv]
			ebtn.disabled = true
		else:
			ebtn.text = "+%d 검 교환  (-%d 파편)" % [tier, cost_e]
			ebtn.disabled = shards < cost_e
	for tier in _gold_buy_buttons.keys():
		var gbtn: Button = _gold_buy_buttons[tier]
		var cost_g: int = int(ProgressStore.SWORD_GOLD_PRICE[tier])
		if tier > max_sword:
			var unlock_lv: int = _sword_unlock_level(tier)
			gbtn.text = "+%d 검 구매  (-%d G)  🔒 Lv%d 해금" % [tier, cost_g, unlock_lv]
			gbtn.disabled = true
		else:
			gbtn.text = "+%d 검 구매  (-%d G)" % [tier, cost_g]
			gbtn.disabled = gold < cost_g

	# ── Level-gated consumable shop
	var shop_open: bool = Economy.consumable_shop_unlocked(player_level)
	if shop_open:
		_consumable_lock_label.text = ""
		_consumable_lock_label.visible = false
	else:
		_consumable_lock_label.text = "🔒 Lv%d에 해금" % Economy.UNLOCK_CONSUMABLE_SHOP
		_consumable_lock_label.visible = true
	var xp_boost_open: bool = Economy.xp_boost_unlocked(player_level)
	# Rebuild consumable button labels and disabled state from the cost dicts
	# so we never accumulate stale lock-hint text.
	var consumable_costs: Dictionary = {
		"luck_charm": Economy.LUCK_CHARM_COST,
		"xp_boost":   Economy.XP_BOOST_COST,
		"combo_insure": Economy.COMBO_INSURE_COST,
	}
	for cid in _consumable_buttons.keys():
		var row_btns: Array = _consumable_buttons[cid]
		var cost_dict: Dictionary = consumable_costs.get(cid, {})
		var pay_keys: Array = cost_dict.keys()
		for i in row_btns.size():
			var cbtn: Button = row_btns[i]
			var pay_key: String = pay_keys[i]
			var amount: int = int(cost_dict[pay_key])
			var label_prefix: String = ("파편" if pay_key == "shards" else "골드") + " %d" % amount
			if not shop_open:
				cbtn.text = label_prefix
				cbtn.disabled = true
			elif cid == "xp_boost" and not xp_boost_open:
				cbtn.text = label_prefix + "  🔒 Lv%d" % Economy.UNLOCK_XP_BOOST
				cbtn.disabled = true
			else:
				cbtn.text = label_prefix
				var can_afford: bool = (shards if pay_key == "shards" else gold) >= amount
				cbtn.disabled = not can_afford


func _on_sell() -> void:
	var lv := ProgressStore.get_weapon_level()
	var result := ProgressStore.sell_current_sword()
	if result.get("ok", false):
		_status_label.text = "💰 +%d 검을 %d G에 판매 — 새 +0 검 지급" % [lv, int(result.get("price", 0))]
		_status_label.modulate = Color(0.6, 1.0, 0.7)


func _on_buy_scroll(qty: int) -> void:
	var result := ProgressStore.buy_scroll_bundle(qty)
	if result.get("ok", false):
		_status_label.text = "📜 주문서 %d개 구매 (-%dG, 보유 %d개)" % [
			int(result.get("qty", qty)),
			int(result.get("cost", 0)),
			int(result.get("scrolls", 0)),
		]
		_status_label.modulate = Color(0.85, 0.7, 1.0)
	else:
		_status_label.text = "골드가 부족합니다"
		_status_label.modulate = Color(1, 0.6, 0.6)


func _on_gold_buy(target_level: int) -> void:
	var result := ProgressStore.buy_sword_with_gold(target_level)
	if result.get("ok", false):
		_status_label.text = "⚔ +%d 검 구매 완료 (-%dG)" % [
			target_level, int(result.get("gold_spent", 0)),
		]
		_status_label.modulate = Color(1.0, 0.85, 0.3)
	else:
		var reason: String = result.get("reason", "")
		if reason == "not_enough_gold":
			_status_label.text = "골드가 부족합니다 (필요 %d G)" % int(result.get("cost", 0))
		else:
			_status_label.text = "구매 실패: %s" % reason
		_status_label.modulate = Color(1, 0.6, 0.6)


func _on_exchange(target_level: int) -> void:
	var result := ProgressStore.exchange_shards_for_sword(target_level)
	if result.get("ok", false):
		_status_label.text = "⚒ +%d 검 교환 완료 (파편 %d 사용)" % [
			target_level, int(result.get("shards_spent", 0)),
		]
		_status_label.modulate = Color(0.95, 0.6, 0.55)
	else:
		var reason: String = result.get("reason", "")
		if reason == "not_enough_shards":
			_status_label.text = "파편이 부족합니다 (필요 %d개)" % int(result.get("cost", 0))
		else:
			_status_label.text = "교환 실패: %s" % reason
		_status_label.modulate = Color(1, 0.6, 0.6)


func _go_home() -> void:
	get_tree().change_scene_to_file("res://scenes/Home.tscn")
