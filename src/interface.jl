# ----------------------------------------------------------------------
# SimpleLockFile interface

SimpleLockFile() = SimpleLockFile(tempname())

lockpath(slf::SimpleLockFile) = slf.pidfile_path
# For others to import
lockpath!(slf::SimpleLockFile, fn::AbstractString) = error("SimpleLockFile is immutable")

# ----------------------------------------------------------------------
# defaults

const SLF_DEAFAULT_STALE_AGE = 3.0
const SLF_DEAFAULT_REFRESH_TIME = 1.0
const SLF_DEAFAULT_PULL_INTERVAL = 0.5

# ----------------------------------------------------------------------
# Lock interface

import Base.lock
function Base.lock(slf::SimpleLockFile;
        stale_age = get(slf.extras, "stale_age", SLF_DEAFAULT_STALE_AGE)::Float64,
        refresh = get(slf.extras, "refresh", SLF_DEAFAULT_REFRESH_TIME)::Float64,
        poll_interval = get(slf.extras, "poll_interval", SLF_DEAFAULT_PULL_INTERVAL)::Float64,
    )
    # reelk
    lock(slf.reelk) 

    # pidfile
    if !isnothing(slf.mon)  
        unlock(slf.reelk) # avoid unsync between pidfile and reelk state
        throw(SimpleLockFileError(string(
            "'lock' call without matching 'unlock', file: ", 
            lockpath(slf)
        )))
    end

    mkpath(slf)
    slf.mon = mkpidlock(slf.pidfile_path; stale_age, refresh, poll_interval) 
    return slf
end

import Base.lock
function Base.unlock(slf::SimpleLockFile; force = false)

    # pidfile
    if isnothing(slf.mon) 
        force && rm(slf.pidfile_path; force = true) # Think about it
        throw(SimpleLockFileError(string(
            "'unlock' call without matching 'lock'. file: ", 
            lockpath(slf)
        )))
    end
    close(slf.mon)
    force && rm(slf.pidfile_path; force = true)
    slf.mon = nothing

    # reelk
    unlock(slf.reelk) 

    return slf
end

function Base.lock(f::Function, slf::SimpleLockFile; force = false, kwargs...)
    try; lock(slf; kwargs...)
        return f()
    finally
        unlock(slf; force)
    end
end

function islocked_pidfile(slf::SimpleLockFile) 
    # Ignoring the monitor, all checks depending on the file
    isfile(slf.pidfile_path) || return false
    # trymkpidlock return false if try failed
    stale_age = get(slf.extras, "stale_age.islock", 5 * SLF_DEAFAULT_STALE_AGE)::Float64
    _success = trymkpidlock(slf.pidfile_path; stale_age) do
        return true
    end
    return !_success
end

import Base.islocked
function Base.islocked(slf::SimpleLockFile) 
    # reelk
    _islocked_reelk = islocked(slf.reelk)
    
    # pidfile
    _islocked_pidfile = islocked_pidfile(slf)

    # This is legal
    # reelk = :unlocked
    # pidfile = :locked
    # This illegal
    # reelk = :locked
    # pidfile = :unlocked
    # TODO: TAI: make it an error
    (_islocked_reelk && !_islocked_pidfile) && 
        @warn(
            "unsync lock state!!!", 
            reelk = _islocked_reelk ? :locked : :unlocked, 
            pidfile = _islocked_pidfile ? :locked : :unlocked
        )

    return _islocked_pidfile | _islocked_reelk
end

# ----------------------------------------------------------------------
# File interface

import Base.isfile
isfile(slf::SimpleLockFile) = isfile(lockpath(slf))

import Base.rm
rm(slf::SimpleLockFile; kwargs...) = rm(lockpath(slf); kwargs...)

import Base.basename
basename(slf::SimpleLockFile) = basename(lockpath(slf))

import Base.mkpath
mkpath(slf::SimpleLockFile) = mkpath(dirname(lockpath(slf)))

# ----------------------------------------------------------------------