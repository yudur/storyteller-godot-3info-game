class_name StoryData
extends Resource

@export var id: String
@export var title: String
@export var number_of_frames: int
@export var draggable_items: Array[Resource] = []
# Script extending StoryLogic that decides poses, backgrounds and the solution
@export var logic: Script
