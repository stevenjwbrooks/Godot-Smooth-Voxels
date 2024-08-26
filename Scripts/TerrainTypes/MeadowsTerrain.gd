extends "res://Scripts/Terrain.gd"

func GetValue(x:int, y:int, z:int):
	TERRAIN_TERRACE = 1;
	return BASE_NOISE.get_noise_3d(x, y, z)+(y+y%TERRAIN_TERRACE)/float(RESOLUTION)-0.5

func _ready():
	generate()
