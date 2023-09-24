function _read(valfn)
    try; return parse(Int, read(valfn, String))
    catch ingored end
    return 0
end

let
    @info("Running race tests")
    # must match the values on race_script.jl
    lkfn = joinpath(@__DIR__, "lock")
    valfn = joinpath(@__DIR__, "sum.txt")
    logfn = joinpath(@__DIR__, "log.txt")
    try
        rm(valfn; force = true)
        rm(lkfn; force = true)
        rm(logfn; force = true)
        write(valfn, "0")

        nprocs = 10
        @info("Spawning $(nprocs) racing processes")
        for t in 1:nprocs
            
            julia_cmd = Base.julia_cmd()
            currptoj = Base.active_project()
            script = joinpath(@__DIR__, "race_script.jl")
            @assert isfile(script)
            run(`$(julia_cmd) -t1 -O0 --project=$(currptoj) --startup-file=no $(script)`; wait = false)
            
            sleep(0.1)
        end
        # wait
        mt0 = -1
        val = 0
        Ni = 100 # IMPORTANT: must be the same at race_script.jl
        N = nprocs * Ni 
        
        @info("Reading")
        print(val, "/", N, "      \r")
        @time for _ in 1:nprocs
            while true
                sleep(1.0)
                
                val = _read(valfn)
                mt = mtime(valfn)
                iszero(mt) && continue
                val != 0 && (mt == mt0) && break
                mt0 = mt

                print(val, "/", N, "      \r")
            end
            if (val == N) 
                println(val, "/", N, "            ")
                break
            end

            println(val, "/", N)
            println("waiting...")
            sleep(3.0)
        end
        ok_res = val >= N * 0.99 # > 99% success
        @test ok_res

        # deb info
        if !ok_res && isfile(logfn)
            println("\n\n", "-"^60)
            println("LOG", "\n")
            println(read(logfn, String))
            println("\n\n", "-"^60)
        end
    
    finally
        rm(lkfn; force = true)
        rm(valfn; force = true)
        rm(logfn; force = true)
    end
end