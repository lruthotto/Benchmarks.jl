#######
# OLS #
#######

# Perform a univariate OLS regression (with non-zero intercept) to estimate the
# per-evaluation execution time of an expression.
function ols(evals::Vector{Float64}, times::Vector{Float64})
    a, b = linreg(evals, times)
    r² = 1 - var(a + b * evals - times) / var(times)
    return a, b, r² # intercept, slope, and r-squared of univariate OLS
end

function sem_ols(evals::Vector{Float64}, times::Vector{Float64})
    a, b = linreg(evals, times)
    residuals = times - (a + b * evals)
    numer = inv(length(evals) - 2) * sum(residuals.^2)
    denom = sum((evals - mean(evals)).^2)
    return sqrt(numer / denom)
end

###################
# Pretty Printing #
###################

function reprcompact(item)
    tmpio = IOBuffer()
    showcompact(tmpio, item)
    return takebuf_string(tmpio)
end

function reprcompact(v::Vector)
    tmpio = IOBuffer()
    print(tmpio, "[")
    if length(v) < 6
        print(tmpio, join(map(reprcompact, v), ", "))
    else
        print(tmpio, reprcompact(v[1]), ", ", reprcompact(v[2]), ", ")
        print(tmpio, "… ")
        print(tmpio, reprcompact(v[end-1]), ", ", reprcompact(v[end]))
    end
    print(tmpio, "]")
    return takebuf_string(tmpio)
end

function prettytime(t)
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

function prettymemory(b)
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
