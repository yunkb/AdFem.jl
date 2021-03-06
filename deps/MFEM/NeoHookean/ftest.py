from dolfin import *
import matplotlib.pyplot as plt 
import numpy as np 

# Optimization options for the form compiler
parameters["form_compiler"]["cpp_optimize"] = True
ffc_options = {"optimize": True, \
               "eliminate_zeros": True, \
               "precompute_basis_const": True, \
               "precompute_ip_const": True}

# Create mesh and define function space
mesh = UnitSquareMesh(8, 8, "left")
V = VectorFunctionSpace(mesh, "Lagrange", 1)

# Mark boundary subdomians
left =  CompiledSubDomain("near(x[0], side) && on_boundary", side = 0.0)
right = CompiledSubDomain("near(x[0], side) && on_boundary", side = 1.0)

# Define Dirichlet boundary (x = 0 or x = 1)
c = Expression(("0.0", "0.0"), degree=2)
r = Expression(("0.0", "0.0"), degree=2)

bcl = DirichletBC(V, c, left)
bcr = DirichletBC(V, r, right)
bcs = [bcl, bcr]

# Define functions
du = TrialFunction(V)            # Incremental displacement
v  = TestFunction(V)             # Test function
u  = Function(V)                 # Displacement from previous iteration
u.vector()[:] = np.random.rand(u.vector().size())
B  = Constant((0.0, -0.5))  # Body force per unit volume
T  = Constant((0.1,  0.0))  # Traction force on the boundary

# Kinematics
d = u.geometric_dimension()
I = Identity(d)             # Identity tensor
F = I + grad(u)             # Deformation gradient
C = F.T*F                   # Right Cauchy-Green tensor

# Invariants of deformation tensors
Ic = tr(C)
J  = det(C)

# # Elasticity parameters
# E, nu = 10.0, 0.3
# mu, lmbda = Constant(E/(2*(1 + nu))), Constant(E*nu/((1 + nu)*(1 - 2*nu)))

# Stored strain energy density (compressible neo-Hookean model)
mu = Constant(10.0)
lmbda = Constant(3.0)
psi = (mu/2)*(Ic - 2) - mu*ln(J)/2.0 + (lmbda/2)*1/4.0*ln(J)**2

# Total potential energy
Pi = psi*dx

# Compute first variation of Pi (directional derivative about u in the direction of v)
F = derivative(Pi, u, v)

# Compute Jacobian of F
J = derivative(F, u, du)

DofToVert = vertex_to_dof_map(u.function_space())
Fvalue = assemble(F)[DofToVert]
Svalue = assemble(J).array()[DofToVert, :][:, DofToVert]
np.savetxt("fenics/F.txt", Fvalue)
np.savetxt("fenics/S.txt", Svalue)
np.savetxt("fenics/u.txt", u.vector()[:][DofToVert])
