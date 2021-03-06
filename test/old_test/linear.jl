using Revise
using AdFem
using PyCall
using LinearAlgebra
using PyPlot
using SparseArrays
np = pyimport("numpy")

β = 1/4; γ = 1/2
a = b = 0.1
m = 40
n = 20
h = 0.01
NT = 200
Δt = 5/NT 
bdedge = []
for j = 1:n 
  push!(bdedge, [(j-1)*(m+1)+m+1 j*(m+1)+m+1])
end
bdedge = vcat(bdedge...)

bdnode = Int64[]
for j = 1:n+1
  push!(bdnode, (j-1)*(m+1)+1)
end

M = compute_fem_mass_matrix1(m, n, h)
S = spzeros((m+1)*(n+1), (m+1)*(n+1))
M = [M S;S M]

H = [1.0 0.0 0.0
    0.0 1.0 0.0
    0.0 0.0 0.5]
K = compute_fem_stiffness_matrix(H, m, n, h)
C = a*M + b*K # damping matrix 

L = M + γ*Δt*C + β*Δt^2*K
L, Lbd = fem_impose_Dirichlet_boundary_condition(L, bdnode, m, n, h)

a = zeros(2(m+1)*(n+1))
v = zeros(2(m+1)*(n+1))
d = zeros(2(m+1)*(n+1))
U = zeros(2(m+1)*(n+1),NT+1)

Sigma = zeros(NT+1, 4m*n, 3)
Varepsilon = zeros(NT+1, 4m*n, 3)
for i = 1:NT 
    global a, v, d
    T = eval_f_on_boundary_edge((x,y)->0.1, bdedge, m, n, h)
    T = [T zeros(length(T))]
    rhs = compute_fem_traction_term(T, bdedge, m, n, h)
    if i*Δt>3.0
      rhs = zero(rhs)
    end

    td = d + Δt*v + Δt^2/2*(1-2β)*a 
    tv = v + (1-γ)*Δt*a 
    rhs = rhs - C*tv - K*td
    rhs[[bdnode; bdnode.+(m+1)*(n+1)]] .= 0.0

    a = L\rhs 
    d = td + β*Δt^2*a 
    v = tv + γ*Δt*a 
    U[:,i+1] = d


    Varepsilon[i+1,:,:] = eval_strain_on_gauss_pts(U[:,i+1], m, n, h)
    Sigma[i+1,:,:] = Varepsilon[i+1,:,:] * H
end


visualize_displacement(U, m, n, h; name = "_linear", xlim_=[-0.01,0.5], ylim_=[-0.05,0.22])
visualize_displacement(U, m, n, h;  name = "_linear")
visualize_stress(H, U, m, n, h;  name = "_linear")


close("all")
figure(figsize=(15,5))
subplot(1,3,1)
idx = div(n,2)*(m+1) + m+1
plot((0:NT)*Δt, U[idx,:])
xlabel("time")
ylabel("x displacement")

subplot(1,3,2)
idx = 4*(div(n,2)*m + m)
plot((0:NT)*Δt, Sigma[:,idx,1])
xlabel("time")
ylabel("x stress")

subplot(1,3,3)
idx = 4*(div(n,2)*m + m)
plot((0:NT)*Δt, Varepsilon[:,idx,1])
xlabel("time")
ylabel("x strain")
savefig("linear.png")