#TODO: add callbacks (eg. onwaiting, ontout, etc...)
#TODO: add etime (error time), after such time, if the lock is still... well locked, throw an error. Or add a callback to stalling
module SimpleLockFiles

    # import Base.Threads: threadid
    # import Random: randstring
    import FileWatching: Pidfile

    #! include .
    include("core.jl")
    include("interface.jl")

    export SimpleLockFile
    export lockpath

end