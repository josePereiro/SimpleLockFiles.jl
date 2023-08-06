let
    @info("Running core tests")
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
    
    tout = vtime / 10.0
    @assert vtime > tout
    lid4, ttag4 = SLF.acquire_lock(slf; tout, force = false) # This must be taken
    @test isempty(lid4)
    @test ttag3 == ttag4
    
    sleep(1.3 * vtime) # expire lock
    
    @test !SLF.is_locked(slf, lid3)
    @test !isfile(slf) # is_locked must delete an invalid lock file
    
    vtime = 50.0
    lid4, ttag4 = SLF.acquire_lock(slf; vtime) # This must be free
    @test lid4 != lid3
    @test ttag4 > ttag3
    @test isfile(slf)
    
    # test wait
    lid5, ttag5 = SLF.acquire_lock(slf; tout = 2.0, force = false) # This must fail
    @test isempty(lid5)
    @test ttag4 == ttag5
    
    # Test release
    @test SLF.is_locked(slf, lid4)
    @test SLF.unlock(slf, lid4)
    @test !SLF.is_locked(slf, lid4)
    @test !isfile(slf)
    
    # base.lock
    lkid6 = SLF.rand_lkid()
    run_test = false
    ok_flag = lock(slf, lkid6; vtime = 5.0) do
        # all this time the lock is taken
        for it in 1:10
            @test SLF.is_locked(slf, lkid6)
            @test !SLF.is_locked(slf, "No $(lkid6)")
            sleep(0.1) # 0.1 x 10 < 5.0
            run_test = true
        end
    end
    @test ok_flag # this must be a successful lock process
    @test run_test
    @test !isfile(slf) # released!
        
    # Test unlock force_unlock
    lkid7 = SLF.rand_lkid()
    run_test = false
    ok_flag = lock(slf, lkid7; vtime = 15.0) do
        SLF.unlock(slf, "No $(lkid7)") # this must do nothing
        @test SLF.is_locked(slf, lkid7)
        SLF.force_unlock(slf) # Boom
        @test !isfile(slf) # Now must be free
        @test !SLF.is_locked(slf, lkid7)
        run_test = true
    end
    @test run_test
    @test !ok_flag # The force_unlock invalidate the lock process

    # clear
    rm(slf; force = true)

end
