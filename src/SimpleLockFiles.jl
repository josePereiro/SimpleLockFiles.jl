#TODO: add callbacks (eg. onwaiting, ontout, etc...)
#TODO: add etime (error time), after such time, if the lock is stil... well locked, throw an error
module SimpleLockFiles

    import Random: randstring

    include("core.jl")

    export SimpleLockFile
    export lock_path, rand_lkid
    export acquire_lock, force_unlock, unlock
    export lock

end
