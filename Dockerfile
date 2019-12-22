ARG overlay_ref=8fcc2a5676f9bea4ea6945f2cfdf52319ce7759c
ARG bcc_ref=v0.12.0
ARG bpftrace_ref=master

# name the portage image
FROM gentoo/portage:latest as portage

# image is based on stage3-amd64
FROM gentoo/stage3-amd64:latest

# copy the entire portage volume in
COPY --from=portage /var/db/repos/gentoo /var/db/repos/gentoo

# Sandboxes removed so we don't need ptrace cap for builds
RUN echo 'FEATURES="buildpkg -sandbox -usersandbox"' >> /etc/portage/make.conf
RUN echo 'USE="static-libs"' >> /etc/portage/make.conf
RUN cat /etc/portage/make.conf

RUN emerge -qv dev-vcs/git dev-util/cmake

# Build static libs for libelf and zlib
RUN emerge -qv dev-libs/elfutils
RUN emerge -qv sys-libs/zlib

# Add the custom overlay for clang ebuild with libclang.a, and build llvm
# and clang without SHARED=on
RUN git clone https://github.com/dalehamel/bpftrace-static-deps.git \
    /var/db/repos/localrepo && cd /var/db/repos/localrepo && \
    git reset --hard  $overlay_ref

RUN mkdir -p /etc/portage/repos.conf && \
    echo -e "[localrepo]\nlocation = /var/db/repos/localrepo\npriority = 100\n" >> /etc/portage/repos.conf/localrepo.conf

# Install LLVM and build custom clang
RUN emerge -qv sys-devel/llvm::localrepo
RUN emerge -qv sys-devel/clang::localrepo

# Indicate to cmake the correct locations of clang/llvm cmake configs
ENV LLVM_DIR=/usr/lib/llvm/8/lib64/cmake/llvm
ENV Clang_DIR=/usr/lib/llvm/8/lib64/cmake/clang

# Build BCC and install static libs
RUN mkdir -p /src && git clone https://github.com/iovisor/bcc /src/bcc
WORKDIR /src/bcc
RUN git reset --hard ${bcc_ref} && mkdir build && cd build && \
    cmake -DCMAKE_INSTALL_PREFIX=/usr/local ../ && \
    make -j$(nproc) && make install && \
    cp src/cc/libbcc.a /usr/local/lib64/libbcc.a && \
    cp src/cc/libbcc-loader-static.a /usr/local/lib64/libbcc-loader-static.a && \
    cp ./src/cc/libbcc_bpf.a /usr/local/lib64/libbpf.a

# Build bpftrace
# Currently hacked to post-process link.txt manually until the correct
# cmake incantations can be worked in, this is to serve as a proof of concept
# build. To properly do this, bpftrace's cmake should target llvm and clang.
RUN mkdir -p /src && git clone https://github.com/iovisor/bpftrace /src/bpftrace
WORKDIR /src/bpftrace
RUN git reset --hard ${bpftrace_ref} && \
    sed -i 's/-static/-static-libgcc -static-libstdc++/g' CMakeLists.txt\
    && mkdir build && cd build && \
    cmake -DCMAKE_BUILD_TYPE="Release" -DSTATIC_LINKING:BOOL=ON ../ && \
    llvmlibs=$(ls -1 /usr/lib/llvm/8/lib64/*.a | tr '\n' ' ') && \
    glibc_statics="-Wl,-Bstatic -lz -lrt -ldl -lpthread" && \
    glibc_dynamic="-lpthread -ldl -Wl,-Bstatic -lz -lrt" && \
    sed -i "s|-Wl,-Bdynamic /usr/lib/llvm/8/lib64/libLLVM-8.so|${llvmlibs}|g" \
      src/CMakeFiles/bpftrace.dir/link.txt && \
    sed -i "s|${glibc_statics}|${glibc_dynamic}|g" \
      src/CMakeFiles/bpftrace.dir/link.txt && \
    sed -i "s|-lelf|/usr/lib64/libelf.a|g" \
      src/CMakeFiles/bpftrace.dir/link.txt && \
    sed -i "s|-lclang|/usr/lib/llvm/8/lib64/libclang.a|g" \
      src/CMakeFiles/bpftrace.dir/link.txt && \
    make -j$(nproc) && make install
