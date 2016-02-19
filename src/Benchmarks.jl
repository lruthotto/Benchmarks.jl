module Benchmarks

export @benchmark, time, gctime, bytes, allocs

#########
# Trial #
#########

immutable Trial
    evals::Float64
    time::Float64
    gctime::Float64
    bytes::Float64
    allocs::Float64
end

Base.time(t::Trial) = t.time / t.evals
gctime(t::Trial) = t.gctime / t.evals
bytes(t::Trial) = fld(t.bytes, t.evals)
allocs(t::Trial) = fld(t.allocs, t.evals)

Base.isless(a::Trial, b::Trial) = isless(time(a), time(b))

function Base.show(io::IO, t::Trial)
    println(io, "Benchmarkt.Trial: ")
    println(io, "  time/evaluation:    ", prettytime(time(t)))
    println(io, "  # of evaluations:   ", t.evals)
    println(io, "  total time:         ", prettytime(t.time))
    println(io, "  GC time/evaluation: ", prettytime(gctime(t)))
    println(io, "  memory allocated:   ", prettymemory(bytes(t)))
    println(io, "  # of allocations:   ", allocs(t))
end

Base.showcompact(io::IO, t::Trial) = print(io, "Trial($(prettytime(time(t))))")

function prettytime(t)
    if t < 1_000
        @sprintf("%.2f ns", t)
    elseif t < 1_000_000
        @sprintf("%.2f μs", t / 1_000)
    elseif t < 1_000_000_000
        @sprintf("%.2f ms", t / 1_000_000)
    elseif t < 1_000_000_000_000
        @sprintf("%.2f s", t / 1_000_000_000)
    else
        error("invalid time $t")
    end
end

function prettymemory(b)
    if b < 1_024.0
        @sprintf("%.2f bytes", b)
    elseif b < 1_024.0^2
        @sprintf("%.2f kb", b / 1_024.0)
    elseif b < 1_024.0^3
        @sprintf("%.2f mb", b / 1_024.0^2)
    elseif b < 1_024.0^4
        @sprintf("%.2f gb", b / 1_024.0^3)
    else
        error("invalid memory $b")
    end
end

##############
# @benchmark #
##############

const DEFAULT_TIME_LIMIT = 5.0

macro benchmark(args...)
    if length(args) == 1
        core = first(args)
        time_limit = DEFAULT_TIME_LIMIT
    elseif length(args) == 2
        core, time_limit = args
    else
        error("wrong number of arguments for @benchmark")
    end
    wrapfn = gensym("wrap")
    trialfn = gensym("trial")
    return esc(quote
        @noinline $(wrapfn)() = $(core)
        @noinline function $(trialfn)(time_limit_ns)
            gc()
            total_evals = 0.0
            gc_start = Base.gc_num()
            start_time = time_ns()
            growth_rate = 1.01
            iter_evals = 2.0
            while (time_ns() - start_time) < time_limit_ns
                for _ in 1:floor(iter_evals)
                    $(wrapfn)()
                end
                total_evals += iter_evals
                iter_evals *= growth_rate
            end
            elapsed_time = time_ns() - start_time
            gcdiff = Base.GC_Diff(Base.gc_num(), gc_start)
            bytes = gcdiff.allocd
            allocs = gcdiff.malloc + gcdiff.realloc + gcdiff.poolalloc + gcdiff.bigalloc
            gctime = gcdiff.total_time
            return Benchmarks.Trial(total_evals, elapsed_time, gctime, bytes, allocs)
        end
        $(trialfn)(1e6)
        $(trialfn)($(time_limit) * 1e9)
    end)
end

end # module
