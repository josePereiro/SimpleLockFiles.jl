using SimpleLockFiles

## ----------------------------------------
function _read(valfn)
    try; return parse(Int, read(valfn, String))
    catch ignored end
    return -1
end

function _write(valfn, val)
    try; write(valfn, string(val))
    catch ignored end
    return nothing
end

function _append(valfn, val)
    try; open((io) -> println(io, val), valfn, "a")
    catch ignored end
    return nothing
end

## ----------------------------------------
# OS
@async let
    while true
        println("pid: ", getpid(), ", running!")
        sleep(1.0)
    end
end

## ----------------------------------------
try
    println("Hi from ", getpid())

    
    Ni = 100 # IMPORTANT: must be the same at race_test.jl
    lkfn = joinpath(@__DIR__, "lock")
    valfn = joinpath(@__DIR__, "sum.txt")
    logfn = joinpath(@__DIR__, "log.txt")
    slf = SimpleLockFile(lkfn)
    
    val = 0
    it = 0
    t0 = time()
    frec = 0.0
    
    lock_kwargs = (;time_out = Inf, valid_time = Inf, retry_time = 1e-2, recheck_time = 1e-3, force = false)
    while true
        # lkid = string("PROC-", getpid(), "-", it)
        # println("Iter init", lkid)
        ok_flag = Ref{Bool}()
        lock(slf; ok_flag, lock_kwargs...) do

            touch(valfn)
            val = _read(valfn)
            val += 1
            _write(valfn, val)

            # info
            frec = time() - t0
            msg = string("pid: ", getpid(), ", it: ", it, ", val: ", val, ", frec [s]: ", frec)
            _append(logfn, msg); println(msg); flush.([stdout, stderr])
            t0 = time()
            it += 1
        end
        println("Iter finished, ok_flag: ", ok_flag[])
        it == Ni && break
        sleep(0.1 * rand())
    end # while true
    
    msg = string("pid: ", getpid(), ", it: ", it, ", val: ", val, " GOOD BYE, MY WORK IS DONE!")
    _append(logfn, msg); println(msg); flush.([stdout, stderr])

catch err
    println()
    showerror(stdout, err, catch_backtrace())
    println()
finally
    flush.([stdout, stderr])
    sleep(15.0)
    exit()
end