#include <stdint.h>

/* macOS-only Security.framework symbols that iOS does not export. */
int stubSecCertificateAddToKeychain(void) __asm("_SecCertificateAddToKeychain");
int stubSecCertificateAddToKeychain(void) { return 0; }

int stubSecItemExport(void) __asm("_SecItemExport");
int stubSecItemExport(void) { return 0; }

int stubSecItemImport(void) __asm("_SecItemImport");
int stubSecItemImport(void) { return 0; }

int stubSecKeychainCopyDefault(void) __asm("_SecKeychainCopyDefault");
int stubSecKeychainCopyDefault(void) { return 0; }

int stubSecKeychainCreate(void) __asm("_SecKeychainCreate");
int stubSecKeychainCreate(void) { return 0; }

int stubSecKeychainDelete(void) __asm("_SecKeychainDelete");
int stubSecKeychainDelete(void) { return 0; }

int stubSecKeychainItemCopyKeychain(void) __asm("_SecKeychainItemCopyKeychain");
int stubSecKeychainItemCopyKeychain(void) { return 0; }

int stubSecKeychainOpen(void) __asm("_SecKeychainOpen");
int stubSecKeychainOpen(void) { return 0; }

int stubSecKeychainSetSettings(void) __asm("_SecKeychainSetSettings");
int stubSecKeychainSetSettings(void) { return 0; }

int stubSecKeychainUnlock(void) __asm("_SecKeychainUnlock");
int stubSecKeychainUnlock(void) { return 0; }

int stubSecSignTransformCreate(void) __asm("_SecSignTransformCreate");
int stubSecSignTransformCreate(void) { return 0; }

int stubSecTransformExecute(void) __asm("_SecTransformExecute");
int stubSecTransformExecute(void) { return 0; }

int stubSecTransformSetAttribute(void) __asm("_SecTransformSetAttribute");
int stubSecTransformSetAttribute(void) { return 0; }

int stubSecTrustSettingsCopyCertificates(void) __asm("_SecTrustSettingsCopyCertificates");
int stubSecTrustSettingsCopyCertificates(void) { return 0; }

int stubSecTrustSettingsCopyTrustSettings(void) __asm("_SecTrustSettingsCopyTrustSettings");
int stubSecTrustSettingsCopyTrustSettings(void) { return 0; }

int stubSSLSetCertificateAuthorities(void) __asm("_SSLSetCertificateAuthorities");
int stubSSLSetCertificateAuthorities(void) { return 0; }

void *varkSecInputIsAttributeName __asm("_kSecInputIsAttributeName") = 0;
void *varkSecInputIsDigest __asm("_kSecInputIsDigest") = 0;
void *varkSecTransformInputAttributeName __asm("_kSecTransformInputAttributeName") = 0;

void hytale_syslog_ext(void) __asm("_syslog$DARWIN_EXTSN");
void hytale_syslog_ext(void) { }
