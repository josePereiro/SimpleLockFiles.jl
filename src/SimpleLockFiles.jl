module SimpleLockFiles

import Random: randstring

include("core.jl")

export SimpleLockFile
export lock_path, rand_lkid
export acquire_lock, force_unlock, unlock
export lock

end
