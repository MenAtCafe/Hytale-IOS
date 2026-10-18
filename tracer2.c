#define _DARWIN_C_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>

static FILE *g_log;
static pthread_mutex_t g_mu = PTHREAD_MUTEX_INITIALIZER;
static __thread int in_here;

static FILE *logfile(void) {
    if (!g_log) {
        const char *p = getenv("GLTRACE_LOG");
        g_log = fopen(p ? p : "/tmp/gltrace.log", "a");
        if (!g_log) g_log = stderr;
    }
    return g_log;
}

static void *(*real_getproc)(const char *);

static void *wrapped_getproc(const char *name) {
    void *p = real_getproc ? real_getproc(name) : NULL;
    if (name) {
        pthread_mutex_lock(&g_mu);
        fprintf(logfile(), "GLPROC %s\n", name);
        fflush(logfile());
        pthread_mutex_unlock(&g_mu);
    }
    return p;
}

static void *my_dlsym(void *handle, const char *symbol) {
    void *p = dlsym(handle, symbol);   /* binds to libSystem's dlsym */
    if (symbol && !in_here) {
        in_here = 1;
        int is_gpa = (strcmp(symbol, "SDL_GL_GetProcAddress") == 0);
        if (is_gpa || strncmp(symbol, "SDL_", 4) == 0) {
            pthread_mutex_lock(&g_mu);
            fprintf(logfile(), "DLSYM %s -> %p\n", symbol, p);
            fflush(logfile());
            pthread_mutex_unlock(&g_mu);
        }
        if (is_gpa && p) {
            real_getproc = (void *(*)(const char *))p;
            p = (void *)wrapped_getproc;
        }
        in_here = 0;
    }
    return p;
}

#define DYLD_INTERPOSE(_replacement, _replacee) \
    __attribute__((used)) static struct { \
        const void *replacement; const void *replacee; \
    } _interpose_##_replacee __attribute__((section("__DATA,__interpose"))) = { \
        (const void *)(unsigned long)&_replacement, \
        (const void *)(unsigned long)&_replacee \
    };

DYLD_INTERPOSE(my_dlsym, dlsym)
