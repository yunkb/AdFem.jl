using PoreFlow

# filename = "/Users/tiffan/Desktop/Research/Physics_Informed_ML/ANSYS/VS_code/PoreFlow.jl/docs/src/codes/ChipUnstructured/mesh/mesh_file_CHT2D.msh"
# filename = "/Users/tiffan/Desktop/Research/Physics_Informed_ML/ANSYS/VS_code/PoreFlow.jl/docs/src/codes/ChipUnstructured/mesh/mesh_file_CHT2D_v01.msh"
# file_format = "ansys"

filename = "/Users/tiffan/Desktop/Research/Physics_Informed_ML/ANSYS/VS_code/PoreFlow.jl/docs/src/codes/ChipUnstructured/mesh/CHT_2D.stl"
 file_format = "stl"

meshio = PoreFlow.get_meshio()
mesh = meshio.read(filename, file_format = file_format)
mesh.points[:,1:2]
mesh.cells[1][2] .+ 1

mesh = Mesh(filename = filename, file_format = file_format)
visualize_mesh(mesh)
savefig("mesh.png")