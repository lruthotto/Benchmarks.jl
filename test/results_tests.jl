using Benchmarks: Samples, ExecutionResults, SummaryStats
using Base.Test

###########
# Samples #
###########

s = Samples()

@test (isempty(s.evals) && isempty(s.times) &&
       isempty(s.gctimes) && isempty(s.bytes) &&
       isempty(s.allocs) && isempty(s))

vals = (rand(), rand(), rand(), rand(Int), rand(Int))

push!(push!(s, vals...), vals...)

@test !(isempty(s))
@test s[1] == s[2] == vals
@test length(s) == 2

empty!(s)

@test isempty(s) && length(s) == 0

################
# SummaryStats #
################

# single sample, single eval/sample (no OLS performed) #
#------------------------------------------------------#

s = push!(Samples(), 1, 100.01, 50.01, 10, 100)
stats = SummaryStats(ExecutionResults(s, false, false, 500))
tlo, tmid, thi = stats.timepereval
gclo, gcmid, gchi = stats.gcpercent

@test isnull(tlo) && tmid == 100.01 && isnull(thi)
@test isnull(gclo) && round(gcmid, 4) == 50.005 && isnull(gchi)
@test isnull(stats.rsquared)
@test stats.nsamples == 1 && stats.nevals == 1
@test stats.nbytes == 10 && stats.nallocs == 100

# multiple samples, single eval/sample (no OLS performed) #
#---------------------------------------------------------#

s = Samples()
push!(s, 1, 100, 50, 10, 15)
push!(s, 1, 103, 51, 3, 3)
stats = SummaryStats(ExecutionResults(s, false, false, 500))
tlo, tmid, thi = stats.timepereval
gclo, gcmid, gchi = stats.gcpercent

@test get(tlo) == 92.5 && tmid == 101.5 && get(thi) == 110.5
@test (round(get(gclo), 2) == 48.3 &&
       round(gcmid, 2) == 49.76 &&
       round(get(gchi), 2) == 51.21)
@test isnull(stats.rsquared)
@test stats.nsamples == 2 && stats.nevals == 2
@test stats.nbytes == 3 && stats.nallocs == 3

# multiple samples, multiple eval/sample (OLS performed) #
#--------------------------------------------------------#

s = Samples()
push!(s, 2, 200, 50, 6, 5)
push!(s, 3, 221, 52, 4, 3)
push!(s, 1, 156, 41, 2, 1)
stats = SummaryStats(ExecutionResults(s, false, true, 1000))
tlo, tmid, thi = stats.timepereval
gclo, gcmid, gchi = stats.gcpercent

@test (round(get(tlo), 2) == 0 &&
       round(tmid, 2) == 32.5 &&
       round(get(thi), 2) == 72.34)
@test (round(get(gclo), 2) == 20.17 &&
       round(gcmid, 2) == 24.94 &&
       round(get(gchi), 2) == 29.71)
@test round(get(stats.rsquared), 2) == 0.96
@test stats.nsamples == 3 && stats.nevals == 6
@test stats.nbytes == 1 && stats.nallocs == 1
