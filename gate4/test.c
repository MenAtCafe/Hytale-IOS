#include <dlfcn.h>
#include <stdio.h>

typedef void *(*gpa_t)(const char *);
typedef const char *(*gs_t)(unsigned int);
typedef void (*genq_t)(int, unsigned int *);
typedef void (*bq_t)(unsigned int, unsigned int);
typedef void (*eq_t)(unsigned int);
typedef void (*gq_t)(unsigned int, unsigned int, unsigned int *);
typedef void *(*fs_t)(unsigned int, unsigned int);
typedef unsigned int (*cws_t)(void *, unsigned int, unsigned long long);

int main(int argc, char **argv) {
    if (argc < 2) return 2;
    void *h = dlopen(argv[1], RTLD_NOW);
    if (!h) { printf("dlopen: %s\n", dlerror()); return 1; }
    gpa_t gpa = (gpa_t)dlsym(h, "SDL_GL_GetProcAddress");

    const char *names[] = {
        "glGenBuffers","glBindBuffer","glBufferData","glMapBufferRange","glUnmapBuffer",
        "glCreateShader","glShaderSource","glCompileShader","glCreateProgram","glAttachShader",
        "glLinkProgram","glUseProgram","glGetUniformLocation","glUniformMatrix4fv",
        "glGenVertexArrays","glBindVertexArray","glEnableVertexAttribArray","glVertexAttribPointer",
        "glVertexAttribDivisor","glGenTextures","glBindTexture","glTexImage2D","glTexParameteri",
        "glGenFramebuffers","glBindFramebuffer","glFramebufferTexture2D","glEnable","glDisable",
        "glDepthFunc","glClearColor","glClear","glViewport","glDrawArrays","glDrawElements",
        "glGetError","glGetString","glGenQueries","glDeleteQueries","glBeginQuery","glEndQuery",
        "glGetQueryObjectuiv","glFenceSync","glClientWaitSync","glDeleteSync","glIsSync",
        "glTexImage2DMultisample","glGetResolvedTexture","glScissor","glBlendFunc","glDepthMask",
        "glClearDepth","glActiveTexture","glFinish","glFlush","glDrawArraysInstanced",
        "glDrawElementsInstanced","glReadPixels","glGetBufferSubData","glBindBufferBase",
        "glDispatchCompute","glDeleteBuffers","glDeleteTextures","glDeleteProgram","glDeleteShader"
    };
    int total = (int)(sizeof(names)/sizeof(names[0])), ok = 0;
    for (int i = 0; i < total; i++) if (gpa(names[i])) ok++;
    printf("resolved %d/%d GL entry points via SDL\n", ok, total);

    gs_t gs = (gs_t)gpa("glGetString");
    printf("GL_VERSION -> %s\n", gs ? gs(0x1F02) : "(null)");

    genq_t genq = (genq_t)gpa("glGenQueries");
    bq_t bq = (bq_t)gpa("glBeginQuery");
    eq_t eq = (eq_t)gpa("glEndQuery");
    gq_t gq = (gq_t)gpa("glGetQueryObjectuiv");
    unsigned int q = 0, avail = 0;
    genq(1, &q);
    bq(0x8914, q); eq(0x8914);
    gq(q, 0x8867, &avail);
    printf("occlusion query id=%u available=%u\n", q, avail);

    fs_t fs = (fs_t)gpa("glFenceSync");
    cws_t cws = (cws_t)gpa("glClientWaitSync");
    void *f = fs(0x9117, 0);
    printf("fence=%p waitStatus=0x%X (0x911A = already signaled)\n", f, cws(f, 0, 1000000));
    return 0;
}
