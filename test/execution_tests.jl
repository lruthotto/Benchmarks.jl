using Benchmarks, Base.Test

####################
# @benchmark macro #
####################

@test begin
    # no-op #
    #-------#
    f() = nothing
    @benchmark f()

    # infix operators #
    #-----------------#
    @benchmark (3.0+5im)^3.2

    # indexing #
    #----------#
    A = rand(2,2)
    @benchmark A[end,end]

    # keyword arguments #
    #-------------------#
    @benchmark svds(A, nsv=1)
    @benchmark svds(A; nsv=1)

    # local scopes #
    #--------------#
    x = 1
    let B = copy(A), y = 2
        @benchmark B[1]
        @benchmark x+y
    end

    true # got through without error
end

########################
# @benchmarkable macro #
########################

# general #
#---------#
v = Int[0, 0]
Benchmarks.@benchmarkable(sin_benchmark!, (v[1] += 1), sin(2.0), (v[2] += 1))
r = Benchmarks.execute(sin_benchmark!; time_limit = 1)

@test 0 < r.totaltime < 1.3
@test (v[1] > 0) && (v[1] == v[2])

# time_limit #
#------------#
Benchmarks.@benchmarkable(sleep_benchmark!, nothing, sleep(2), nothing)
r = Benchmarks.execute(sleep_benchmark!; time_limit = 2)

@test 2 <= r.totaltime < 2.3
