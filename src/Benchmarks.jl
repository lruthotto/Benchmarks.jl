module Benchmarks
    export @benchmark

    include("utils.jl")
    include("environment.jl")
    include("results.jl")
    include("execution.jl")
end
