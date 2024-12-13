# SimpleLockFiles

[![CI](https://github.com/josePereiro/SimpleLockFiles.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/josePereiro/SimpleLockFiles.jl/actions/workflows/CI.yml)
[![Coverage](https://codecov.io/gh/josePereiro/SimpleLockFiles.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/josePereiro/SimpleLockFiles.jl)


It provides an object which implement `Base` lock interface combining `ReentrantLock`s and `Pidfile`s.
This way both intra and inter processes locking is achived. 

```julia
using SimpleLockFiles
using Base.Threads

path = joinpath(@__DIR__, ".lock")
lk = SimpleLockFile(path) 

@threads for it in 1:10
    lock(lk) do # 
        println(it, "::", getpid())
        sleep(1.0)
    end
end
```

If the above code is the content of `test.jl`, you can run the follow test.

```bash
julia -t2 test.jl & ; julia -t2 test.jl & 
```

You will see that the print run in serie, even if there are two processes and each one is threaded. Output: 

```bash
7::20386
8::20386
4::20386
5::20386
4::20419
5::20419
6::20386
6::20419
1::20386
7::20419
8::20419
9::20419
2::20386
3::20386
10::20419
1::20419
2::20419
9::20386
3::20419
10::20386
[2]  + 20419 done       julia -t2 --project test.jl
[1]  + 20386 done       julia -t2 --project test.jl
```

See `./test` for more examples.
