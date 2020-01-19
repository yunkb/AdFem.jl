__precompile__(false)
module PoreFlow 

    using SparseArrays
    using LinearAlgebra
    using PyCall
    np = pyimport("numpy")
    # matplotlib.use("macosx")

    pts = @. ([-1/sqrt(3); 1/sqrt(3)] + 1)/2

    include("Struct.jl")
    include("Core.jl")

end