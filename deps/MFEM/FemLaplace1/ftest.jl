using ADCME
using LinearAlgebra
using AdFem
using DelimitedFiles

A = readdlm("fenics/A.txt")
mesh = Mesh(8,8,1/8)
ρ = constant(ones(get_ngauss(mesh)))
B1 = compute_fem_laplace_matrix1(ones(get_ngauss(mesh)), mesh)
B = compute_fem_laplace_matrix1(ρ, mesh)
sess = Session(); init(sess)
B0 = run(sess, B)
B0 = Array(B0)
@show norm(A - B0)
@info norm(B1-B0)

A = readdlm("fenics/A2.txt")
mesh = Mesh(8, 8, 1.0 / 8,degree=2)
ρ = constant(ones(get_ngauss(mesh)))
B1 = compute_fem_laplace_matrix1(ones(get_ngauss(mesh)), mesh)

B = compute_fem_laplace_matrix1(ρ, mesh)
sess = Session(); init(sess)
B0 = run(sess, B)
B0 = Array(B0)
@info norm(B1-B0)

E = Int64.(readdlm("fenics/edges.txt"))
Edof = get_edge_dof(E, mesh)
DOF = [1:mesh.nnode; Edof .+ mesh.nnode]
B0 = B0[DOF, DOF]

@show norm(A - B0)