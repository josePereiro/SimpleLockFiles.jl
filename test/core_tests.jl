let
    @info("Running core tests")
    lkfn = joinpath(@__DIR__, "lock")
    rm(lkfn; force = true)
    
    try        
        slf = SimpleLockFile(lkfn)
        @test lockpath(slf) == lkfn
        
        # Single threaded test
        for it in 1:100
            @test !islocked(slf)
            lock(slf) do
                @test islocked(slf)
            end
            sleep(0.01) # safety delay
        end

        # Multithreaded threaded test
        # Single threaded test
        Base.Threads.@threads :static for it in 1:100
            lock(slf) do
                @test islocked(slf)
            end
            sleep(0.01) # safety delay
        end
        
    finally
        # clear
        rm(lkfn; force = true)
    end
end
