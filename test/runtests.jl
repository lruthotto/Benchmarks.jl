using Benchmarks, Base.Test

t = @benchmark sin(1)
@test 100 > time(t) > 0
@test gctime(t) == 0
@test bytes(t) == 0
@test allocs(t) == 0

v = rand(100)
t = @benchmark [rand(1000); v] 0.1
@test 20000 > time(t) > gctime(t)
@test gctime(t) > 0
@test 20000 > bytes(t) > 0
@test 100 > allocs(t) > 0
