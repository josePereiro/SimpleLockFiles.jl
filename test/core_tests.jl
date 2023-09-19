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
    valid_time = 3.0
    lid3, ttag3 = write_lock_file(slf; valid_time)
    @test !isempty(lid3)
    @test ttag3 > time()
    @test isfile(slf)
    
    @test islocked(slf, lid3)
    
    time_out = valid_time / 10.0
    @assert valid_time > time_out
    ok_flag = Ref{Bool}()
    lock(slf, "IMPOSTOR!"; ok_flag, time_out, force = false) # This must be taken
    @test !ok_flag[]
    
    sleep(1.3 * valid_time) # expire lock
    
    @test !islocked(slf, lid3)
    @test !isfile(slf) # islocked must delete an invalid lock file
    
    valid_time = 50.0
    ok_flag = Ref{Bool}()
    lock(slf; ok_flag, valid_time) # This must be free
    @test ok_flag[]
    lid4, ttag4 = read_lock_file(slf)
    @test ttag4 > ttag3
    @test isfile(slf)
    
    # test wait
    ok_flag = Ref{Bool}()
    lock(slf, "IMPOSTOR!"; ok_flag, time_out = 2.0, force = false) # This must fail
    @test !ok_flag[]
    _, ttag5 = read_lock_file(slf)
    @test ttag4 == ttag5
    
    # Test release
    @test islocked(slf, lid4)
    @test unlock(slf, lid4)
    @test !islocked(slf, lid4)
    @test !isfile(slf)
    
    # base.lock
    lkid6 = currtask_id()
    run_test = false
    ok_flag = Ref{Bool}()
    lock(slf, lkid6; ok_flag, valid_time = 5.0) do
        # all this time the lock is taken
        for it in 1:10
            @test islocked(slf, lkid6)
            @test !islocked(slf, "No $(lkid6)")
            sleep(0.1) # 0.1 x 10 < 5.0
            run_test = true
        end
    end
    @test ok_flag[] # this must be a successful lock process
    @test run_test
    @test !isfile(slf) # released!
        
    # Test unlock forced unlock
    lkid7 = currtask_id()
    run_test = false
    ok_flag = Ref{Bool}()
    lock(slf, lkid7; ok_flag, valid_time = 15.0) do
        unlock(slf, "No $(lkid7)") # this must do nothing
        @test islocked(slf, lkid7)
        unlock(slf; force = true) # Boom
        @test !isfile(slf) # Now must be free
        @test !islocked(slf, lkid7)
        run_test = true
    end
    @test run_test
    @test !ok_flag[] # The forced unlock invalidate the lock process

    # clear
    rm(slf; force = true)

end
