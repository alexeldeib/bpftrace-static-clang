[![CircleCI](https://circleci.com/gh/dalehamel/bpftrace-static-clang.svg?style=svg)](https://circleci.com/gh/dalehamel/bpftrace-static-clang)

# What's this?

This repository builds a bpftrace executable with (almost) no dependencies,
while still maintaining correct and predictable execution. It links only to
glibc libraries:

```
        linux-vdso.so.1 (0x00007ffed204c000)
        libpthread.so.0 => /lib64/libpthread.so.0 (0x00007f962f663000)
        libdl.so.2 => /lib64/libdl.so.2 (0x00007f962f65d000)
        libm.so.6 => /lib64/libm.so.6 (0x00007f962f512000)
        libc.so.6 => /lib64/libc.so.6 (0x00007f962f343000)
        /lib64/ld-linux-x86-64.so.2 (0x00007f96339b3000)
```

`linux-vdso` is virtual / injected by the kernel, and the rest are provided by
glibc.

# Why make this?

There is an alpine-based build for bpftrace which produces a static library. In
theory, this should be portable. In practice however, [LLVM and musl don't
seem to get along](https://github.com/iovisor/bpftrace/issues/266).

This appears to be a common problem with linking libc statically, be it musl,
glibc, or uclibc; the use of dlopen and other functions provided by dynamic
linkers can lead to undefined behavior in static executables.

So, what if rather than trying to build a static bpftrace, we assemble bpftrace 
from only static libraries *except* for libc? This could promise to give the
best of both worlds, offering the portability of a static build, with the
correctness of a dynamic build.

## Embedded environments

Using bpftrace on the Raspberry Pi and android would be made much easier if
the LLVM and clang dependencies were abstracted away. A build host that can
target a compatible glibc ABI can be set up as a cross compiler fairly easily,
and the resulting executable should be easily shared with any supported
architecture.

## Embedded bcc and clang.

As bpftrace is tightly coupled to bcc, embedding bcc directly into the
executable makes sense. This ensures that the version of bcc that is used is
fixed, and that a particular release of a mostly static bpftrace can have
very predictable behavior and be easy to reason about.

# How does this work?

Right now, this works by using Gentoo and a custom ebuild based off of the
alpine cmake flags for building static LLVM and Clang packages.

# How should this work?

bpftrace could be configured to include LLVM and clang as build targets if a
flag like `-D STATIC_LINK_CLANG` or similar is specified. Then and only then
the llvm and clang code can be pulled in, and the same cmake flags used by
the alpine/gentoo packages can be used to generate the static libraries to be
embedded.

Ideally if built for distribution, this should target the oldest possible glibc
it can to maintain compatibility with the oldest systems it can. If it can
target a glibc version that is shipped with most distributions that feature
eBPF support, such as glibc ABI 2.25, then it should be portable to a large
majority of Linux distributions.
