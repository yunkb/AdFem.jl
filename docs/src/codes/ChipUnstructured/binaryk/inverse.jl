using ADCME
using AdFem

include("../chip_unstructured_solver.jl")
include("../chip_unstructured_geometry.jl")
include("../plot_inverse_one_iter.jl")

trialnum = 7

k_mold = 0.014531
k_chip_ref = 2.60475
k_air = 0.64357

function k_exact(x, y)
    k_mold + (x>0.49 && x<0.5) * k_chip_ref
end

function k_nn(x, y) # exact solution + nn: change to nn solution?
    c = 100           # hyperparameter to control shape of sigmoid function
    out = fc(x, [20,20,20,1])
    k_mold + sigmoid(c * out) * k_chip_ref
end

xy = mesh.nodes 
xy2 = zeros(mesh.nedge, 2)
for i = 1:mesh.nedge
    xy2[i,:] = (mesh.nodes[mesh.edges[i,1], :] + mesh.nodes[mesh.edges[i,2], :])/2
end
xy = [xy;xy2]

x, y = xy[chip_fem_idx, 1], xy[chip_fem_idx, 2]
k_chip_exact = constant( @. k_exact(x, y) )
k_chip = k_nn(x, y)

nu = 0.47893  # equal to 1/Re
power_source = 82.46295  #82.46295 = 1.0e6 divide by air rho cp   #0.0619 = 1.0e6 divide by chip die rho cp
buoyance_coef = 299102.83

u_std = 0.001
p_std = 0.000001225
T_infty = 300

NT = 15    # number of iterations for Newton's method

heat_source_fem = zeros(ndof)
heat_source_fem[chip_fem_top_idx] .= power_source
heat_source_gauss = dof_to_gauss_points(heat_source_fem, mesh)

B = constant(compute_interaction_matrix(mesh))
Laplace = constant(compute_fem_laplace_matrix1(nu * constant(ones(ngauss)), mesh))
heat_source = compute_fem_source_term1(constant(heat_source_gauss), mesh)

# apply Dirichlet to velocity and temperature; set left bottom two points to zero to fix rank deficient problem for pressure
bd = [bd; bd .+ ndof; 
      fvm_bd .+ 2*ndof; 
      bd .+ (2*ndof+nelem)]

# add solid region into boundary condition for u, v, p, i.e. exclude solid when solving Navier Stokes
bd = [bd; solid_fem_idx; solid_fem_idx .+ ndof; solid_fvm_idx .+ 2*ndof]

S0 = constant(zeros(nelem+3*ndof))
S = solve_navier_stokes(S0, NT, k_chip)
S_computed = S[end, :]
S_data = matread("data.mat")["V"]

loss =  mean((S_computed .- S_data)^2)
loss = loss * 1e10

# ---------------------------------------------------
_loss = Float64[]
cb = (vs, iter, loss)->begin 
    global _loss
    push!(_loss, loss)
    printstyled("[#iter $iter] loss=$loss\n", color=:green)
    # if mod(iter, 1)==1
    close("all")
    plot_cond(iter, vs[1][1:length(chip_fem_idx_nodes)])
    matwrite("fn$trialnum/loss$iter.mat", Dict("iter"=>iter,"loss"=>_loss, "k_chip"=>vs[1]))
    # end
end

ADCME.options.training.training = placeholder(true)
l = placeholder(rand(20545,))
x = placeholder(rand(5875, 2))

# train the neural network 
opt = AdamOptimizer().minimize(loss)
sess = Session(); init(sess)
for i = 1:100
    _, loss_ = run(sess, [opt, loss], feed_dict=Dict(l=>S_data, x=>xy))
    @info i, loss_
end

BFGS!(sess, loss, vars = [k_chip], callback = cb, method="BFGS")
