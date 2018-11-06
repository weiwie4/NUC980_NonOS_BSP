#ifndef _LINUX_ERR_H
#define _LINUX_ERR_H

#include "asm\errno.h"


/*
 * Kernel pointers have redundant information, so we can use a
 * scheme where we can return either an error code or a dentry
 * pointer with the same return value.
 *
 * This should be a per-architecture thing, to allow different
 * error and pointer decisions.
 */
#define MAX_ERRNO	4095

#ifndef __ASSEMBLY__

#define IS_ERR_VALUE(x) ((x) >= (unsigned long)-MAX_ERRNO)

static __inline void *ERR_PTR(long error)
{
	return (void *) error;
}

static __inline long PTR_ERR(const void *ptr)
{
	return (long) ptr;
}

static __inline long IS_ERR(const void *ptr)
{
	return IS_ERR_VALUE((unsigned long)ptr);
}

#endif

#endif /* _LINUX_ERR_H */
