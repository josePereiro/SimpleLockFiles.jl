# ----------------------------------------------------------------------
# type
struct SimpleLockFile <: Base.AbstractLock
    path::AbstractString
end

# ----------------------------------------------------------------------
# lkid
function _currtask_id(pid::Integer, thr::Integer, t::Task)
    # task 
    # from show(stdout, t::Task)
    ref = string(convert(UInt, pointer_from_objref(t)), base = 16, pad = Sys.WORD_SIZE>>2)
    _task_str = string("tsk_@0x", ref)
    # pid
    _pid_str = string("pid_", pid)
    # thread
    _thr_str = string("thr_", thr)
    return string(_pid_str, "_", _thr_str, "_", _task_str)
end

# ----------------------------------------------------------------------
# _lock_file
const _LOCK_FILE_SEP = "^^"
_validate_id(lock_id::AbstractString) = 
    contains(lock_id, _LOCK_FILE_SEP) && 
        error("Separator '", _LOCK_FILE_SEP, "' found in the lock id")


# all in seconds
const _LOCK_DFT_TIME_OUT = Inf 
const _LOCK_DFT_RETRY_TIME = 0.3
const _LOCK_DFT_VALID_TIME = Inf
const _LOCK_DFT_CHECK_TIME = 0.1

# write
function _write_lock_file(lf::AbstractString;
        lkid::AbstractString = currtask_id(), 
        valid_time::Float64 = _LOCK_DFT_VALID_TIME
    )
    _validate_id(lkid)
    mkpath(dirname(lf))
    ttag = time() + valid_time
    write(lf, string(lkid, _LOCK_FILE_SEP, ttag))
    return (lkid, ttag)
end

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
    catch; end
    return ("", -1.0)
end


function _read_lock_file_if_necesary(lf, lread, lmtime)
    needread = isnothing(lread) # no data provided
    needread |= (lmtime != mtime(lf)) # or file changed
    return needread ? _read_lock_file(lf) : lread
end

# ----------------------------------------------------------------------
# _lock_status

_is_valid_ttag(ttag::Number) = ttag > time()
_is_valid_ttag(ttag) = false

const _LOCKED_BY_OTHER = -1
const _LOCKED_BY_ME = 1
const _UNLOCKED = 0

function _lock_status(lf::AbstractString, lkid::AbstractString;
        lread = nothing, 
        lmtime = nothing
    )

    # check file
    !isfile(lf) && return _UNLOCKED
    
    # read if necesary or modify
    curr_lid, ttag = _read_lock_file_if_necesary(lf, lread, lmtime)

    # del if invalid
    if !_is_valid_ttag(ttag)
        _unlock(lf, lkid; force = true)
        return _UNLOCKED
    end

    # test mine or someone else
    return lkid == curr_lid ? _LOCKED_BY_ME : _LOCKED_BY_OTHER
end

# ----------------------------------------------------------------------
# _unlock
function _unlock(lf::AbstractString, lkid::AbstractString; force = false)
    force && rm(lf; force = true)
    isfile(lf) || return true
    _lock_status(lf, lkid)  == _LOCKED_BY_ME || return false
    rm(lf; force = true)
    return true
end

# ----------------------------------------------------------------------
# _try_lock

# TODO: make it return (tryid, ownerid, ttag)
function _try_lock(lf::AbstractString, lkid::AbstractString;
        valid_time = _LOCK_DFT_VALID_TIME, 
        lread = nothing, 
        lmtime = nothing
    )
    if isfile(lf)
        lkid0, ttag = _read_lock_file_if_necesary(lf, lread, lmtime)
        # check if it is taken
        if _is_valid_ttag(ttag)
            # (tryid, ownerid, ttag)
            return (lkid, lkid0, ttag)
        else
            # del if invalid
            _unlock(lf, lkid; force = true)
        end
    end
    lkid, ttag = _write_lock_file(lf; lkid, valid_time)
    # (tryid, ownerid, ttag)
    return (lkid, lkid, ttag)
end

# ----------------------------------------------------------------------
# _acquire_lock

function _acquire_lock(lf::AbstractString, lkid::AbstractString;
        valid_time = _LOCK_DFT_VALID_TIME, 
        retry_time = _LOCK_DFT_RETRY_TIME, 
        time_out = _LOCK_DFT_TIME_OUT,
        recheck_time = _LOCK_DFT_CHECK_TIME,
        force = false
    )
    # starting file state
    lmtime = mtime(lf)
    lread = _read_lock_file(lf)

    # starting file state
    t0 = time()
    # try to _acquire till time_out
    while time_out > 0.0
        lkid, lkid0, _ = _try_lock(lf, lkid; valid_time, lread, lmtime)
        if lkid == lkid0
            sleep(recheck_time) # wait before confirm
            _lock_status(lf, lkid; lread, lmtime) == _LOCKED_BY_ME && return true
        end
        time() - t0 > time_out && break
        sleep(retry_time)
    end
    !force && return false
    # time_out < 0.0 || force && time_out
    _unlock(lf, lkid; force)
    lkid, lkid0, _ = _try_lock(lf, lkid; valid_time, lread, lmtime)
    return lkid0 == lkid
end
