ARG TARGET_IMAGE

FROM ${TARGET_IMAGE} as kernel-reference

RUN rpm -q --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-core > /kernel_version

FROM registry.access.redhat.com/ubi10:latest AS builder

ARG RHEL_VERSION=''
# If RHEL_VERSION is empty, we infer it from the /etc/os-release file. This is used by OKD as we always want the latest one. 
RUN [ "${RHEL_VERSION}" == "" ] && source /etc/os-release && RHEL_VERSION=${VERSION_ID}; echo ${RHEL_VERSION} > /etc/dnf/vars/releasever \
  && echo -e "best=True\ninstall_weak_deps=False" >> /etc/dnf/dnf.conf

# kernel packages needed to build drivers / kmods 
RUN --mount=type=bind,from=kernel-reference,source=/kernel_version,target=/kernel_version,ro \
  KERNEL_VERSION=$(cat /kernel_version) && \
  dnf -y install \
  kernel-devel${KERNEL_VERSION:+-}${KERNEL_VERSION} \
  kernel-devel-matched${KERNEL_VERSION:+-}${KERNEL_VERSION} \
  kernel-headers${KERNEL_VERSION:+-}${KERNEL_VERSION} \
  kernel-modules${KERNEL_VERSION:+-}${KERNEL_VERSION} \
  kernel-modules-extra${KERNEL_VERSION:+-}${KERNEL_VERSION}; \
  #
  dnf -y install \
  kernel-64k-devel${KERNEL_VERSION:+-}${KERNEL_VERSION} \
  kernel-64k-modules${KERNEL_VERSION:+-}${KERNEL_VERSION} \
  kernel-64k-modules-extra${KERNEL_VERSION:+-}${KERNEL_VERSION}; \
  #
  dnf -y install kernel-rpm-macros && \
  # Additional packages that are mandatory for driver-containers
  dnf -y install autoconf automake binutils elfutils-libelf-devel glibc kabi-dw kmod libtool && \
  # Find and install the GCC version used to compile the kernel
  # If it cannot be found (fails on some architectures), install the default gcc
  export INSTALLED_KERNEL=$(rpm -q --qf "%{VERSION}-%{RELEASE}.%{ARCH}"  kernel-devel) && \
  GCC_VERSION=$(cat /lib/modules/${INSTALLED_KERNEL}/config | grep -Eo "gcc \(GCC\) ([0-9\.]+)" | grep -Eo "([0-9\.]+)") && \
  dnf -y install gcc-${GCC_VERSION} gcc-c++-${GCC_VERSION} || dnf -y install gcc gcc-c++ && \
  #
  # Additional packages that are needed for a subset (e.g DPDK) of driver-containers
  dnf -y install xz diffutils flex bison && \
  #
  # Packages needed to build driver-containers
  dnf -y install git make rpm-build && \
  #
  dnf clean all && rm -rf /var/cache/dnf/*


LABEL io.k8s.description="driver-toolkit is a container with the kernel packages necessary for building driver containers for deploying kernel modules/drivers on OpenShift" \
  name="driver-toolkit" \
  io.openshift.release.operator=true \
  version="0.1"

# Last layer for metadata for mapping the driver-toolkit to a specific kernel version
RUN --mount=type=bind,from=kernel-reference,source=/kernel_version,target=/kernel_version,ro \
  KERNEL_VERSION=$(cat /kernel_version) && \
  export INSTALLED_KERNEL=$(rpm -q --qf "%{VERSION}-%{RELEASE}.%{ARCH}"  kernel-devel); \
  export INSTALLED_RT_KERNEL=$(rpm -q --qf "%{VERSION}-%{RELEASE}.%{ARCH}+rt"  kernel-rt-core); \
  echo "{ \"KERNEL_VERSION\": \"${INSTALLED_KERNEL}\", \"RT_KERNEL_VERSION\": \"${INSTALLED_RT_KERNEL}\", \"RHEL_VERSION\": \"$(</etc/dnf/vars/releasever)\" }" > /etc/driver-toolkit-release.json
