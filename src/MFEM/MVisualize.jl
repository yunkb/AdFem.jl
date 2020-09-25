export visualize_mesh

"""
    visualize_mesh(mesh::Mesh) 

Visualizes the unstructured meshes. 
"""
function visualize_mesh(mesh::Mesh)
    nodes, elems = mesh.nodes, mesh.elems
    patches = PyObject[]
    for i = 1:size(elems,1)
        e = elems[i,:]
        p = plt.Polygon(nodes[e,:],edgecolor="k",lw=1,fc=nothing,fill=false)
        push!(patches, p)
    end
    p = matplotlib.collections.PatchCollection(patches, match_original=true)
    gca().add_collection(p)
    axis("scaled")
    xlabel("x")
    ylabel("y")
    gca().invert_yaxis()
end

"""
    visualize_scalar_on_fem_points(u::Array{Float64,1}, mesh::Mesh, args...;
        with_mesh::Bool = false, kwargs...)

Visualizes the nodal values `u` on the unstructured mesh `mesh`.

- `with_mesh`: if true, the unstructured mesh is also plotted. 
"""
function visualize_scalar_on_fem_points(u::Array{Float64,1}, mesh::Mesh, args...;
        with_mesh::Bool = false, kwargs...)
        # plots a finite element mesh
    function plot_fem_mesh(nodes_x, nodes_y)
        for i = 1:size(mesh.elems, 1)
            x = nodes_x[mesh.elems[i,:]]
            y = nodes_y[mesh.elems[i,:]]
            plt.fill(x, y, edgecolor="black", fill=false)
        end
    end

    # FEM data
    nodes_x = mesh.nodes[:,1]
    nodes_y = mesh.nodes[:,2]
    nodal_values = u
    elements_tris = []
    for i = 1:size(mesh.elems, 1)
        push!(elements_tris, mesh.elems[i,:] .- 1)
    end

    # create an unstructured triangular grid instance
    triangulation = matplotlib.tri.Triangulation(nodes_x, nodes_y, elements_tris)

    # plot the finite element mesh
    if with_mesh
        plot_fem_mesh(nodes_x, nodes_y)
    end

    # plot the contours
    plt.tricontourf(triangulation, nodal_values)

    # show
    colorbar()
    axis("scaled")
end


"""
    visualize_scalar_on_gauss_points(u::Array{Float64,1}, mesh::Mesh, args...;kwargs...)

Visualizes scalar values on Gauss points. For unstructured meshes, the values on each element are averaged to produce a uniform value for each element.
"""
function visualize_scalar_on_gauss_points(u::Array{Float64,1}, mesh::Mesh, args...;kwargs...)
    # FEM data
    @assert length(u) == get_ngauss(mesh)
    ngauss_per_elem = get_ngauss(mesh)÷mesh.nelem
    U = zeros(mesh.nelem)
    for i = 1:mesh.nelem
        U[i] = mean(u[(i-1)*ngauss_per_elem+1:i*ngauss_per_elem])
    end
    visualize_scalar_on_fvm_points(U, mesh, args...;kwargs...)
end

"""
    visualize_scalar_on_fvm_points(u::Array{Float64,1}, mesh::Mesh, args...;kwargs...)
"""
function visualize_scalar_on_fvm_points(u::Array{Float64,1}, mesh::Mesh, args...;kwargs...)
    @assert length(u) == mesh.nelem
    nodes_x, nodes_y = mesh.nodes[:,1], mesh.nodes[:,2]
    verts = zeros(size(mesh.elems, 1), 3, 2)
    for i = 1:size(mesh.elems, 1)
        x = nodes_x[mesh.elems[i,:]]
        y = nodes_y[mesh.elems[i,:]]
        verts[i, :, :] = [x y]
    end
    # Make the collection and add it to the plot.
    coll = matplotlib.collections.PolyCollection(verts, array=u, cmap=matplotlib.cm.jet, edgecolors="none")
    gca().add_collection(coll)
    gca().autoscale_view()
    colorbar(coll, ax=gca())
    xlabel("x")
    ylabel("y")
    axis("scaled")
end

"""
    visualize_displacement(u::Array{Float64, 1}, mmesh::Mesh)
"""
function visualize_displacement(u::Array{Float64, 1}, mmesh::Mesh)
    mesh0 = copy(mmesh)
    mesh0.nodes[:,1] = mesh0.nodes[:,1] + u[1:mmesh.nnode]
    mesh0.nodes[:,2] = mesh0.nodes[:,2] + u[mmesh.ndof+1:mmesh.ndof+mmesh.nnode]
    visualize_mesh(mesh0)
end

"""
    visualize_von_mises_stress(K::Array{Float64}, u::Array{Float64, 1}, mmesh::Mesh, args...; kwargs...)
"""
function visualize_von_mises_stress(K::Array{Float64}, u::Array{Float64, 1}, mmesh::Mesh, args...; kwargs...)
    VonMisesStress = compute_von_mises_stress_term(K, u, mmesh)
    visualize_scalar_on_gauss_points(VonMisesStress, mmesh, args...; kwargs...)
end