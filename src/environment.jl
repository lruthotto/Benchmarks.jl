# Return estimated clock resolution in nanoseconds by sampling the system clock
# (2 * nsamples) times. This function fails on Windows due to the behavior
# of `time_ns()` on that platform.
function estimate_clock_resolution(nsamples::Integer = 10_000)
    min_Δt = typemax(UInt)
    for _ in 1:nsamples
        t1 = Base.time_ns()
        t2 = Base.time_ns()
        # On Linux AArch64 it seems that t1 and t2 could be the same sometimes
        while t2 <= t1
            t2 = Base.time_ns()
        end
        Δt = t2 - t1
        min_Δt = min(min_Δt, Δt)
    end
    return min_Δt
end

# An `Environment` instance stores information about the environment in which a
# suite of benchmarks were executed.
immutable Environment
    uuid::UTF8String # unique ID of run
    timestamp::DateTime # benchmark execution start time
    julia_sha1::UTF8String # the git SHA1 of the current julia installation
    package_sha1::Nullable{UTF8String} # the git SHA1 of the current repo (if any)
    os::UTF8String # the current OS
    cpu_cores::Int # the number of CPU cores available
    arch::UTF8String # the current architecture
    machine::UTF8String # the current machine type
    use_blas64::Bool # is BLAS configured to use 64-bits?
    word_size::Int # the word size of the host machine.
    function Environment()
        uuid = string(Base.Random.uuid4())
        timestamp = now()
        julia_sha1 = Base.GIT_VERSION_INFO.commit
        os = string(OS_NAME)
        cpu_cores = CPU_CORES
        arch = string(Base.ARCH)
        machine = Base.MACHINE
        use_blas64 = Base.USE_BLAS64
        word_size = Base.WORD_SIZE

        package_sha1 = Nullable{UTF8String}()
        try
            sha1 = readchomp(pipeline(`git rev-parse HEAD`, stderr=Base.DevNull))
            package_sha1 = Nullable{UTF8String}(utf8(sha1))
        end

        new(uuid,
            timestamp,
            julia_sha1,
            package_sha1,
            os,
            cpu_cores,
            arch,
            machine,
            use_blas64,
            word_size)
    end
end

function Base.show(io::IO, e::Environment)
    println(io, "Benchmarks.Environment:")
    println(io, "  UUID:             ", e.uuid),
    println(io, "  start time:       ", e.timestamp),
    println(io, "  julia SHA1:       ", e.julia_sha1),
    println(io, "  parent repo SHA1: ", get(e.package_sha1, "NULL")),
    println(io, "  machine type:     ", e.machine),
    println(io, "  CPU architecture: ", e.arch),
    println(io, "  CPU cores:        ", e.cpu_cores),
    println(io, "  OS:               ", e.os),
    println(io, "  word size:        ", e.word_size),
    print(io,   "  64-bit BLAS?:     ", e.use_blas64)
end
