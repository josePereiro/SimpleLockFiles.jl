# ----------------------------------------------------------------------
# type
mutable struct SimpleLockFile <: Base.AbstractLock
    pidfile_path::AbstractString
    reelk::ReentrantLock
    mon::Union{Pidfile.LockMonitor, Nothing}
    extras::Dict

    function SimpleLockFile(pidfile_path) 
        lk = new(pidfile_path, ReentrantLock(), nothing, Dict())
        return lk
    end
end
