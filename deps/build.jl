function find_gpp()
    @static if is_windows()
        #TODO, is this really the hardcoded way to get the WinRPM path to g++ ?
        gpp = Pkg.dir("WinRPM","deps","usr","x86_64-w64-mingw32","sys-root","mingw","bin","g++")
        if !isfile(gpp*".exe")
            info("g++ not found. installing gcc-c++ using WinRPM")
            @eval using WinRPM
            WinRPM.install("gcc-c++"; yes = true)
            WinRPM.install("gcc"; yes = true)
            WinRPM.install("headers"; yes = true)
        end
        RPMbindir = Pkg.dir("WinRPM","deps","usr","x86_64-w64-mingw32","sys-root","mingw","bin")
        incdir = Pkg.dir("WinRPM","deps","usr","x86_64-w64-mingw32","sys-root","mingw","include")
        push!(Base.Libdl.DL_LOAD_PATH, RPMbindir) # TODO does this need to be reversed?
        ENV["PATH"] = ENV["PATH"] * ";" * RPMbindir;
        return gpp, incdir, "dll"
    end
    @static if is_unix()
        if success(`g++ --version`)
            return "g++", "", "so"
        else
            error("no g++ found. Please install a version > 4.5")
        end
    end
end

path = joinpath(dirname(@__FILE__), "..", "src")

if success(`where cl.exe`) && iswindows()
    info("Compiling with cl.exe")
    run(`cl.exe /D_USRDLL /D_WINDLL /EHsc /Fo$(path) $(path)cclipper.cpp $(path)clipper.cpp /MT /link /DLL /OUT:$(path)cclipper.dll`)
else
    # Note: on Mac OS X, g++ is aliased to clang++.
    gpp, incdir, ext = find_gpp()
    cd(path) do
        run(`$gpp -c -fPIC -std=c++11 clipper.cpp cclipper.cpp -I $incdir`)
        run(`$gpp -shared -o cclipper.$ext clipper.o cclipper.o`)
    end
end
