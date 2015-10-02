module TestAnalysisAPI
    import Benchmarks
    using Base.Test

    ####################
    # @benchmark macro #
    ####################

    # no-op function calls:
    f() = nothing
    @benchmark f()

    # infix operators
    @benchmark (3.0+5im)^3.2

    # indexing
    A = rand(2,2)
    @benchmark A[end,end]

    # Keyword arguments
    @benchmark svds(A, nsv=1)

    # local scopes
    x = 1
    let B = copy(A), y = 2
        @benchmark B[1]
        @benchmark x+y
    end

    ################
    # Retrival API #
    ################

    f(v) = dot(v, rand(length(v)))
    results = @benchmark f(rand(10))
    stats = Benchmarks.SummaryStatistics(results)

    @test Benchmarks.execresults(stats) == results
    @test Benchmarks.totaltime(stats) > 0.0
    @test Benchmarks.nbytes(stats) > 0
    @test Benchmarks.nallocs(stats) > 0
    @test Benchmarks.nsamples(stats) > 0
    @test get(Benchmarks.rsquared(stats)) > 0.8

    lowertime, centertime, uppertime = Benchmarks.timepereval(stats)
    @test get(lowertime) > 0.0
    @test centertime > get(lowertime)
    @test get(uppertime) > centertime

    lowergc, centergc, uppergc = Benchmarks.gcpercent(stats)
    @test get(lowergc) > 0.0
    @test centergc > get(lowergc)
    @test get(uppergc) > centergc
end
