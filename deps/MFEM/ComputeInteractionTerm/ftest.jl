using ADCME
using LinearAlgebra
using PoreFlow
using DelimitedFiles

p = readdlm("fenics/x.txt")[:]
f = readdlm("fenics/f.txt")[:]

mesh = Mesh(8, 8, 1. /8)
f0 = compute_interaction_term(p, mesh)
sess = Session(); init(sess)
f1 = run(sess, f0)

@show norm(f - f1)
