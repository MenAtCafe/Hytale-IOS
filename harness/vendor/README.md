# vendor

## SDL3.dylib

iOS Simulator (arm64) build of **SDL 3.4.18** with two local patches. It is the
only prebuilt dependency kept in the repository; the upstream trees (SDL,
glslang, SPIRV-Cross) and the CMake toolchain were removed to keep the archive
small.

### Patch 1: preload the shim at load time

In `src/video/SDL_video.c`:

~~~c
__attribute__((constructor))
static void HytaleGL_Preload(void)
{
    Dl_info info;
    if (dladdr((void *)SDL_GL_GetProcAddress, &info) && info.dli_fname) {
        char path[4096];
        size_t len = strlen(info.dli_fname);
        if (len < sizeof(path) - 32) {
            strcpy(path, info.dli_fname);
            char *slash = strrchr(path, '/');
            if (slash) {
                strcpy(slash + 1, "libHytaleGL.dylib");
                dlopen(path, RTLD_NOW | RTLD_GLOBAL);
            }
        }
    }
}
~~~

### Patch 2: consult the shim before SDL's own GL loader

In `SDL_GL_GetProcAddress`:

~~~c
SDL_FunctionPointer SDL_GL_GetProcAddress(const char *proc)
{
    SDL_FunctionPointer func;
    {
        static void *(*gl_hook)(const char *) = NULL;
        static int gl_hook_checked = 0;
        if (!gl_hook_checked) {
            gl_hook = (void *(*)(const char *))dlsym(RTLD_DEFAULT, "HytaleGL_GetProcAddress");
            gl_hook_checked = 1;
        }
        if (gl_hook) {
            void *hooked = gl_hook(proc);
            if (hooked) {
                return (SDL_FunctionPointer)hooked;
            }
        }
    }
    /* ... SDL's original loading path ... */
}
~~~

### Rebuilding from upstream

~~~sh
git clone --depth 1 --branch release-3.4.18 https://github.com/libsdl-org/SDL
# apply the two hunks above
cmake -S SDL -B sdlbuild -G "Unix Makefiles" \
  -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=iphonesimulator \
  -DCMAKE_OSX_ARCHITECTURES=arm64 -DSDL_SHARED=ON -DSDL_STATIC=OFF
cmake --build sdlbuild
# libSDL3.0.dylib -> SDL3.dylib
~~~

The probe bundle is ad-hoc signed by `harness/build.sh` (`codesign --deep`).

## License

SDL3.dylib is built from SDL 3.4.18 and keeps its original zlib license, included
in `SDL3-LICENSE.txt`. This is a modified build: the two patches above are
plainly marked as such, as the license requires.
