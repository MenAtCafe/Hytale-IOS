#define _DARWIN_C_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>

extern void *dlvsym(void *handle, const char *symbol, const char *version);

static void *(*real_dlsym)(void *, const char *);
static void *(*real_getproc)(const char *);
static FILE *g_log;
static pthread_mutex_t g_mu = PTHREAD_MUTEX_INITIALIZER;
static __thread int in_dlsym;

static FILE *logfile(void) {
    if (!g_log) {
        const char *p = getenv("GLTRACE_LOG");
        g_log = fopen(p ? p : "/tmp/gltrace.log", "a");
        if (!g_log) g_log = stderr;
    }
    return g_log;
}

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

void *dlsym(void *handle, const char *symbol) {
    if (!real_dlsym)
        real_dlsym = (void *(*)(void *, const char *))dlvsym(RTLD_NEXT, "dlsym", "Default");
    void *p = real_dlsym(handle, symbol);
    if (symbol && !in_dlsym) {
        in_dlsym = 1;
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
        in_dlsym = 0;
    }
    return p;
}
