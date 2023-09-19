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
        script = joinpath(@__DIR__, "race_script.jl")
        @assert isfile(script)
        
        rm(valfn; force = true)
        rm(lkfn; force = true)
        rm(logfn; force = true)
        write(valfn, "0")

        currptoj = Base.current_project(@__DIR__)
        
        nprocs = 10
        @info("Spawning $(nprocs) competing processes")
        for t in 1:nprocs
            
            # run this for debug
            # julia_cmd = strip(string(Base.julia_cmd()), ['`'])
            # plogfn = joinpath(@__DIR__, "log$(t).txt")
            # jlsrc = "$(julia_cmd) --project=$(currptoj) --startup-file=no $(script) 2>&1 > $(plogfn)"
            # run(`bash -c $(jlsrc)`; wait = false)
            
            julia_cmd = Base.julia_cmd()
            run(`$(julia_cmd) -t1 -O0 --project=$(currptoj) --startup-file=no $(script)`; wait = false)
            
            sleep(0.1)
        end
        # wait
        mt0 = -1
        val = 0
        N = nprocs * 50 # must match the value N on race_script.jl
        
        @info("Reading")
        print(val, "/", N, "\r")
        @time for _ in 1:nprocs
            while true
                sleep(1.0)
                
                val = _read(valfn)
                mt = mtime(valfn)
                iszero(mt) && continue
                val != 0 && (mt == mt0) && break
                mt0 = mt

                print(val, "/", N, "\r")
            end
            if (val == N) 
                println(val, "/", N, "       ")
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