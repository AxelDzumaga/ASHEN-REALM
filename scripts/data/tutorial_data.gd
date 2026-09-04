class_name TutorialData
extends RefCounted

enum Priority {
	LOW = 0,
	NORMAL = 10,
	HIGH = 20,
	CORE = 30,
}

var id: StringName
var title: String
var body: String
var priority: Priority


func _init(
	tutorial_id: StringName,
	tutorial_title: String,
	tutorial_body: String,
	tutorial_priority: Priority = Priority.NORMAL,
) -> void:
	id = tutorial_id
	title = tutorial_title
	body = tutorial_body
	priority = tutorial_priority
