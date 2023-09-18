# ----------------------------------------------------------------------
# type
struct SimpleLockFile
    path::AbstractString
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

_validate_id(lock_id::AbstractString) = 
    contains(lock_id, _LOCK_FILE_SEP) && 
        error("Separator '", _LOCK_FILE_SEP, "' found in the lock id")


# all in seconds
const _LOCK_DFT_TIME_OUT = Inf 
const _LOCK_DFT_WAIT_TIME = 1.0
const _LOCK_DFT_VALID_TIME = Inf
const _LOCK_DFT_CHECK_TIME = 0.1

function _write_lock_file(lf::AbstractString;
        lkid::AbstractString = rand_lkid(), 
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

function _read_lock_file(lf::AbstractString)
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
function _read_lock_file_if_necesary(lf, lread, lmtime)
    needread = isnothing(lread) # no data provided
    needread |= (lmtime != mtime(lf)) # or file changed
    return needread ? _read_lock_file(lf) : lread
end

# ----------------------------------------------------------------------
# has lock

_is_valid_ttag(ttag) = ttag > time()

function _is_locked(lf::AbstractString, lkid::AbstractString;
        lread = nothing, 
        lmtime = nothing
    )

    # check file
    !isfile(lf) && return false
    
    # read if necesary or modify
    curr_lid, ttag = _read_lock_file_if_necesary(lf, lread, lmtime)

    # del if invalid
    if !_is_valid_ttag(ttag)
        _force_unlock(lf)
        return false
    end

    # test
    return lkid == curr_lid
end

"""
    is_locked(slf::SimpleLockFile, lkid::AbstractString)::Bool

Check if the lock is valid and is owned by `lkid`
"""
is_locked(slf::SimpleLockFile, lkid::AbstractString) = _is_locked(lock_path(slf), lkid)

# ----------------------------------------------------------------------
# release
function _unlock(lf::AbstractString, lkid::AbstractString)
    !isfile(lf) && return false
    !_is_locked(lf, lkid) && return false
    _force_unlock(lf)
    return true
end

import Base.unlock
"""
    unlock(slf::SimpleLockFile, lkid::AbstractString)

Releases ownership of the lock (if `lkid` is valid).
"""
unlock(slf::SimpleLockFile, lkid::AbstractString) = _unlock(lock_path(slf), lkid)

# ----------------------------------------------------------------------
# force_unlock
function _force_unlock(lf::AbstractString) 
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

# TODO: make it return (tryid, ownerid, ttag)
function _try_acquire_once(lf::AbstractString, lkid::AbstractString = rand_lkid();
        vtime = _LOCK_DFT_VALID_TIME, 
        lread = nothing, 
        lmtime = nothing
    )
    if isfile(lf)
        curr_lid, ttag = _read_lock_file_if_necesary(lf, lread, lmtime)
        
        # check if is taken
        if _is_valid_ttag(ttag)
            # (tryid, ownerid, ttag)
            return (lkid, curr_lid, ttag)
        else
            # del if invalid
            _force_unlock(lf)
        end
    end
    lkid, ttag = _write_lock_file(lf; lkid, vtime)
    # (tryid, ownerid, ttag)
    return (lkid, lkid, ttag)
end

function _acquire_lock(lf::AbstractString, lkid::AbstractString = rand_lkid();
        vtime = _LOCK_DFT_VALID_TIME, 
        wtime = _LOCK_DFT_WAIT_TIME, 
        tout = _LOCK_DFT_TIME_OUT,
        ctime = _LOCK_DFT_CHECK_TIME,
        force = false
    )
    # starting file state
    lmtime = mtime(lf)
    lread = _read_lock_file(lf)

    # starting file state
    t0 = time()
    # try to _acquire till tout
    while tout > 0.0
        lkid, lkid0, _ = _try_acquire_once(lf, lkid; vtime, lread, lmtime)
        if lkid == lkid0
            sleep(ctime) # wait before confirm
            _is_locked(lf, lkid; lread, lmtime) && return true
        end
        time() - t0 > tout && break
        sleep(wtime)
    end
    !force && return false
    # tout < 0.0 || force && tout
    force && _force_unlock(lf)
    lkid, lkid0, _ = _try_acquire_once(lf, lkid; vtime, lread, lmtime)
    return lkid0 == lkid
end

acquire_lock(slf::SimpleLockFile, lkid::AbstractString = rand_lkid(); kwargs...) = 
    _acquire_lock(lock_path(slf), lkid; kwargs...)


# ----------------------------------------------------------------------
# Base.lock

import Base.lock
"""
    lock(f::Function, slf::SimpleLockFile, lkid::AbstractString = rand_lkid(); 
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
(_**WARNING**_: If `f()` execution time is greater than `vtime`, the lock can be acquired legally by other owner before it finished. Set `vtime` to `Inf` for avoiding this).
If `force = true` it will forcefully acquire the lock anyway (after `tout`) and then executes `f()` (this is a deadlock free configuration).
This method is not fully secure from racing, but it must be ok for slow applications.
Returns `true` if the locking process was successful (`f()` finished and the lock is still valid).
"""
function Base.lock(
        f::Function, slf::SimpleLockFile, lkid::AbstractString = rand_lkid();
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

Base.lock(slf::SimpleLockFile, lkid::AbstractString = rand_lkid(); kwargs...) = 
    acquire_lock(slf, lkid; kwargs...)