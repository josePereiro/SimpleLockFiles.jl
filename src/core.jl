# ----------------------------------------------------------------------
# type
struct SimpleLockFile <: Base.AbstractLock
    pidfile_path::AbstractString
    reelk::ReentrantLock
    extras::Dict

    SimpleLockFile(pidfile_path) = new(pidfile_path, ReentrantLock(), Dict())
end

function _check_validity(lkf::AbstractString)
    pid, host, _ = Pidfile.parse_pidfile(lkf)
    val = Pidfile.isvalidpid(host, pid)
    val || rm(lkf; force = true)
    return val
end

function _its_mypid(lkf::AbstractString)
    pid, host, _ = Pidfile.parse_pidfile(lkf)
    val = Pidfile.isvalidpid(host, pid)
    val || rm(lkf; force = true)
    return val ? getpid() == Int(pid) : false
end
