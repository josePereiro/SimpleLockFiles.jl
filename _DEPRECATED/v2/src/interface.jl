SimpleLockFile() = SimpleLockFile(tempname())

lockpath(slf::SimpleLockFile) = slf.pidfile_path
# For others to import
lockpath!(slf::SimpleLockFile, fn::AbstractString) = error("SimpleLockFile is immutable")

_stale_age(slf::SimpleLockFile) = get!(slf.extras, "stale_age", 0.0)::Float64
_LockMonitor(slf::SimpleLockFile) = 
    get!(slf.extras, "_Pidfile.LockMonitor", nothing)::Union{Pidfile.LockMonitor, Nothing}

import Base.lock

# lock both ReentrantLock and pidfile
# function Base.lock(f::Function, slf::SimpleLockFile; kwargs...)
#     return lock(slf.reelk) do
#         lkp = lockpath(slf)
#         # _its_mypid(lkp) && return f() # To allow nested locks
#         monitor = nothing
#         val = nothing
#         try
#             mkpath(slf)
#             stale_age = _stale_age(slf)
#             monitor = Pidfile.mkpidlock(lkp; stale_age, kwargs...) 
#             slf.extras["_Pidfile.LockMonitor"] = monitor
#             val = f()
#         finally
#             slf.extras["_Pidfile.LockMonitor"] = nothing
#             isnothing(monitor) || close(monitor)
#             # rm(slf; force = true)
#         end
#         return val
#     end
# end

# lock both ReentrantLock and pidfile
function Base.lock(slf::SimpleLockFile; kwargs...) 
    lkp = lockpath(slf)
    # _its_mypid(lkp) && return f() # To allow nested locks
    # TODO: find a way to check if I have slf.reelk
    mkpath(slf)
    stale_age = _stale_age(slf)
    monitor = Pidfile.mkpidlock(lkp; stale_age, kwargs...)
    # lock(slf.reelk) # TODO: test this with nested lock calls
    slf.extras["_Pidfile.LockMonitor"] = monitor # see that slf.reelk is locked!
    return slf
end

function Base.lock(f::Function, slf::SimpleLockFile; force = false, kwargs...)
    try; lock(slf,; kwargs...)
        return f()
    finally
        unlock(slf; force)
    end
end

import Base.islocked
function Base.islocked(slf::SimpleLockFile) 
    # islocked(slf.reelk) && return true
    # lkp = lockpath(slf)
    # stale_age = _stale_age(slf)
    # val = _check_validity(lkp, stale_age)
    # check mine
    lk = _LockMonitor(slf)
    if !isnothing(lk)
        isopen(lk.fd) && return true 
    else
        return false
    end
    # !isnothing(lk) && isopen(lk.fd) && return true 
    # check other
    # return val
end

import Base.unlock
function Base.unlock(slf::SimpleLockFile; force = false) 
    # legal way
    lk = _LockMonitor(slf)
    if !isnothing(lk) 
        close(lk)
    end
    # islocked(slf.reelk) && unlock(slf.reelk)

    force && rm(lkp; force = true)
    # lkp = lockpath(slf)
    # val = _check_validity(lkp) # rm if invalid
    close(lk)
end

# ----------------------------------------------------------------------
# File handling
import Base.isfile
isfile(slf::SimpleLockFile) = isfile(lockpath(slf))

import Base.rm
rm(slf::SimpleLockFile; kwargs...) = rm(lockpath(slf); kwargs...)

import Base.basename
basename(slf::SimpleLockFile) = basename(lockpath(slf))

import Base.mkpath
mkpath(slf::SimpleLockFile) = mkpath(dirname(lockpath(slf)))

# ----------------------------------------------------------------------