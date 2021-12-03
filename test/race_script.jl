using SimpleLockFiles

## ----------------------------------------
function _read(valfn)
    try; return parse(Int, read(valfn, String))
    catch ingored end
    return -1
end

function _write(valfn, val)
    try; write(valfn, string(val))
    catch ingored end
    return nothing
end

## ----------------------------------------
let
    lkfn = joinpath(@__DIR__, "lock")
    valfn = joinpath(@__DIR__, "sum.txt")
    slf = SimpleLockFile(lkfn)

    N = 100
    for it in 1:N
        lock(slf; tout = 15.0, wt = 0.1, ctime = 0.1) do
            touch(valfn)
            val = _read(valfn)
            val += 1
            _write(valfn, val)
        end
        sleep(1/N)
    end
end