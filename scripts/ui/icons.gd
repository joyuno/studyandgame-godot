# Lucide(ISC) SVG 아이콘을 TextureRect로 만드는 헬퍼. 이모지 대체.
class_name Icons
extends RefCounted

# 의미 이름 → Lucide 파일명
const MAP: Dictionary = {
	"luck_charm": "clover",
	"xp_boost": "zap",
	"combo_insure": "flame",
	"scroll": "scroll-text",
	"gold": "coins",
	"shards": "gem",
	"ticket": "ticket",
	"trophy": "trophy",
	"sword": "sword",
	"lock": "lock",
}

static func make(semantic: String, color: Color, size: int = 20) -> TextureRect:
	var t := TextureRect.new()
	var file: String = MAP.get(semantic, semantic)
	var path := "res://assets/icons/%s.svg" % file
	if ResourceLoader.exists(path):
		t.texture = load(path)
	t.custom_minimum_size = Vector2(size, size)
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.modulate = color
	return t
