# ----------------------------------------------------------------------
# SimpleLockFile
SimpleLockFile() = SimpleLockFile(tempname())

lock_path(slf::SimpleLockFile) = slf.path

read_lock_file(slf::SimpleLockFile) = _read_lock_file(lock_path(slf))

write_lock_file(slf::SimpleLockFile; kwargs...) = _write_lock_file(lock_path(slf); kwargs...)

currtask_id() = _currtask_id(getpid(), threadid(), current_task())

# ----------------------------------------------------------------------
# Base
import Base.isfile
isfile(slf::SimpleLockFile) = isfile(lock_path(slf))

import Base.rm
rm(slf::SimpleLockFile; kwargs...) = rm(lock_path(slf); kwargs...)

import Base.basename
basename(slf::SimpleLockFile) = basename(lock_path(slf))

import Base.dirname
dirname(slf::SimpleLockFile) = dirname(dirname(lock_path(slf)))

import Base.mkpath
mkpath(slf::SimpleLockFile) = mkpath(dirname(lock_path(slf)))

# ----------------------------------------------------------------------
import Base.islocked
"""
    islocked(slf::SimpleLockFile, lkid::AbstractString)::Bool

Check if the lock is still valid and owned by `lkid`
"""
Base.islocked(slf::SimpleLockFile, lkid::AbstractString) = 
    _lock_status(lock_path(slf), lkid) == _LOCKED_BY_ME

"""
    islocked(slf::SimpleLockFile, lkid::AbstractString)::Bool

Check if the lock is still valid. Ignore any id.
"""
Base.islocked(slf::SimpleLockFile) = 
    _lock_status(lock_path(slf), "") != _UNLOCKED

# ----------------------------------------------------------------------
import Base.unlock
"""
    unlock(slf::SimpleLockFile, lkid::AbstractString)

Releases ownership of the lock (if `lkid` is valid).
Return true if succeded. 
"""
Base.unlock(slf::SimpleLockFile, lkid::AbstractString = currtask_id(); force = false) = 
    _unlock(lock_path(slf), lkid; force)

# TODO: implement unlock(_lk) 'ERROR: unlock count must match lock count'
# TODO: implement unlock(_lk) 'ERROR: unlock from wrong thread'
# ----------------------------------------------------------------------
import Base.trylock

function Base.trylock(slf::SimpleLockFile, lkid::AbstractString = currtask_id(); 
        valid_time = _LOCK_DFT_VALID_TIME, 
        recheck_time = _LOCK_DFT_RECHECK_TIME,
    )
    lf = lock_path(slf)
    lkid, lkid0, _ = _try_lock(lf, lkid; valid_time)
    lkid == lkid0 && sleep(recheck_time) # wait before confirm
    _lock_status(lf, lkid; lread, lmtime) == _LOCKED_BY_ME
end

# ----------------------------------------------------------------------
import Base.lock
"""
    lock(f::Function, slf::SimpleLockFile, lkid::AbstractString = currtask_id(); 
        valid_time = $(_LOCK_DFT_VALID_TIME), 
        retry_time = $(_LOCK_DFT_RETRY_TIME), 
        time_out = $(_LOCK_DFT_TIME_OUT),
        recheck_time = $(_LOCK_DFT_RECHECK_TIME),
        force = false
    )

Acquire the lock, execute `f()` with the lock held, and release the lock when f returns.
If the lock is already locked by a different `lkid`, the method waits for it to become available and then executes `f()`.
During waiting, it will sleep `retry_time` seconds before re-attempting to acquire the lock again and again till `time_out` seconds elapsed.
Once acquired the lock the method will wait `recheck_time` and double check that it is still secure (to reduce races).
The acquisition will take at least `recheck_time` seconds and if the double check fails it will keep attempting it till `time_out`.
If acquired, the lock will be consider valid for `valid_time` seconds (no other process/thread asking politely for the lock should get it).
(_**WARNING**_: If `f()` execution time is greater than `valid_time`, the lock can be acquired legally by other owner before it finished. Set `valid_time` to `Inf` for avoiding this).
If `force = true` it will forcefully acquire the lock anyway (after `time_out`) and then executes `f()` (this is a deadlock free configuration).
This method is not fully secure from racing, but it must be ok for slow applications.
Returns f()
"""
function Base.lock(
        f::Function, slf::SimpleLockFile, lkid::AbstractString = currtask_id();
        valid_time = _LOCK_DFT_VALID_TIME, 
        retry_time = _LOCK_DFT_RETRY_TIME, 
        time_out = _LOCK_DFT_TIME_OUT,
        recheck_time = _LOCK_DFT_RECHECK_TIME,
        ok_flag::Ref{Bool} = Ref{Bool}(),
        force = false
    )

    lf = lock_path(slf)
    ok_flag[] = false
    try
        ok_flag[] = _acquire_lock(lf, lkid; force, valid_time, retry_time, time_out, recheck_time)
        ok_flag[] && return f()
    finally
        ok_flag[] = _lock_status(lf, lkid) == _LOCKED_BY_ME
        _unlock(lf, lkid)
    end
    return nothing
end

function Base.lock(slf::SimpleLockFile, lkid::AbstractString = currtask_id(); 
        valid_time = _LOCK_DFT_VALID_TIME, 
        retry_time = _LOCK_DFT_RETRY_TIME, 
        time_out = _LOCK_DFT_TIME_OUT,
        recheck_time = _LOCK_DFT_RECHECK_TIME,
        ok_flag::Ref{Bool} = Ref{Bool}(),
        force = false
    )
    lf = lock_path(slf)
    ok_flag[] = _acquire_lock(lf, lkid; force, valid_time, retry_time, time_out, recheck_time)
    return nothing
end