# `AbstractAnalysis` is a supertype that defines a general interface for
# types which provide statistical analyses of `ExecutionResults` objects.
#
# Subtypes A <: AbstractAnalysis should define:
#
# - execresults(a::A) --> ExecutionResults || Tuple{Vararg{ExecutionResults}}
#       returns the `ExecutionResults` object(s) associated with `a`

abstract AbstractAnalysis

# Returns the total time (ns) spent executing the benchmark
totaltime(r::ExecutionResults) = r.time_used
totaltime(rs::Tuple{Vararg{ExecutionResults}}) = map(totaltime, rs)
totaltime(a::AbstractAnalysis) = totaltime(execresults(a))

# A `SummaryStatistics` object stores the results of a statistic analysis of
# an `ExecutionResults` object. The precise analysis strategy employed
# depends on the structure of the `ExecutionResults` object:
#
#     (1) If only a single sample of a single evaluation was recorded, the
#     analysis reports only point estimates.
#
#     (2) If multiple samples of a single evaluation were recorded, the
#     analysis reports point estimates and CI's determined by straight
#     summary statistic calculations.
#
#     (3) If a geometric search was performed to generate samples that
#     represent multiple evaluations, an OLS regression is fit that
#     estimates the model `elapsed_time ~ 1 + evaluations`. The slope
#     of the `evaluations` term is treated as the best estimate of the
#     elapsed time of a single evaluation.
#
# For both strategies (2) and (3), we try to make up for a lack of IID
# samples by using 6-sigma CI's instead of the traditional 2-sigma CI'
# reported in most applied statistical work.
#
# In order to estimate GC time, we assume that the relationship betweeen GC
# time and total time is constant with respect to the number of evaluations.
# As such, we avoid using an OLS fit for estimating GC time.
#
# We also assume that the ratio, `bytes_allocated / evaluations` is a
# constant that only exhibits upward-biased noise. As such, we take the
# minimum value of this ratio to determine the memory allocation behavior of
# an expression.

immutable SummaryStatistics <: AbstractAnalysis
    execresults::ExecutionResults
    n_samples::Int
    n_evaluations::Int
    elapsed_time_lower::Nullable{Float64}
    elapsed_time_center::Float64
    elapsed_time_upper::Nullable{Float64}
    gc_proportion_lower::Nullable{Float64}
    gc_proportion_center::Float64
    gc_proportion_upper::Nullable{Float64}
    bytes_allocated::Int
    allocations::Int
    r²::Nullable{Float64}

    function SummaryStatistics(execresults::ExecutionResults)
        s = execresults.samples
        n_samples = length(s.evaluations)
        n_evaluations = convert(Int, sum(s.evaluations))
        if !execresults.search_performed
            if !execresults.multiple_samples
                @assert n_samples == 1
                @assert all(s.evaluations .== 1.0)
                m = s.elapsed_times[1]
                gc_proportion = s.gc_times[1] / s.elapsed_times[1]
                elapsed_time_center = m
                elapsed_time_lower = Nullable{Float64}()
                elapsed_time_upper = Nullable{Float64}()
                r² = Nullable{Float64}()
                gc_proportion_center = 100.0 * gc_proportion
                gc_proportion_lower = Nullable{Float64}()
                gc_proportion_upper = Nullable{Float64}()
            else
                @assert all(s.evaluations .== 1.0)
                m = mean(s.elapsed_times)
                sem = std(s.elapsed_times) / sqrt(n_samples)
                gc_proportion = mean(s.gc_times ./ s.elapsed_times)
                gc_proportion_sem = (std(s.gc_times ./ s.elapsed_times)
                                     / sqrt(n_samples))
                r² = Nullable{Float64}()
                elapsed_time_center = m
                elapsed_time_lower = m - 6.0 * sem
                elapsed_time_upper = m + 6.0 * sem
                gc_proportion_center = 100.0 * gc_proportion
                gc_proportion_lower = Nullable{Float64}(
                    max(
                        0.0,
                        gc_proportion_center - 6.0 * 100 * gc_proportion_sem
                    )
                )
                gc_proportion_upper = Nullable{Float64}(
                    min(
                        100.0,
                        gc_proportion_center + 6.0 * 100 * gc_proportion_sem
                    )
                )
            end
        else
            a, b, ols_r² = ols(s.evaluations, s.elapsed_times)
            sem = sem_ols(s.evaluations, s.elapsed_times)
            gc_proportion = mean(s.gc_times ./ s.elapsed_times)
            gc_proportion_sem = (std(s.gc_times ./ s.elapsed_times)
                                 / sqrt(n_samples))
            r² = Nullable{Float64}(ols_r²)
            elapsed_time_center = b
            elapsed_time_lower = b - 6.0 * sem
            elapsed_time_upper = b + 6.0 * sem
            gc_proportion_center = 100.0 * gc_proportion
            gc_proportion_lower = Nullable{Float64}(
                max(
                    0.0,
                    gc_proportion_center - 6.0 * 100 * gc_proportion_sem
                )
            )
            gc_proportion_upper = Nullable{Float64}(
                min(
                    100.0,
                    gc_proportion_center + 6.0 * 100 * gc_proportion_sem
                )
            )
        end

        i = indmin(s.bytes_allocated ./ s.evaluations)

        bytes_allocated = fld(
            s.bytes_allocated[i],
            convert(UInt, s.evaluations[i])
        )
        allocations = fld(
            s.allocations[i],
            convert(UInt, s.evaluations[i])
        )

        new(
            execresults,
            n_samples,
            n_evaluations,
            elapsed_time_lower,
            elapsed_time_center,
            elapsed_time_upper,
            gc_proportion_lower,
            gc_proportion_center,
            gc_proportion_upper,
            bytes_allocated,
            allocations,
            r²,
        )
    end
end

# Returns the `ExecutionResults` object from which these statistics were derived
execresults(stats::SummaryStatistics) = stats.execresults

# Returns estimates of the time (ns) per evaluation of the target function
timepereval(stats::SummaryStatistics) = (stats.elapsed_time_lower,
                                         stats.elapsed_time_center,
                                         stats.elapsed_time_upper)

# Returns estimates of the % of time spent in GC during benchmark execution
gcpercent(stats::SummaryStatistics) = (stats.gc_proportion_lower,
                                       stats.gc_proportion_center,
                                       stats.gc_proportion_upper)

# Returns the # of bytes allocated during benchmark execution
nbytes(stats::SummaryStatistics) = stats.bytes_allocated

# Returns the # of allocations made during benchmark execution
nallocs(stats::SummaryStatistics) = stats.allocations

# Returns the # of evaluations performed during benchmark execution
nevals(stats::SummaryStatistics) = stats.n_evaluations

# Returns the # of samples taken during benchmark execution
nsamples(stats::SummaryStatistics) = stats.n_samples

# Returns the r² value of the OLS regression performed on the execution results
rsquared(stats::SummaryStatistics) = stats.r²

# `SummaryStatistics` pretty-printing
function Base.show(io::IO, stats::SummaryStatistics)
    max_length = 24
    @printf(io, "============ Benchmark Results Summary ============\n")

    if !(execresults(stats).precompiled)
        @printf(io, "Warning: function may not have been precompiled\n")
    end

    lowertime, centertime, uppertime = timepereval(stats)
    if isnull(lowertime) || isnull(uppertime)
        @printf(
            io,
            "%s: %s\n",
            lpad("Time per evaluation", max_length),
            pretty_time_string(centertime)
        )
    else
        @printf(
            io,
            "%s: %s [%s, %s]\n",
            lpad("Time per evaluation", max_length),
            pretty_time_string(centertime),
            pretty_time_string(get(lowertime)),
            pretty_time_string(get(uppertime))
        )
    end

    lowergc, centergc, uppergc = gcpercent(stats)
    if isnull(lowergc) || isnull(uppergc)
        @printf(
            io,
            "%s: %.2f%%\n",
            lpad("Proportion of time in GC", max_length),
            centergc
        )
    else
        @printf(
            io,
            "%s: %.2f%% [%.2f%%, %.2f%%]\n",
            lpad("Proportion of time in GC", max_length),
            centergc,
            get(lowergc),
            get(uppergc)
        )
    end

    @printf(
        io,
        "%s: %s\n",
        lpad("Memory allocated", max_length),
        pretty_memory_string(nbytes(stats))
    )

    @printf(
        io,
        "%s: %d allocations\n",
        lpad("Number of allocations", max_length),
        nallocs(stats),
    )

    @printf(
        io,
        "%s: %d\n",
        lpad("Number of samples", max_length),
        nsamples(stats)
    )

    @printf(
        io,
        "%s: %d\n",
        lpad("Number of evaluations", max_length),
        nevals(stats)
    )

    if execresults(stats).search_performed
        @printf(
            io,
            "%s: %.3f\n",
            lpad("R² of OLS model", max_length),
            get(rsquared(stats), NaN),
        )
    end

    @printf(
        io,
        "%s: %.2f s\n",
        lpad("Time spent benchmarking", max_length),
        totaltime(stats),
    )
end
