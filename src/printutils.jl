function pretty_time_string(t)
    if t < 1_000.0
        @sprintf("%.2f ns", t)
    elseif t < 1_000_000.0
        @sprintf("%.2f μs", t / 1_000.0)
    elseif t < 1_000_000_000.0
        @sprintf("%.2f ms", t / 1_000_000.0)
    else # if t < 1_000_000_000_000.0
        @sprintf("%.2f s", t / 1_000_000_000.0)
    end
end

function pretty_memory_string(b)
    if b < 1_024.0
        @sprintf("%.2f bytes", b)
    elseif b < 1_024.0^2
        @sprintf("%.2f kb", b / 1_024.0)
    elseif b < 1_024.0^3
        @sprintf("%.2f mb", b / 1_024.0^2)
    else # if b < 1_024.0^4
        @sprintf("%.2f gb", b / 1_024.0^3)
    end
end

# The functions below are derived from "private" functions in Base

# print elapsed time, return expression value
const _mem_units = ["bytes", "KB", "MB", "GB", "TB", "PB"]
const _cnt_units = ["", " k", " M", " G", " T", " P"]
function prettyprint_getunits(value, numunits, factor)
    c1 = factor
    c2 = c1 * c1
    if value <= c1 * 100
        return (value, 1)
    end
    unit = 2
    while value > c2 * 100 && (unit < numunits)
        c1 = c2
        c2 *= factor
        unit += 1
    end
    return div(value + (c1 >>> 1), c1), unit
end

const _sec_units = ["nanoseconds ", "microseconds", "milliseconds", "seconds     "]
function prettyprint_nanoseconds(value::UInt64)
    if value < 1000
        return (1, value, 0)    # nanoseconds
    elseif value < 1000000
        mt = 2
    elseif value < 1000000000
        mt = 3
        # round to nearest # of microseconds
        value = div(value+500,1000)
    elseif value < 1000000000000
        mt = 4
        # round to nearest # of milliseconds
        value = div(value+500000,1000000)
    else
        # round to nearest # of seconds
        return (4, div(value+500000000,1000000000), 0)
    end
    frac::UInt64 = div(value,1000)
    return (mt, frac, value-(frac*1000))
end

function time_print(elapsedtime, bytes, gctime, allocs)
    mt, pptime, fraction = prettyprint_nanoseconds(elapsedtime)
    if fraction != 0
        @printf("%4d.%03d %s", pptime, fraction, _sec_units[mt])
    else
        @printf("%8d %s", pptime, _sec_units[mt])
    end
    if bytes != 0 || allocs != 0
        bytes, mb = prettyprint_getunits(bytes, length(_mem_units), 1024)
        allocs, ma = prettyprint_getunits(allocs, length(_cnt_units), 1000)
        @printf(
            " (%d%s allocation%s: %d %s",
            allocs,
            _cnt_units[ma],
            allocs == 1 ? "" : "s",
            bytes,
            _mem_units[mb]
        )
        if gctime > 0
            @printf(", %.2f%% gc time", 100 * gctime / elapsedtime)
        end
        print(")")
    elseif gctime > 0
        @printf(", %.2f%% gc time", 100 * gctime / elapsedtime)
    end
    println()
end
