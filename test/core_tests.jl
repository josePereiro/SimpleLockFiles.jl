let
    @info("Running core tests")
    lkfn = tempname()
    slf = SimpleLockFile(lkfn)

    @test lock_path(slf) == lkfn

    # Test write and read
    lid1, ttag1 = write_lock_file(slf)
    lid2, ttag2 = read_lock_file(slf)

    @test lid1 == lid2
    @test ttag1 == ttag2
    
    # Test valid period
    vtime = 3.0
    lid3, ttag3 = write_lock_file(slf; vtime)
    @test !isempty(lid3)
    @test ttag3 > time()
    @test isfile(slf)
    
    @test islocked(slf, lid3)
    
    tout = vtime / 10.0
    @assert vtime > tout
    ok_flag = lock(slf; tout, force = false) # This must be taken
    @test !ok_flag
    
    sleep(1.3 * vtime) # expire lock
    
    @test !islocked(slf, lid3)
    @test !isfile(slf) # islocked must delete an invalid lock file
    
    vtime = 50.0
    ok_flag = lock(slf; vtime) # This must be free
    @test ok_flag
    lid4, ttag4 = read_lock_file(slf)
    @test ttag4 > ttag3
    @test isfile(slf)
    
    # test wait
    ok_flag = lock(slf; tout = 2.0, force = false) # This must fail
    @test !ok_flag
    _, ttag5 = read_lock_file(slf)
    @test ttag4 == ttag5
    
    # Test release
    @test islocked(slf, lid4)
    @test unlock(slf, lid4)
    @test !islocked(slf, lid4)
    @test !isfile(slf)
    
    # base.lock
    lkid6 = rand_lkid()
    run_test = false
    ok_flag = lock(slf, lkid6; vtime = 5.0) do
        # all this time the lock is taken
        for it in 1:10
            @test islocked(slf, lkid6)
            @test !islocked(slf, "No $(lkid6)")
            sleep(0.1) # 0.1 x 10 < 5.0
            run_test = true
        end
    end
    @test ok_flag # this must be a successful lock process
    @test run_test
    @test !isfile(slf) # released!
        
    # Test unlock forced unlock
    lkid7 = rand_lkid()
    run_test = false
    ok_flag = lock(slf, lkid7; vtime = 15.0) do
        unlock(slf, "No $(lkid7)") # this must do nothing
        @test islocked(slf, lkid7)
        unlock(slf; force = true) # Boom
        @test !isfile(slf) # Now must be free
        @test !islocked(slf, lkid7)
        run_test = true
    end
    @test run_test
    @test !ok_flag # The forced unlock invalidate the lock process

    # clear
    rm(slf; force = true)

end
