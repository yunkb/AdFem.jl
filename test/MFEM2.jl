using Revise
using ADCME
using PyPlot 
using AdFem 
using Test

mesh = Mesh(2, 2, 0.5)
@test mesh.nodes≈[ 0.0  0.0
                0.5  0.0
                1.0  0.0
                0.0  0.5
                0.5  0.5
                1.0  0.5
                0.0  1.0
                0.5  1.0
                1.0  1.0]

@test get_ngauss(mesh)≈24


nodes = gauss_nodes(mesh)
close("all")
visualize_mesh(mesh)
scatter(nodes[:,1], nodes[:,2])
savefig("g.png")

@test get_area(mesh)≈ones(8)*0.25/2

@PDATA
Mesh("twoholes.stl")


@testset "fem_to_gauss_points" begin 
    mesh = Mesh(10, 10, 1.0)
    x, y = mesh.nodes[:,1], mesh.nodes[:,2]
    u = @. x^2 + y
    out = fem_to_gauss_points(constant(u), mesh)
    out2 = fem_to_gauss_points(u, mesh)
    sess = Session(); init(sess)
    out1 = run(sess, out)
    @test out1≈out2
    # close("all")
    # visualize_scalar_on_gauss_points(out1, mesh)
    # savefig("test2.png")

    # close("all")
    # visualize_scalar_on_fem_points(u, mesh)
    # savefig("test.png")
end

@testset "visualize_scalar_on_fvm_points" begin 
    mesh = Mesh(10, 10, 1.0)
    u = rand(size(mesh.elems, 1))
    visualize_scalar_on_fvm_points(u, mesh)
    # close("all")
    # visualize_scalar_on_gauss_points(out1, mesh)
    # savefig("test2.png")

    # close("all")
    # visualize_scalar_on_fem_points(u, mesh)
    # savefig("test.png")
end