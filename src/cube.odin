package main
cubePositions := [TOTAL_VERTICES]float3 {
	// front face
	{-0.5, -0.5, 0.5}, // Front bottom left  (0)
	{0.5, -0.5, 0.5}, // Front bottom right (1)
	{0.5, 0.5, 0.5}, // Front top right    (2)
	{-0.5, 0.5, 0.5}, // Front top left     (3)

	// back face
	{-0.5, -0.5, -0.5}, // Back bottom left   (4)
	{-0.5, 0.5, -0.5}, // Back top left      (5)
	{0.5, 0.5, -0.5}, // Back top right     (6)
	{0.5, -0.5, -0.5}, // Back bottom right  (7)

	// right face
	{0.5, -0.5, -0.5}, // Right bottom back  (8)
	{0.5, 0.5, -0.5}, // Right top back     (9)
	{0.5, 0.5, 0.5}, // Right top front    (10)
	{0.5, -0.5, 0.5}, // Right bottom front (11)

	// left face
	{-0.5, -0.5, 0.5}, // Left bottom front  (12)
	{-0.5, 0.5, 0.5}, // Left top front     (13)
	{-0.5, 0.5, -0.5}, // Left top back      (14)
	{-0.5, -0.5, -0.5}, // Left bottom back   (15)

	// top face
	{-0.5, 0.5, -0.5}, // Top back left      (16)
	{0.5, 0.5, -0.5}, // Top back right     (17)
	{0.5, 0.5, 0.5}, // Top front right    (18)
	{-0.5, 0.5, 0.5}, // Top front left     (19)
	{-0.5, -0.5, 0.5}, // Bottom front left  (20)
	{-0.5, -0.5, -0.5}, // Bottom back left   (21)
	{0.5, -0.5, -0.5}, // Bottom back right  (22)
	{0.5, -0.5, 0.5}, // Bottom front right (23)
}

cubeColors := [TOTAL_VERTICES]float3 {
	// front face
	{0, 0, 0}, // Front bottom left  (0)
	{0, 0, 0}, // Front bottom right (1)
	{0, 0, 0}, // Front top right    (2)
	{0, 0, 0}, // Front top left     (3)

	// back face
	{1, 0, 0}, // Back bottom left   (4)
	{1, 0, 0}, // Back top left      (5)
	{1, 0, 0}, // Back top right     (6)
	{1, 0, 0}, // Back bottom right  (7)

	// right face
	{1, 1, 0}, // Right bottom back  (8)
	{1, 1, 0}, // Right top back     (9)
	{1, 1, 0}, // Right top front    (10)
	{1, 1, 0}, // Right bottom front (11)

	// left face
	{1, 0, 1}, // Left bottom front  (12)
	{1, 0, 1}, // Left top front     (13)
	{1, 0, 1}, // Left top back      (14)
	{1, 0, 1}, // Left bottom back   (15)

	// top face
	{1, .5, .5}, // Top back left      (16)
	{1, .5, .5}, // Top back right     (17)
	{1, .5, .5}, // Top front right    (18)
	{1, .5, .5}, // Top front left     (19)

	//bottom face
	{1, .8, .8}, // Bottom front left  (20)
	{1, .8, .8}, // Bottom back left   (21)
	{1, .8, .8}, // Bottom back right  (22)
	{1, .8, .8}, // Bottom front right (23)
}
cubeUV := [TOTAL_VERTICES]float2 {
	//front
	{0, 0},
	{1, 0},
	{1, 1},
	{0, 1},
	//back
	{0, 0},
	{1, 0},
	{1, 1},
	{0, 1},
	//right
	{0, 0},
	{1, 0},
	{1, 1},
	{0, 1},
	//left
	{0, 0},
	{1, 0},
	{1, 1},
	{0, 1},
	//top
	{0, 0},
	{1, 0},
	{1, 1},
	{0, 1},
	//bottom
	{0, 0},
	{1, 0},
	{1, 1},
	{0, 1},
}

cubeIndices := [36]u16 {
	// Front face 
	0,
	1,
	2,
	0,
	2,
	3,
	// Back face 
	4,
	5,
	6,
	4,
	6,
	7,
	// Right facet
	8,
	9,
	10,
	8,
	10,
	11,
	// Left face 
	12,
	13,
	14,
	12,
	14,
	15,
	// Top face
	16,
	17,
	18,
	16,
	18,
	19,
	// Bottom face 
	20,
	21,
	22,
	20,
	22,
	23,
}
