*Note: As you can see, this package is a more recently developed fork of the
original. At the time of writing, I've done a fair amount of clean-up, removing
unused code and simplifying some of the existing code in order to avoid
duplication and increase readability. I've also restructured the various result
types to make them more friendly for external use. Finally, I've refactored the
test suite for wider and more targeted coverage (which is now actually being
tracked). At some point, I hope to merge this fork and the original package -- Jarrett*

[![Build Status](https://travis-ci.org/jrevels/Benchmarks.jl.svg?branch=master)](https://travis-ci.org/jrevels/Benchmarks.jl)
[![Coverage Status](https://coveralls.io/repos/jrevels/Benchmarks.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/jrevels/Benchmarks.jl?branch=master)

Benchmarks.jl
=============

A package to make Julia benchmarking both easy and rigorous.

## How to Use Benchmarks.jl

For trivial benchmarking, you can use the `@benchmark` macro, which takes
in a simple Julia expression and returns the results of benchmarking that
expression:

```julia
using Benchmarks

@benchmark sin(2.0)

@benchmark sin(sin(2.0))

@benchmark exp(sin(2.0))

@benchmark svd(rand(10, 10))
```

You can fine-tune the benchmarking process by working with the lower-level
interface used by `@benchmark`: the `Benchmarks.@benchmarkable`, which can be
used define a "benchmarkable" function, and `Benchmarks.execute`, which actually
runs the function and returns the results.

Specifically, `Benchmarks.@benchmarkable` and is called in the following manner:

```julia
import Benchmarks

# generate a new benchmarkable function and bind it to the `mybench!` variable
mybench! = Benchmarks.@benchmarkable(
    setup_expr,      # this expression will be run before benchmarking core
    core_expr,       # this is the expression to be benchmarked
    teardown_expr    # this expression will be run after benchmarking core
)

# Now we can run the benchmarkable function we defined:
results = Benchmark.execute(mybench!)
```

Here's a concrete example of the above:

```julia
import Benchmarks

normbench! = Benchmarks.@benchmarkable(
    (v = rand(1000)),
    norm(v),
    println("Done with this execution!")
)

results = Benchmark.execute(normbench!)
```

Note that `Benchmark.execute` accepts the following keyword arguments (you'll probably need to read [the design section](#the-design-of-benchmarksjl) to understand some of these):

- `sample_limit = 100`:  The max number of samples to take when benchmarking. This limit is ignored in the event that a geometric search is triggered.
- `time_limit = 10`: The max number of seconds to spend benchmarking. This limit is respected, even if a geometric search is triggered.
- `τ = 0.95`: The minimum R² of the OLS model before the geometric search is considered to have converged.
- `α = 1.1`: The growth rate for the geometric search.
- `ols_samples = 100`: The number of samples collected during each call to the benchmarkable function when performing the geometric search.
- `verbose = false`: If `true`, progress will be printed to `STDOUT` during the geometric (no progress is printed unless a geometric search is triggered).
- `rungc = true`: If `true`, periodically run `gc()` between execution samples.

## The Design of Benchmarks.jl

Benchmarking is hard. To do it well, you have to care about the details of how
code is executed and the statistical challenges that make it hard to generalize
correctly from benchmark data. To explain the rationale for design of the
package, we discuss the problems that the package is designed to solve.

#### Measurement Error: Benchmarks that Measure the Wrong Thing

The first problem that the Benchmarks package tries to solve is the problem of
measurement error: benchmarking any expression that can be evaluated faster
than the system clock's resolution can track is vulnerable to measuring the
system clock's performance rather than the expression's performance. Naive
estimates, like those generated by the `@time` macro are often totally
inaccurate. To convince yourself, consider the following timings:

```j
@time sin(2.0)

@time sin(sin(2.0))

@time sin(sin(2.0))
```

On my system, the results of this code often suggest that `sin(sin(2.0))` can
be evaluated faster than `sin(2.0)`. That's obviously absurd -- and the timings
returned by `@time sin(2.0)` are almost certainly totally inaccurate.

The reason for that inaccuracy is that `sin(2.0)` can be evaluated much faster
than the system clock's finest resolution. As such, you're almost exclusively
measuring variability in the system clock when you evaluate `@time sin(2.0)`.

To deal with this, Benchmarks.jl exploits a simple linear relationship:
evaluating an expression N times in a row should take approximately N times as
long as evaluating the same expression exactly 1 time. This linear relationship
holds almost perfectly as N grows. Thus, we solve the problem of measurement
error by measuring the time it takes to evaluate `sin(2.0)` a very large number
of times. Then we apply linear regression to estimate the time it takes to
evaluate `sin(2.0)` exactly once.

#### Accounting for Variability

When you repeatedly evaluate the same expression, you find that the timings
you measure are not all the same - there is often substantial variability across
measurements.

Benchmarks.jl tries to resolve this problem by estimating the average time that
it would take to evaluate an expression. Because the average is estimated from a
small sample of measurements, we have to acknowledge that our estimate is
uncertain. We do this by reporting 95% confidence intervals (CIs) for the
average time per evaluation.

#### Resource Constraints

Getting the best estimate of the average time requires gathering as many
samples as possible, but most people also want their benchmarks to run in a
finite amount of time. For this reason, Benchmarks.jl exposes a way to
constrain the number of samples and the amount of time taken through keyword
arguments to `Benchmarks.execute` (`sample_limit` and `time_limit`).

Note that, for very fast computations that require OLS modeling, `sample_limit`
is ignored (`time_limit` is still respected, however). This is because users
cannot reasonably expect to know how many samples they need to gather to
estimate the average time accurately.
