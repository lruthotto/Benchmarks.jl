
print("Testing enviroment detection...")
tic()
include("environment_tests.jl")
println("done (took $(toq()) seconds).")

print("Testing Samples/ExecutionResults/SummaryStats...")
tic()
include("results_tests.jl")
println("done (took $(toq()) seconds).")

print("Testing @benchmark/@benchmarkable/execution...")
tic()
include("execution_tests.jl")
println("done (took $(toq()) seconds).")
