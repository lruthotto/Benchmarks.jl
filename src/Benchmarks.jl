module Benchmarks
    export @benchmark

    include("01_clock_resolution.jl")
    include("02_environment.jl")
    include("03_samples.jl")
    include("04_results.jl")
    include("05_analysis.jl")
    include("benchmarkable.jl")
    include("ols.jl")
    include("execute.jl")
    include("benchmark.jl")
    include("wrapper_types.jl")
    include("printutils.jl")
end
