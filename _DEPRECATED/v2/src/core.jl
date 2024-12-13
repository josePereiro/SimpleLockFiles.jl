# ----------------------------------------------------------------------
# type
struct SimpleLockFile <: Base.AbstractLock
    pidfile_path::AbstractString
    reelk::ReentrantLock
    extras::Dict

    function SimpleLockFile(pidfile_path) 
        lk = new(pidfile_path, ReentrantLock(), Dict())
        return lk
    end
end

function _check_validity(lkf::AbstractString, stale_age = Inf)
    pid, host, age = Pidfile.parse_pidfile(lkf)
    isval = Pidfile.isvalidpid(host, pid)
    # stale_age == 0 means disable
    isval = isval && stale_age > 0 && age < stale_age 
    # isval || rm(lkf; force = true)
    return isval
end

function _its_mypid(lkf::AbstractString)
    pid, host, _ = Pidfile.parse_pidfile(lkf)
    val = Pidfile.isvalidpid(host, pid)
    # val || rm(lkf; force = true)
    return val ? getpid() == Int(pid) : false
end
