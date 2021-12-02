function _read(valfn)
    try; return parse(Int, read(valfn, String))
    catch ingored end
    return 0
end

let
    @info("Running race tests")
    lkfn = joinpath(@__DIR__, "lock")
    sumfn = joinpath(@__DIR__, "sum.txt")
    try
        script = joinpath(@__DIR__, "race_script.jl")
        @assert isfile(script)

        rm(sumfn; force = true)
        rm(lkfn; force = true)

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

            mt = mtime(sumfn)
            iszero(mt) && continue
            (mt == mt0) && break
            mt0 = mt

            val = _read(sumfn)
            print(val, "/", N, "\r")
        end
        println(val, "/", N)
        @test val >= N * 0.99 # > 99% success
    
    finally
        rm(lkfn; force = true)
        rm(sumfn; force = true)
    end
end