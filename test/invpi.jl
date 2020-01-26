using Revise
using PoreFlow
using PyCall
using LinearAlgebra
using ADCME
np = pyimport("numpy")

# Domain information 
NT = 50
Δt = 1/NT
n = 30
m = n 
h = 1.0/n 
bdnode = Int64[]
for i = 1:m+1
    for j = 1:n+1
        if i==1 || i==m+1 || j==1|| j==n+1
            push!(bdnode, (j-1)*(m+1)+i)
        end
    end
end

# Physical parameters
b = 1.0
H = [1.0 0.0 0.0
    0.0 1.0 0.0
    0.0 0.0 0.5]
Q = SparseTensor(compute_fvm_tpfa_matrix(m, n, h))
K = SparseTensor(compute_fem_stiffness_matrix(H, m, n, h))
L = SparseTensor(compute_interaction_matrix(m, n, h))
M = SparseTensor(compute_fvm_mass_matrix(m, n, h))
A = [K -b*L'
b*L/Δt 1/Δt*M-Q]
A, Abd = fem_impose_coupled_Dirichlet_boundary_condition(A, bdnode, m, n, h)

U = zeros(m*n+2(m+1)*(n+1), NT+1)
x = Float64[]; y = Float64[]
for j = 1:n+1
    for i = 1:m+1
        push!(x, (i-1)*h)
        push!(y, (j-1)*h)
    end
end
    
injection = (div(n,2)-1)*m + 3
production = (div(n,2)-1)*m + m-3

function condition(i, ta_u)
    i<=NT
end

function body(i, ta_u)
    u = read(ta_u, i)
    bdval = zeros(2*length(bdnode))
    rhs1 = vector([bdnode; bdnode.+ (m+1)*(n+1)], bdval, 2(m+1)*(n+1))
    rhs2 = zeros(m*n)
    rhs2[injection] += 1.0
    rhs2[production] -= 1.0
    rhs2 += b*L*u[1:2(m+1)*(n+1)]/Δt + 
            M * u[2(m+1)*(n+1)+1:end]/Δt
    rhs = [rhs1;rhs2]
    rhs -= Abd * bdval 
    o = A\rhs 
    ta_u = write(ta_u, i+1, o)
    op = tf.print(i)
    i = bind(i, op)
    i+1, ta_u
end

i = constant(1, dtype=Int32)
ta_u = TensorArray(NT+1)
ta_u = write(ta_u, 1, constant(zeros(2(m+1)*(n+1)+m*n)))
_, u_out = while_loop(condition, body, [i, ta_u])
u_out = stack(u_out)

sess = Session(); init(sess)
U = run(sess, u_out)
visualize_displacement(U'|>Array, m, n, h, name="_tf")
visualize_pressure(U'|>Array, m, n, h, name="_tf")
