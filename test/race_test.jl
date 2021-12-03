function _read(valfn)
    try; return parse(Int, read(valfn, String))
    catch ingored end
    return 0
end

let
    @info("Running race tests")
    lkfn = joinpath(@__DIR__, "lock")
    valfn = joinpath(@__DIR__, "sum.txt")
    try
        script = joinpath(@__DIR__, "race_script.jl")
        @assert isfile(script)
        
        rm(valfn; force = true)
        rm(lkfn; force = true)
        write(valfn, "0")

        currptoj = Base.current_project(@__DIR__)
        proc = nothing
        julia_cmd = Base.julia_cmd()
        nprocs = 3
        for t in 1:nprocs
            run(`$(julia_cmd) --project=$(currptoj) --startup-file=no $(script)`; wait = false)
        end
        # wait
        mt0 = -1
        val = 0
        N = nprocs * 100 # Each proc should add 100 to val
        while true
            sleep(1.0)
            
            val = _read(valfn)
            mt = mtime(valfn)
            iszero(mt) && continue
            val != 0 && (mt == mt0) && break
            mt0 = mt

            print(val, "/", N, "\r")
        end
        println(val, "/", N)
        @test val >= N * 0.99 # > 99% success
    
    finally
        rm(lkfn; force = true)
        rm(valfn; force = true)
    end
end