using SimpleLockFiles
const SLF = SimpleLockFiles
using Test

@testset "SLF.jl" begin
    
    lkfn = tempname()
    slf = SLF.SimpleLockFile(lkfn)

    @test SLF.lock_path(slf) == lkfn

    # Test write and read
    lid1, ttag1 = SLF.write_lock_file(slf)
    lid2, ttag2 = SLF.read_lock_file(slf)

    @test lid1 == lid2
    @test ttag1 == ttag2
    
    # Test valid period
    vtime = 3.0
    lid3, ttag3 = SLF.write_lock_file(slf; vtime)
    @test !isempty(lid3)
    @test ttag3 > time()
    @test isfile(slf)

    @test SLF.is_locked(slf, lid3)
    
    lid4, ttag4 = SLF.acquire_lock(slf) # This must be taken
    @test isempty(lid4)
    @test ttag3 == ttag4
    
    sleep(2 * vtime) # expire lock

    @test !SLF.is_locked(slf, lid3)
    @test !isfile(slf) # is_locked must delete an invalid lock file

    vtime = 50.0
    lid4, ttag4 = SLF.acquire_lock(slf; vtime) # This must be free
    @test lid4 != lid3 
    @test ttag4 > ttag3
    @test isfile(slf)

    # test wait
    lid5, ttag5 = SLF.acquire_lock(slf; tout = 2.0) # This must fail
    @test isempty(lid5)
    @test ttag4 == ttag5

    # Test release
    @test SLF.is_locked(slf, lid4)
    @test SLF.release_lock(slf, lid4)
    @test !SLF.is_locked(slf, lid4)
    @test !isfile(slf)

    # base.lock
    lock(slf; vtime = 3.0) do
        # all this time the lock is taken
        for it in 1:10
            @test !SLF.is_locked(slf, "Not a lock id")
            sleep(0.2)
        end
    end
    @test !isfile(slf) # released!

    # clear
    rm(slf; force = true)

end
