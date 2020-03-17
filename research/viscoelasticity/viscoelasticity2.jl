using Revise
using PoreFlow
using PyCall
using LinearAlgebra
using PyPlot
using SparseArrays
using MAT
np = pyimport("numpy")


mode = "training"

## alpha-scheme
β = 1/4; γ = 1/2
a = b = 0.1

n = 10
m = 2n 
h = 0.01
NT = 500
it0 = 1
Δt = 2.0/NT
ηmax = 1
ηmin = 0.5

bdedge = bcedge("right", m, n, h)
bdnode = bcnode("lower", m, n, h)

# λ = Variable(1.0)
# μ = Variable(1.0)
# invη = Variable(1.0)

function eta_model(idx)
  if idx == 1
    out = ηmin * ones(n)
    out[1:div(n,3)] .= ηmax
    out
  elseif idx==2
    out = 1.0 * ones(n)
    out[1:div(n,3)] .= 3.0
    out[2div(n,3):end] .= 3.0
    out[:]
  elseif idx==3
    out = 0.1 * ones(n)
    out[2div(n,3):end] .= 0.3
    out[:]
  end
end

function visualize_inv_eta(X1, X2, X3, k)
    x = LinRange(0.5h,m*h, m)
    y = LinRange(0.5h,n*h, n)
    V1 = zeros(m, n)
    V2 = zeros(m, n)
    V3 = zeros(m, n)
    for i = 1:m  
        for j = 1:n 
            elem = (j-1)*m + i 
            V1[i, j] = mean(X1[4(elem-1)+1:4elem])
            V2[i, j] = mean(X2[4(elem-1)+1:4elem])
            V3[i, j] = mean(X3[4(elem-1)+1:4elem])
        end
    end
    close("all")
    figure(figsize=(15,4))
    subplot(131)
    pcolormesh(x, y, V1'/50.0, vmin=ηmin-(ηmax-ηmin)/4, vmax=ηmax+(ηmax-ηmin)/4)
    colorbar(shrink=0.5)
    xlabel("x")
    ylabel("y")
    axis("scaled")
    gca().invert_yaxis()
    if k == "true"
      title("True Model")
      savefig("true.png") 
    else
      k_ = string(k)
      k_ = reduce(*, "0" for i = 1:4-length(k_))*k_
      title("Iteration = $k_")
    end

    subplot(132)
    pcolormesh(x, y, V2', vmin=0.5, vmax=3.5)
    colorbar(shrink=0.5)
    xlabel("x")
    ylabel("y")
    axis("scaled")
    gca().invert_yaxis()
    if k == "true"
      title("True Model")
      savefig("true.png")
    else
      k_ = string(k)
      k_ = reduce(*, "0" for i = 1:4-length(k_))*k_
      title("Iteration = $k_")
    end

    subplot(133)
    pcolormesh(x, y, V3', vmin=0.05, vmax=0.35)
    colorbar(shrink=0.5)
    xlabel("x")
    ylabel("y")
    axis("scaled")
    gca().invert_yaxis()
    if k == "true"
      title("True Model")
      savefig("true.png")
    else 
      k_ = string(k)
      k_ = reduce(*, "0" for i = 1:4-length(k_))*k_
      title("Iteration = $k_")
      savefig("iter$k_.png")
    end
    
    
end

if mode=="data"
  global invη_var = constant(eta_model(1))
  invη = reshape(repeat(invη_var, 1, 4m), (-1,))
  global invη *= 50.0
  global λ_var = constant(eta_model(2))
  global μ_var = constant(eta_model(3))
  global λ = reshape(repeat(λ_var, 1, 4m), (-1,))
  global μ = reshape(repeat(μ_var, 1, 4m), (-1,))
else
    global invη_var = Variable((ηmin + ηmax)/2*ones(n))
    global λ_var = Variable(2.0*ones(n))
    global μ_var = Variable(0.2*ones(n))

    # global invη_var = placeholder(eta_model(1))
    # global λ_var = placeholder(eta_model(2))
    # global μ_var = placeholder(eta_model(3))


    invη_ = reshape(repeat(invη_var, 1, 4m), (-1,))
    global invη = 50.0*invη_
    global λ = reshape(repeat(λ_var, 1, 4m), (-1,))
    global μ = reshape(repeat(μ_var, 1, 4m), (-1,))
end


fn_G = o->begin 
  λ, μ,invη = o
  G = tensor([1/Δt+μ*invη -μ/3*invη 0.0
    -μ/3*invη 1/Δt+μ*invη-μ/3*invη 0.0
    0.0 0.0 1/Δt+μ*invη])
  invG = inv(G)
  S = tensor([2μ/Δt+λ/Δt λ/Δt 0.0
    λ/Δt 2μ/Δt+λ/Δt 0.0
    0.0 0.0 μ/Δt])
  invG, S 
end
invG, S = tf.map_fn(fn_G, (λ, μ,invη), dtype=(tf.float64, tf.float64))

H = batch_matmul(invG,S)


M = compute_fem_mass_matrix1(m, n, h)
Zero = spzeros((m+1)*(n+1), (m+1)*(n+1))
M = SparseTensor([M Zero;Zero M])

K = compute_fem_stiffness_matrix(H, m, n, h)
C = a*M + b*K # damping matrix 
L = M + γ*Δt*C + β*Δt^2*K
L, Lbd = fem_impose_Dirichlet_boundary_condition_experimental(L, bdnode, m, n, h)


a = TensorArray(NT+1); a = write(a, 1, zeros(2(m+1)*(n+1))|>constant)
v = TensorArray(NT+1); v = write(v, 1, zeros(2(m+1)*(n+1))|>constant)
d = TensorArray(NT+1); d = write(d, 1, zeros(2(m+1)*(n+1))|>constant)
U = TensorArray(NT+1); U = write(U, 1, zeros(2(m+1)*(n+1))|>constant)
Sigma = TensorArray(NT+1); Sigma = write(Sigma, 1, zeros(4*m*n, 3)|>constant)
Varepsilon = TensorArray(NT+1); Varepsilon = write(Varepsilon, 1,zeros(4*m*n, 3)|>constant)


Forces = zeros(NT, 2(m+1)*(n+1))
for i = 1:NT
  T = eval_f_on_boundary_edge((x,y)->0.1, bdedge, m, n, h)

  # if i>=NT÷2
  #   T *= 0.0
  # end
  T = [-T T]
#   T = [T T]
  rhs = compute_fem_traction_term(T, bdedge, m, n, h)

#   if i*Δt>0.5
#     rhs = zero(rhs)
#   end
  Forces[i, :] = rhs
end
Forces = constant(Forces)

function condition(i, tas...)
  i <= NT
end

function body(i, tas...)
  a_, v_, d_, U_, Sigma_, Varepsilon_ = tas
  a = read(a_, i)
  v = read(v_, i)
  d = read(d_, i)
  U = read(U_, i)
  Sigma = read(Sigma_, i)
  Varepsilon = read(Varepsilon_, i)

  res = batch_matmul(invG/Δt, Sigma)
  F = compute_strain_energy_term(res, m, n, h) - K * U
  rhs = Forces[i] - Δt^2 * F

  td = d + Δt*v + Δt^2/2*(1-2β)*a 
  tv = v + (1-γ)*Δt*a 
  rhs = rhs - C*tv - K*td
  rhs = scatter_update(rhs, constant([bdnode; bdnode.+(m+1)*(n+1)]), constant(zeros(2*length(bdnode))))


  ## alpha-scheme
  a = L\rhs # bottleneck  
  d = td + β*Δt^2*a 
  v = tv + γ*Δt*a 
  U_new = d

  Varepsilon_new = eval_strain_on_gauss_pts(U_new, m, n, h)

  res2 = batch_matmul(invG * S, Varepsilon_new-Varepsilon)
  Sigma_new = res +  res2

  i+1, write(a_, i+1, a), write(v_, i+1, v), write(d_, i+1, d), write(U_, i+1, U_new),
        write(Sigma_, i+1, Sigma_new), write(Varepsilon_, i+1, Varepsilon_new)
end


i = constant(1, dtype=Int32)
_, _, _, _, u, sigma, varepsilon = while_loop(condition, body, 
                  [i, a, v, d, U, Sigma, Varepsilon])

U = stack(u)
Sigma = stack(sigma)
Varepsilon = stack(varepsilon)

if mode!="data"
  data = matread("viscoelasticity.mat")
  global Uval,Sigmaval, Varepsilonval = data["U"], data["Sigma"], data["Varepsilon"]
  U.set_shape((NT+1, size(U, 2)))
  idx0 = 1:4m*n
  Sigma = map(x->x[idx0,:], Sigma)

  idx = collect(1:m+1)
  global loss = sum((U[it0:end, idx] - Uval[it0:end, idx])^2) 
end

sess = Session(); init(sess)
# @show run(sess, loss) #step1 
# lineview(sess, μ_var, loss, eta_model(3), 0.2*ones(n))
# gradview(sess, μ_var, loss, 0.2*ones(n))

# error()
cb = (v, i, l)->begin
  println("[$i] loss = $l")
  if i=="true" || mod(i, 10)==0
    inv_eta, λ, μ = v[1], v[2], v[3]
    visualize_inv_eta(inv_eta,λ, μ, i)
  end
end

if mode=="data"
  Uval,Sigmaval, Varepsilonval = run(sess, [U, Sigma, Varepsilon])
  matwrite("viscoelasticity.mat", Dict("U"=>Uval, "Sigma"=>Sigmaval, "Varepsilon"=>Varepsilonval))

  visualize_von_mises_stress(Sigmaval, m, n, h, name="_viscoelasticity")
  visualize_scattered_displacement(Array(Uval'), m, n, h, name="_viscoelasticity", 
                  xlim_=[-2h, m*h+2h], ylim_=[-2h, n*h+2h])

  close("all")
  plot(LinRange(0, 20, NT+1), Uval[:,m+1])
  xlabel("Time")
  ylabel("Displacement")
  savefig("disp.png")

  cb(run(sess, [invη, λ, μ]), "true", 0.0)
  error("Stop!")
end

# BFGS!(sess, loss)
# @info run(sess, loss, invη_var=>eta_model(1))

# dat = linedata(eta_model(1), (ηmin + ηmax)/2*ones(n))
# V = zeros(length(dat))
# for i = 1:length(dat)
#   @info i 
#   V[i] = run(sess, loss, invη_var=>dat[i])
# end
# close("all")
# lineview(V)
# savefig("line")

# close("all")
# gradview(sess, invη_var, gradients(loss, invη_var), loss, (ηmin + ηmax)/2*ones(n))
# savefig("line")
v_ = []
i_ = []
l_ = []
cb(run(sess, [invη, λ, μ]), 0, run(sess, loss))
loss_ = BFGS!(sess, loss*1e10, vars=[invη, λ, μ], callback=cb, var_to_bounds=Dict(invη_var=>(0.1,2.0)))