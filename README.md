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

You will also need to have a version of visual studio installed, at least as new as VS 2017.

To build, use the command
```
zig build run
```
to build and run the project.

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
zig build -Dtarget=x86_64-native-msvc
```

## VSCode

Debugging through VS Code is supported for this project.  You will need the C/C++ extension for VSCode, and you may also need to check "Debug: Allow Breakpoints Everywhere" in File -> Preferences -> Settings.  The project has debug configurations set up for debugging both debug and release builds.  For a better browsing and editing experience, also check out the Zig Language Server: https://github.com/zigtools/zls.

## Building your own versions of the third-party libraries

This project vendors pre-built lib files for SDL and vulkan-1. vulkan-1.lib comes directly from the Lib folder of the SDK.  SDL.lib was built from the visual studio project distributed with the official SDL source, with two modifications: the "HAVE_LIBC" preprocessor define was added to the project files, in order to avoid duplicate symbols when linking, and the Runtime Library was switched from /MD to /MT, in order to be compatible with Zig's linking style.

## Structure of this repo

* c_src: Libraries and stubs for C code.  In this case, just VMA.
* include: Zig files which provide extern declarations for C libraries
* lib: Precompiled binaries for third party dependencies
* shaders: Shader source files, in hlsl
* src: Zig source for the project
* build.zig: Build script

## Future Work

There's still more that can be done on this port.  So far, Zig doesn't have a build script port of SDL's extremely complicated CMakeLists.txt.  But in theory such a thing could be made, and with it we could compile SDL from source with `zig cc`, and link the .o files in directly without creating a static library.  With that, cross-compiling this project would be trivial.
