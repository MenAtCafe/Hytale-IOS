#include <dlfcn.h>
#include <stdio.h>
int main(void) {
    void *p = dlsym(RTLD_DEFAULT, "SDL_GL_GetProcAddress");
    printf("lookup -> %p\n", p);
    return 0;
}
