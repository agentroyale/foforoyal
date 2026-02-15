class_name ItemData
extends Resource
## Base data for all items: resources, tools, weapons, building materials.

enum Category {
	RESOURCE,
	TOOL,
	WEAPON,
	BUILDING,
	MISC,
}

@export var item_name: String = ""
@export var description: String = ""
@export var icon: Texture2D
@export var max_stack_size: int = 1
@export var category: Category = Category.MISC
