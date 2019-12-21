ARG overlay_ref=0347f26bba5a7c6149ad6159257aee617b84f356
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

# Add the custom overlay for clang ebuild with libclang.a

RUN git clone https://github.com/dalehamel/bpftrace-static-deps.git \
    /var/db/repos/localrepo && cd /var/db/repos/localrepo && \
    git reset --hard ${overlay_ref}

RUN mkdir -p /etc/portage/repos.conf && \
    echo -e "[localrepo]\nlocation = /var/db/repos/localrepo\npriority = 100\n" >> /etc/portage/repos.conf/localrepo.conf

# Build static libs for libelf and glibc
RUN emerge -qv dev-libs/elfutils

# Install LLVM and build custom clang
RUN emerge -qv sys-devel/llvm
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
RUN mkdir -p /src && git clone https://github.com/iovisor/bpftrace /src/bpftrace
WORKDIR /src/bpftrace
RUN git reset --hard ${bpftrace_ref} && mkdir build && cd build && \
    cmake -DCMAKE_BUILD_TYPE="Release" -DSTATIC_LINKING:BOOL=ON ../ && \
    make -j$(nproc) && make install
