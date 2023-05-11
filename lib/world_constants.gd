extends Node


const ColorDictionary = {
	GREEN = Color(0, 0, 0.57),
	RED = Color(0.87, 0.09, 0.16),
}
const COLLISION_ALL_OFF = 0x0000
const CollisionLayer = {
	PLAYER = 0,
	ENVIRONMENT = 1,
}

var MaterialMap = {}
