using SimpleLockFiles
const SLF = SimpleLockFiles
using Test

@testset "SLF.jl" begin
    
    include("core_tests.jl")
    include("race_test.jl")

end
