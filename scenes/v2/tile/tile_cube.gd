class_name TileCube extends Tile

@onready var cube = $CSGBox3D
@onready var label = $Label3D


func _ready():
	assert(cube.material != null, "TileCube " + name + " is missing a material")


func _set_label_text(text: String):
	label.text = text
