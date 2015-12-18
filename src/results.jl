###########
# Samples #
###########

# A `Samples` instance contains information obtained from benchmark execution.
# All fields are Vectors of equal length, and each index corresponds to an
# individual sample.
type Samples
    evals::Vector{Float64} # number of evals for each sample
    times::Vector{Float64} # time (ns) for each sample
    gctimes::Vector{Float64} # GC time (ns) for each sample
    bytes::Vector{Int} # bytes allocated for each sample
    allocs::Vector{Int} # number of allocations for each sample
    function Samples()
        return new(Vector{Float64}(),
                   Vector{Float64}(),
                   Vector{Float64}(),
                   Vector{Int}(),
                   Vector{Int}())
    end
end

function Base.push!(s::Samples, evals::Real, time::Real, gctime::Real,
                    bytes::Real, allocs::Real)
    push!(s.evals, evals)
    push!(s.times, time)
    push!(s.gctimes, gctime)
    push!(s.bytes, bytes)
    push!(s.allocs, allocs)
    return s
end

function Base.isempty(s::Samples)
    return (isempty(s.evals) && isempty(s.times) &&
            isempty(s.gctimes) && isempty(s.bytes) &&
            isempty(s.allocs))
end

function Base.empty!(s::Samples)
    empty!(s.evals)
    empty!(s.times)
    empty!(s.gctimes)
    empty!(s.bytes)
    empty!(s.allocs)
    return s
end

Base.getindex(s::Samples, i) = (s.evals[i], s.times[i], s.gctimes[i], s.bytes[i], s.allocs[i])

Base.length(s::Samples) = length(s.evals)

function Base.show(io::IO, s::Samples)
    println(io, "Benchmarks.Samples:")
    println(io, "  number of samples: ", length(s))
    println(io, "  evaluations:       ", reprcompact(s.evals))
    println(io, "  times (ns):        ", reprcompact(s.times))
    println(io, "  GC times (ns):     ", reprcompact(s.gctimes))
    println(io, "  bytes allocated:   ", reprcompact(s.bytes))
    print(io,   "  allocations:       ", reprcompact(s.allocs))
end

####################
# ExecutionResults #
####################

# An `ExecutionResults` instance contains the `Samples` instance obtained from
# benchmarking, as well as some metadata about the benchmarking process itself.
immutable ExecutionResults
    samples::Samples # the sample data taken during execution
    precompiled::Bool # did we ensure the benchmarkable function was precompiled?
    multiple_evals::Bool # did we need to perform multiple evaluations per sample?
    totaltime::Float64 # total time (s) spent executing the benchmark
end

function Base.show(io::IO, r::ExecutionResults)
    println(io, "Benchmarks.ExecutionResults (see :samples field for Samples):")
    println(io, "  precompiled?:                     ", r.precompiled)
    println(io, "  multiple evaluations per sample?: ", r.multiple_evals)
    print(io,   "  total time spent benchmarking:    ", round(r.totaltime, 2), " s")
end

################
# SummaryStats #
################

immutable SummaryStats
    timepereval::Tuple{Nullable{Float64},Float64,Nullable{Float64}}
    rsquared::Nullable{Float64}
    gcpercent::Tuple{Nullable{Float64},Float64,Nullable{Float64}}
    nsamples::Int # number of samples taken
    nevals::Int # number of evaluations performed
    nbytes::Int # number of bytes allocated
    nallocs::Int # number of allocations made
    function SummaryStats(results::ExecutionResults)
        s = results.samples

        timepereval, rsquared = calc_timepereval(s, results.multiple_evals)
        gcpercent = calc_gcpercent(s)
        nsamples = length(s)
        nevals = Int(sum(s.evals))

        i = indmin(s.bytes ./ s.evals)
        evals_i = UInt(s.evals[i])
        nbytes = fld(s.bytes[i], evals_i)
        nallocs = fld(s.allocs[i], evals_i)

        return new(timepereval, rsquared, gcpercent,
                   nsamples, nevals, nbytes, nallocs)
    end
end

function calc_timepereval(s::Samples, multiple_evals::Bool)
    rsquared = Nullable{Float64}()
    if multiple_evals # if true, we should perform an ols
        _, m, ols_rsquared = ols(s.evals, s.times)
        sem = sem_ols(s.evals, s.times)
        rsquared = Nullable(ols_rsquared)
    elseif length(s) == 1
        timepereval = (Nullable{Float64}(), s.times[1], Nullable{Float64}())
        return timepereval, rsquared
    else # if we have multiple samples, but only one eval per sample
        m = mean(s.times)
        sem = std(s.times) / sqrt(length(s))
    end
    offset = 6.0 * sem
    timepereval = (Nullable(max(0.0, m - offset)), m, Nullable(m + offset))
    return timepereval, rsquared
end

function calc_gcpercent(s::Samples)
    if length(s) == 1
        gc_center = 100.0 * (s.gctimes[1] / s.times[1])
        return (Nullable{Float64}(), gc_center, Nullable{Float64}())
    else
        gc_times_ratio = s.gctimes ./ s.times
        offset = 600.0 * std(gc_times_ratio) / sqrt(length(s))
        gc_center = 100.0 * mean(gc_times_ratio)
        gc_lower = Nullable(max(0.0, gc_center - offset))
        gc_upper = Nullable(min(100.0, gc_center + offset))
        return (gc_lower, gc_center, gc_upper)
    end
end

function Base.show(io::IO, stats::SummaryStats)
    t_lo, t, t_hi = stats.timepereval
    timestr = prettytime(t)
    if !(isnull(t_lo) || isnull(t_hi))
        timestr = "$timestr [$(prettytime(get(t_lo))), $(prettytime(get(t_hi)))]"
    end

    gc_lo, gc, gc_hi = stats.gcpercent
    gcstr = "$(round(gc,2))%"
    if !(isnull(gc_lo) || isnull(gc_hi))
        gcstr = "$gcstr [$(round(get(gc_lo),2))%, $(round(get(gc_hi),2))%]"
    end

    if isnull(stats.rsquared)
        rsqr_str = "N/A (OLS not performed)"
    else
        rsqr_str = string(round(get(stats.rsquared), 2))
    end

    println(io, "Benchmarks.SummaryStats:")
    println(io, "  estimated time per evaluation: ", timestr)
    println(io, "  R² of OLS model:               ", rsqr_str)
    println(io, "  estimated % time in GC:        ", gcstr)
    println(io, "  bytes allocated:               ", prettymemory(stats.nbytes))
    println(io, "  number of allocations:         ", stats.nallocs)
    println(io, "  number of samples:             ", stats.nsamples)
    print(io,   "  number of evaluations:         ", stats.nevals)
end
