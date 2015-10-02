# An `ExecutionResults` object stores information gained via benchmark
# execution, prior to statistical analysis.
#
# Fields:
#
#     precompiled::Bool: During benchmarking, did we ensure that the
#         benchmarkable function was precompiled? We do this for all
#         functions that can be executed at least twice without exceeding
#         the time budget specified by the user. Otherwise, we only measure
#         the expression's execution once and store this flag to indicate that
#         our single measurement potentially includes compilation time.
#
#     multiple_samples::Bool: During benchmarking, did we gather more than one
#         sample? If so, we will attempt to report results that acknowledge
#         the variability in our sampled observations. If not, we will only
#         report a single point estimate of the expression's performance
#         without any measure of our uncertainty in that point estimate.
#
#     search_performed::Bool: During benchmarking, did we perform a geometric
#         search to determine the minimum number of times we must evaluate the
#         expression being benchmarked before an individual sample can be
#         considered an unbiased estimate of the expression's performance? If
#         so, downstream analyses should use the slope of the linear regression
#         model, `elapsed_time ~ 1 + evaluations`, as their estimate of the
#         time it takes to evaluate the expression once. If not, we know that
#         `evaluation[i] == 1` for all `i`.
#
#     samples::Samples: A record of all samples that were recorded during
#         benchmarking.
#
#     time_used::Float64: The time (in nanoseconds) that was consumed by the
#         benchmarking process.

immutable ExecutionResults
    precompiled::Bool
    multiple_samples::Bool
    search_performed::Bool
    samples::Samples
    time_used::Float64
end

Base.show(io::IO, r::ExecutionResults) = show(io, SummaryStatistics(r))
