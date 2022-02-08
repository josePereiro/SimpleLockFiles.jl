# ----------------------------------------------------------------------
# type
struct SimpleLockFile
    path::String
end

SimpleLockFile() = SimpleLockFile(tempname())

lock_path(slf::SimpleLockFile) = slf.path

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
# id
rand_lkid(n = 10) = randstring(n)

# ----------------------------------------------------------------------
# write

const _LOCK_FILE_SEP = ","

_validate_id(lock_id::String) = 
    contains(lock_id, _LOCK_FILE_SEP) && 
        error("Separator '", _LOCK_FILE_SEP, "' found in the lock id")


const _LOCK_DFT_TIME_OUT = 0.0
const _LOCK_DFT_WAIT_TIME = 1.0
const _LOCK_DFT_VALID_TIME = 30.0
const _LOCK_DFT_CHECK_TIME = 0.1

function _write_lock_file(lf::String;
        lkid::String = rand_lkid(), 
        vtime::Float64 = _LOCK_DFT_VALID_TIME
    )
    _validate_id(lkid)
    mkpath(dirname(lf))
    ttag = time() + vtime
    write(lf, string(lkid, _LOCK_FILE_SEP, ttag))
    return (lkid, ttag)
end

write_lock_file(slf::SimpleLockFile; kwargs...) = 
    _write_lock_file(lock_path(slf); kwargs...)

# ----------------------------------------------------------------------
# read
function _tryparse(type::Type{T}, str::AbstractString, dft::T) where {T}
    val = tryparse(type, str)
    return isnothing(val) ? dft : val
end

function _read_lock_file(lf::String)
    try
        !isfile(lf) && return ("", -1.0)
        txt = read(lf, String)
        spt = split(txt, _LOCK_FILE_SEP)
        length(spt) != 2 && return ("", -1.0)
        lkid, ttag_str = spt
        ttag = _tryparse(Float64, ttag_str, -1.0)
        return (lkid, ttag)
    catch ignore; end
    return ("", -1.0)
end
read_lock_file(slf::SimpleLockFile) = _read_lock_file(lock_path(slf))

# ----------------------------------------------------------------------
# has lock

_is_valid_ttag(ttag) = ttag > time()

function _is_locked(lf::String, lkid::String)

    !isfile(lf) && return false
    
    # read
    curr_lid, ttag = _read_lock_file(lf)

    # del if invalid
    if !_is_valid_ttag(ttag)
        _force_unlock(lf)
        return false
    end

    # test
    return lkid == curr_lid
end

"""
    is_locked(slf::SimpleLockFile, lkid::String)::Bool

Check if the lock is valid and is owned by `lkid`
"""
is_locked(slf::SimpleLockFile, lkid::String) = _is_locked(lock_path(slf), lkid)

# ----------------------------------------------------------------------
# release
function _unlock(lf::String, lkid::String)
    !isfile(lf) && return false
    !_is_locked(lf, lkid) && return false
    _force_unlock(lf)
    return true
end

import Base.unlock
"""
    unlock(slf::SimpleLockFile, lkid::String)

Releases ownership of the lock (if `lkid` is valid).
"""
unlock(slf::SimpleLockFile, lkid::String) = _unlock(lock_path(slf), lkid)

# ----------------------------------------------------------------------
# force_unlock
function _force_unlock(lf::String) 
    rm(lf; force = true)
    return nothing
end

"""
    force_unlock(slf::SimpleLockFile)

Releases ownership of the lock (even if it is valid).
"""
force_unlock(slf::SimpleLockFile) = _force_unlock(lock_path(slf))

# ----------------------------------------------------------------------
# acquire_lock

function _acquire(lf::String, lkid::String = rand_lkid();
        vtime = _LOCK_DFT_VALID_TIME
    )
    if isfile(lf)
        curr_lid, ttag = _read_lock_file(lf)
        
        # check if is taken
        if _is_valid_ttag(ttag)
            return (curr_lid == lkid) ? 
                (curr_lid, ttag) : # is mine
                ("", ttag) # is taken
        else
            # del if invalid
            _force_unlock(lf)
        end
    end
    return _write_lock_file(lf; lkid, vtime)
end

function _acquire_lock(lf::String, lkid::String = rand_lkid();
        vtime = _LOCK_DFT_VALID_TIME, 
        wtime = _LOCK_DFT_WAIT_TIME, 
        tout = _LOCK_DFT_TIME_OUT,
        ctime = _LOCK_DFT_CHECK_TIME,
        force = false
    )
    ctime = abs(ctime)

    if tout > 0.0
        t0 = time()

        # try to _acquire till tout
        while true
            lkid0, ttag = _acquire(lf, lkid; vtime)
            if !isempty(lkid0) 
                sleep(ctime) # wait before confirm
                _is_locked(lf, lkid) && return (lkid, ttag)
            end

            if (time() - t0) > tout 
                if force 
                    _force_unlock(lf)
                    return _acquire(lf, lkid; vtime)
                else
                    return ("", ttag)
                end
            end
            sleep(wtime)
        end
    else
        force && _force_unlock(lf)
        return _acquire(lf, lkid; vtime)
    end
end

acquire_lock(slf::SimpleLockFile, lkid::String = rand_lkid(); kwargs...) = _acquire_lock(lock_path(slf), lkid; kwargs...)

# ----------------------------------------------------------------------
# Base.lock

import Base.lock
"""
    lock(f::Function, slf::SimpleLockFile, lkid::String = rand_lkid(); 
        vtime = $(_LOCK_DFT_VALID_TIME), 
        wtime = $(_LOCK_DFT_WAIT_TIME), 
        tout = $(_LOCK_DFT_TIME_OUT),
        ctime = $(_LOCK_DFT_CHECK_TIME),
        force = false
    )

Acquire the lock, execute `f()` with the lock held, and release the lock when f returns.
If the lock is already locked by a different `lkid`, the method waits for it to become available and then executes `f()`.
During waiting, it will sleep `wtime` seconds before re-attempting to acquire the lock again and again till `tout` seconds elapsed.
Once acquired the lock the method will wait `ctime` and double check that it is still secure (to reduce races).
The acquisition will take at least `ctime` seconds and if the double check fails it will keep attempting it till `tout`.
If acquired, the lock will be consider valid for `vtime` seconds (no other process/thread asking politely for the lock should get it).
(_**WARNING**_: If `f()` execution time is greater than `vtime`, the lock can be acquired legally by other owner before it finished).
If `force = true` it will forcefully acquire the lock anyway (after `tout`) and then executes `f()` (this is a deadlock free configuration).
This method is not fully secure from racing, but it must be ok for slow applications.
Returns `true` if the locking process was successful (`f()` finished and the lock is still valid).
"""

function lock(
        f::Function, slf::SimpleLockFile, lkid::String = rand_lkid();
        vtime = _LOCK_DFT_VALID_TIME, 
        wtime = _LOCK_DFT_WAIT_TIME, 
        tout = _LOCK_DFT_TIME_OUT,
        ctime = _LOCK_DFT_CHECK_TIME,
        force = false
    )

    lf = lock_path(slf)
    ok_flag = false
    try
        _acquire_lock(lf, lkid; force, vtime, wtime, tout, ctime)
        ok_flag = _is_locked(lf, lkid)
        ok_flag && f()
    finally
        ok_flag = _is_locked(lf, lkid)
        _unlock(lf, lkid)
    end
    
    return ok_flag
end