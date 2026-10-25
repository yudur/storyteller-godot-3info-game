class_name SceneData
extends Resource

@export var id: String
@export var display_name: String

# Variant name -> background. "default" is required; story logic picks the others by context
@export var variants: Dictionary[String, Texture2D] = {}

func get_variant(key: String) -> Texture2D:
	if variants.has(key):
		return variants[key]
	if variants.has("default"):
		return variants["default"]

	push_warning("SceneData '%s' has no variant '%s' nor 'default'" % [id, key])
	return null
