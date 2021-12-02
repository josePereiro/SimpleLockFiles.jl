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

# ----------------------------------------------------------------------
# id
const _lock_path_SEP = ","

_validate_id(lock_id::String) = 
    contains(lock_id, _lock_path_SEP) && 
        error("Separator '", _lock_path_SEP, "' found in the lock id")

const _LOCK_ID_DICT = ['a':'z'; 'A':'Z'; '0':'9']
rand_lkid(n = 10) = join(rand(_LOCK_ID_DICT, n))

# ----------------------------------------------------------------------
# write

const _LOCK_DFT_TIME_OUT = 0.0
const _LOCK_DFT_WAIT_TIME = 1.0
const _LOCK_DFT_VALID_TIME = 30.0

function _write_lock_file(lf::String;
        lkid::String = rand_lkid(), 
        vtime::Float64 = _LOCK_DFT_VALID_TIME
    )
    ttag = time() + vtime
    write(lf, string(lkid, _lock_path_SEP, ttag))
    return (lkid, ttag)
end

write_lock_file(slf::SimpleLockFile; kwargs...) = 
    _write_lock_file(lock_path(slf); kwargs...)

# ----------------------------------------------------------------------
# read

function _read_lock_file(lf::String)
    !isfile(lf) && return ("", -1.0)
    txt = read(lf, String)
    spt = split(txt, _lock_path_SEP)
    length(spt) != 2 && return ("", -1.0)
    lkid = spt[1]
    ttag = tryparse(Float64, spt[2])
    ttag = isnothing(ttag) ? -1.0 : ttag
    return (lkid, ttag)
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
            
            if curr_lid == lkid
                return (curr_lid, ttag) # is mine
            else
                return ("", ttag) # is taken
            end
        else
            # del if invalid
            _force_unlock(lf)
        end
    end
    return _write_lock_file(lf; lkid, vtime)
end

function _acquire_lock(lf::String, lkid::String = rand_lkid();
        vtime = _LOCK_DFT_VALID_TIME, 
        wt = _LOCK_DFT_WAIT_TIME, 
        tout = _LOCK_DFT_TIME_OUT,
        force = false
    )
    if tout > 0.0
        t0 = time()
        while true
            lkid0, ttag = _acquire(lf, lkid; vtime)
            !isempty(lkid0) && return (lkid, ttag)
            if (time() - t0) > tout 
                if force 
                    _force_unlock(lf)
                    return _acquire(lf, lkid; vtime)
                else
                    return ("", ttag)
                end
            end
            sleep(wt)
        end
    else
        force && _force_unlock(lf)
        return _acquire(lf, lkid; vtime)
    end
end

acquire_lock(slf::SimpleLockFile, lkid::String = rand_lkid(); kwargs...) = _acquire_lock(lock_path(slf), lkid)

# ----------------------------------------------------------------------
# Base.lock

import Base.lock
"""
    lock(f::Function, slf::SimpleLockFile, lkid::String = rand_lkid(); 
        vtime = $(_LOCK_DFT_VALID_TIME), 
        wt = $(_LOCK_DFT_WAIT_TIME), 
        tout = $(_LOCK_DFT_TIME_OUT),
        force = false
    )

Acquire the lock, execute `f()` with the lock held, and release the lock when f returns.
If the lock is already locked by a different `lkid`, wait (till `tout`) for it to become available.
During waiting, it will sleep `wt` seconds before re-attemping to acquire_lock.
If `force = true` it will acquire_lock the lock after `tout`.
This method is not fully secure to race, but it must be ok for sllow applications.
Returns `true` if the locking process was succeful.
    
WARNING: If `f` execution time if greater than `vtime`, the lock could be acquire by other owner before it finished.

"""
function lock(
        f::Function, slf::SimpleLockFile, lkid::String = rand_lkid();
        vtime = _LOCK_DFT_VALID_TIME, 
        wt = _LOCK_DFT_WAIT_TIME, 
        tout = _LOCK_DFT_TIME_OUT,
        force = false
    )

    lf = lock_path(slf)
    ok_flag = false
    try
        _acquire_lock(lf, lkid; force, vtime, wt, tout)
        f()
    finally
        ok_flag = _is_locked(lf, lkid)
        ok_flag && _unlock(lf, lkid)
    end
    
    return ok_flag
end