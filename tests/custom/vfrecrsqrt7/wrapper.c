#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

const char *getenvval(const char *pszName) {
    const char *pszValue = getenv(pszName);
    if (pszValue == NULL) {
        return "";
    }
    return pszValue;
}

#ifdef __cplusplus
}
#endif
