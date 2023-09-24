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
        Base.Threads.@threads for it in 1:100
            lock(slf) do
                @test islocked(slf)
            end
            sleep(0.01) # safety delay
        end
        
        # # Test Nested lock calls
        # # This differs from Base.lock stuff but at the end one 
        # # Same task
        # rm(slf; force = true)
        # @time for ti in 1:200
        #     flags = []
        #     lock(slf) do
        #         lock(slf) do # This will be relocked
        #             push!(flags, 1) # Must be first element
        #         end
        #         push!(flags, 2) # Must be second element
        #     end 
        #     @test issorted(flags)
        # end

        # # Multiple tasks
        # rm(slf; force = true)
        # @time for ti in 1:200
        #     flags = []
        #     t0 = lock(slf) do
        #         _t0 = @async lock(slf) do # different task must wait
        #             @async lock(slf) do # different task must wait
        #                 @async lock(slf) do # different task must wait
        #                     push!(flags, 4) 
        #                 end
        #                 push!(flags, 3) 
        #             end
        #             push!(flags, 2)
        #         end
        #         push!(flags, 1) # Must be first element
        #         _t0
        #     end 
        #     wait(t0)
        #     @test issorted(flags)
        # end
    finally
        # clear
        rm(lkfn; force = true)
    end
end
