@tool
extends MeshInstance3D

@export	var MATERIAL:Material
@export var RESOLUTION:int = 64
@export var LAND_POINT:int = 32
@export var ISO_LEVEL := 0.0
@export var FLAT_SHADED := false
@export var TERRAIN_TERRACE:int = 1

@export var BASE_NOISE: FastNoiseLite
@export var LANDMASS_NOISE: FastNoiseLite
@export var REGION_NOISE: FastNoiseLite
@export var HILL_NOISE: FastNoiseLite

var TIME: int = 0

@export var GENERATE: bool:
	set(value):
		TIME = Time.get_ticks_msec()
		generate()
		var elapsed = (Time.get_ticks_msec()-TIME)/1000.0
		print("Terrain generated in: " + str(elapsed) + "s")

class VoxelGrid:
	var data: PackedFloat32Array
	var resolution: int
	
	func _init(tResolution: int):
		self.resolution = tResolution
		self.data.resize(resolution*resolution*resolution)
		self.data.fill(1.0) # 1 is Outside Mesh
	
	func read(x: int, y: int, z: int):
		return self.data[x + self.resolution * (y + self.resolution * z)]
	
	func write(x: int, y: int, z: int, value: float):
		self.data[x + self.resolution * (y + self.resolution * z)] = value
	
	
func scalar_field(x:float, y:float, z:float):
	return (x * x + y * y + z * z)/60.0

func generate():
	
	var elapsed = (Time.get_ticks_msec()-TIME)/1000.0
	print("1: " + str(elapsed) + "s")
	var voxel_grid = VoxelGrid.new(RESOLUTION)
	#generate terrain
	for x in range(1, voxel_grid.resolution-1):
		for y in range(1, voxel_grid.resolution-1):
			for z in range(1, voxel_grid.resolution-1):
				var value = GetValue(x,y,z);
				voxel_grid.write(x, y, z, value)
	
	elapsed = (Time.get_ticks_msec()-TIME)/1000.0
	print("2: " + str(elapsed) + "s")
	#march
	var vertices = PackedVector3Array()
	for x in voxel_grid.resolution-1:
		for y in voxel_grid.resolution-1:
			for z in voxel_grid.resolution-1:
				march_cube(x, y, z, voxel_grid, vertices)
	elapsed = (Time.get_ticks_msec()-TIME)/1000.0
	print("3: " + str(elapsed) + "s")
	#draw
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	elapsed = (Time.get_ticks_msec()-TIME)/1000.0
	print("4: " + str(elapsed) + "s")
	if FLAT_SHADED:
		surface_tool.set_smooth_group(-1)
	
	for vert in vertices:
		surface_tool.add_vertex(vert)
	
	surface_tool.generate_normals()
	surface_tool.index()
	surface_tool.set_material(MATERIAL)
	
	mesh = surface_tool.commit()
	# TODO: Generate Collider
	# create_trimesh_collision();
		
func march_cube(x:int, y:int, z:int, voxel_grid:VoxelGrid, vertices:PackedVector3Array):
	var tri = get_triangulation(x, y, z, voxel_grid)
	for edge_index in tri:
		if edge_index < 0: break
		var point_indices = MarchingCubeConstants.EDGES[edge_index]
		var p0 = MarchingCubeConstants.POINTS[point_indices.x]
		var p1 = MarchingCubeConstants.POINTS[point_indices.y]
		var pos_a = Vector3(x+p0.x, y+p0.y, z+p0.z)
		var pos_b = Vector3(x+p1.x, y+p1.y, z+p1.z)
		
		var position = calculate_interpolation(pos_a, pos_b, voxel_grid)
		vertices.append(position)

func calculate_interpolation(a:Vector3, b:Vector3, voxel_grid:VoxelGrid):
	var val_a = voxel_grid.read(a.x, a.y, a.z)
	var val_b = voxel_grid.read(b.x, b.y, b.z)
	var t = (ISO_LEVEL - val_a)/(val_b-val_a)
	return a+t*(b-a)
		
func get_triangulation(x:int, y:int, z:int, voxel_grid:VoxelGrid):
	var idx = 0b00000000
	idx |= int(voxel_grid.read(x, y, z) < ISO_LEVEL)<<0
	idx |= int(voxel_grid.read(x, y, z+1) < ISO_LEVEL)<<1
	idx |= int(voxel_grid.read(x+1, y, z+1) < ISO_LEVEL)<<2
	idx |= int(voxel_grid.read(x+1, y, z) < ISO_LEVEL)<<3
	idx |= int(voxel_grid.read(x, y+1, z) < ISO_LEVEL)<<4
	idx |= int(voxel_grid.read(x, y+1, z+1) < ISO_LEVEL)<<5
	idx |= int(voxel_grid.read(x+1, y+1, z+1) < ISO_LEVEL)<<6
	idx |= int(voxel_grid.read(x+1, y+1, z) < ISO_LEVEL)<<7
	return MarchingCubeConstants.TRIANGULATIONS[idx]

func GetValue(x:int, y:int, z:int):
	var distanceToCenter = Vector3(x,y,z).distance_to(Vector3(RESOLUTION/2,RESOLUTION/2,RESOLUTION/2)) / (RESOLUTION/2)
	
	var value = abs(BASE_NOISE.get_noise_2d(x,z))
	value = (1 - distanceToCenter) * value;
	
	var base_value = distanceToCenter - value
	if y < LAND_POINT :
		return base_value;
	return 1;

func _ready():
	generate()
