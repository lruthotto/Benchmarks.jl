import Benchmarks
using Base.Test

############################
# Environment Construction #
############################

env = Benchmarks.Environment()

sleep(1)

@test (now()-env.timestamp).value >= 1000
@test env.julia_sha1 == Base.GIT_VERSION_INFO.commit
@test env.os == string(OS_NAME)
@test env.cpu_cores == CPU_CORES
@test env.arch == string(Base.ARCH)
@test env.machine == Base.MACHINE
@test env.use_blas64 == Base.USE_BLAS64
@test env.word_size == Base.WORD_SIZE

####################
# Clock Resolution #
####################

@test 0 < Benchmarks.estimate_clock_resolution()
