-- currently only supports vs2010.
-- and premake4 4.4 doesn't have vs2012 support yet. but seems auto upgrade works fine

if _ACTION == 'clean' then
    os.rmdir('./build')
    os.rmdir('./bin')
    os.rmdir('./obj_vs')
    os.rmdir('./obj_gmake')
end

solution('clumsy')
    location("./build")
    configurations({'Debug', 'Release'})
    platforms({'x32', 'x64'})

    project('clumsy')
        language("C")
        files({'src/**.c', 'src/**.h'})
        links({'WinDivert', 'iup', 'comctl32', 'Winmm', 'ws2_32'}) 
        if _ACTION == 'vs2010' then -- only vs can include rc file in solution
            files({'./etc/clumsy.rc'})
        elseif _ACTION == 'gmake' then
            files({'./etc/clumsy.rc'})
        end

        configuration('Debug')
            flags({'ExtraWarnings', 'Symbols'})
            defines({'_DEBUG'})
            kind("ConsoleApp")

        configuration('Release')
            flags({'Optimize'})
            flags({'Symbols'}) -- keep the debug symbols for development
            defines({'NDEBUG'})
            kind("WindowedApp")

        configuration("gmake")
            links({'kernel32', 'gdi32', 'comdlg32', 'uuid', 'ole32'}) -- additional libs
            buildoptions({'-Wno-missing-braces', '--std=c99'}) -- suppress a bug in gcc warns about {0} initialization
            --linkoptions({'--std=c90'})
            -- notice that tdm-gcc use static runtime by default
            objdir('obj_vs')

        configuration("vs*")
            defines({"_CRT_SECURE_NO_WARNINGS"})
            flags({'NoManifest'})
            buildoptions({'/wd"4214"'})
            includedirs({'external/WinDivert-1.1.1-MSVC/include'})
            objdir('obj_gmake')

        configuration({'x32', 'vs*'})
            -- defines would be passed to resource compiler for whatever reason
            -- and ONLY can be put here not under 'configuration('x32')' or it won't work
            defines({'X32'})
            includedirs({'external/iup-3.8_Win32_dll11_lib/include'})
            libdirs({
                'external/WinDivert-1.1.1-MSVC/x86',
                'external/iup-3.8_Win32_dll11_lib'
                })

        configuration({'x64', 'vs*'})
            defines({'X64'})
            includedirs({'external/iup-3.8_Win64_dll11_lib/include'})
            libdirs({
                'external/WinDivert-1.1.1-MSVC/amd64',
                'external/iup-3.8_Win64_dll11_lib'
                })

        configuration({'x32', 'gmake'})
            defines({'X32'}) -- defines would be passed to resource compiler for whatever reason
            includedirs({'external/WinDivert-1.1.1-MINGW/include',
                'external/iup-3.8_Win64_mingw4_lib/include'})
            libdirs({
                'external/WinDivert-1.1.1-MINGW/x86',
                'external/iup-3.8_Win32_mingw4_lib'
                })
            resoptions({'-O coff', '-F pe-i386'}) -- mingw64 defaults to x64

        configuration({'x64', 'gmake'})
            defines({'X64'})
            includedirs({'external/WinDivert-1.1.1-MINGW/include',
                'external/iup-3.8_Win64_mingw4_lib/include'})
            libdirs({
                'external/WinDivert-1.1.1-MINGW/amd64',
                'external/iup-3.8_Win64_mingw4_lib'
                })

        local function set_bin(platform, config, arch)
            local platform_str
            if platform == 'vs*' then
                platform_str = 'vs'
            else
                platform_str = platform
            end
            local subdir = 'bin/' .. platform_str .. '/' .. config .. '/' .. arch
            local divert_lib, iup_lib
            if platform == 'vs*' then 
                if arch == 'x64' then
                    divert_lib = '../external/WinDivert-1.1.1-MSVC/amd64/'
                    iup_lib = '../external/iup-3.8_Win64_dll11_lib'
                else
                    divert_lib = '../external/WinDivert-1.1.1-MSVC/x86/'
                    iup_lib = '../external/iup-3.8_Win32_dll11_lib'
                end
            elseif platform == 'gmake' then
                if arch == 'x64' then
                    divert_lib = '../external/WinDivert-1.1.1-MINGW/amd64/'
                    iup_lib = '../external/iup-3.8_Win64_mingw4_lib'
                else
                    divert_lib = '../external/WinDivert-1.1.1-MINGW/x86/'
                    iup_lib = '../external/iup-3.8_Win32_mingw4_lib'
                end
            end
            configuration({platform, config, arch})
                targetdir(subdir)
                debugdir(subdir)
                if platform == 'vs*' then
                    postbuildcommands({
                        "robocopy " .. divert_lib .." ../"   .. subdir .. '  *.dll *.sys *.inf > robolog.txt',
                        "robocopy " .. iup_lib .. " ../"   .. subdir .. ' iup.dll >> robolog.txt',
                        "robocopy ../etc/ ../"   .. subdir .. ' config.txt >> robolog.txt',
                        "exit /B 0"
                    })
                elseif platform == 'gmake' then 
                    postbuildcommands({
                        -- robocopy returns non 0 will fail make
                        'cp ' .. divert_lib .. "WinDivert.* ../" .. subdir,
                        'cp ' .. divert_lib .. "WdfCoInstaller01009.dll ../" .. subdir,
                        "cp ../etc/config.txt ../" .. subdir,
                    })
                end
        end

        set_bin('vs*', 'Debug', "x32")
        set_bin('vs*', 'Debug', "x64")
        set_bin('vs*', 'Release', "x32")
        set_bin('vs*', 'Release', "x64")
        set_bin('gmake', 'Debug', "x32")
        set_bin('gmake', 'Debug', "x64")
        set_bin('gmake', 'Release', "x32")
        set_bin('gmake', 'Release', "x64")

