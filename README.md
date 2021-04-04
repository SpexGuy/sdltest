# sdltest

A simple vulkan + SDL test application in Zig for Windows.

It currently draws a spinning cube and a fullscreen fractal.

This was ported from https://github.com/Honeybunch/sdltest

## Building

This project currently only supports Windows, but I don't believe there's any code outside of the build script that limits it to that platform.  In theory this should be portable to other platforms as long as a static SDL library can be built for that platform.  Some of the bindings may not work properly on big-endian systems.

### Windows

Make sure to have the following tools available on your path:
* zig (master, from https://ziglang.org/download/)
* dxc (part of the Vulkan SDK, from https://vulkan.lunarg.com/sdk/home)

The program uses MSVC libc by default, so you will need VS2017 or later.  Or build with `-Dtarget=native-native-gnu` to use mingw (packaged with zig) instead.

To build and run, use the command
```
zig build run
```

If you want an executable for debugging, use the command
```
zig build
```
to put the executable in `zig-cache/bin/sdltest.exe`.

Zig build supports several flags.  Use `zig build --help` to get a full list.  Some common ones you might want:
```
# build in release mode
zig build -Drelease-fast

# build a redistributable binary
zig build -Dtarget=x86_64-native-gnu
```

## VSCode

Debugging through VS Code is supported for this project.  You will need the C/C++ extension for VSCode, and you may also need to check "Debug: Allow Breakpoints Everywhere" in File -> Preferences -> Settings.  The project has debug configurations set up for debugging both debug and release builds.  For a better browsing and editing experience, also check out the Zig Language Server: https://github.com/zigtools/zls.

## Third-party libraries

This project vendors a pre-built lib file for vulkan-1, which comes directly from the Lib folder of the SDK.

## Structure of this repo

* c_src: Libraries and stubs for C code.  In this case, just VMA.
* include: Zig files which provide extern declarations for C libraries
* lib: Precompiled binaries for third party dependencies
* shaders: Shader source files, in hlsl
* sdl: Copy of the SDL library, with slight modifications (search for "ZIG MOD")
* src: Zig source for the project
* build.zig: Build script

## Future Work

There's still more that can be done on this port.  The build.zig file contains a partial port of SDL's CMakeLists.txt, but this currently only supports windows.  Some more work is needed to add support for other platforms.
