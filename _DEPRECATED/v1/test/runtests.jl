using SimpleLockFiles
using Test

@testset "SimpleLockFiles.jl" begin
    
    include("core_tests.jl")
    include("race_test.jl")

end
