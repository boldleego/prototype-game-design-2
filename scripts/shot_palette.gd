extends RefCounted
class_name ShotPalette

enum ShotColor { RED, BLUE, YELLOW }

const COLOR_VALUES := {
	ShotColor.RED: Color(0.95, 0.35, 0.32, 1.0),
	ShotColor.BLUE: Color(0.31, 0.64, 0.98, 1.0),
	ShotColor.YELLOW: Color(0.98, 0.8, 0.29, 1.0),
}

const EMISSION_VALUES := {
	ShotColor.RED: Color(1.0, 0.28, 0.22, 1.0),
	ShotColor.BLUE: Color(0.28, 0.56, 1.0, 1.0),
	ShotColor.YELLOW: Color(0.95, 0.58, 0.12, 1.0),
}
