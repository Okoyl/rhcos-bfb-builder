# RHCOS BFB Build

### Pre-requisites
Podman and qemu-user-static are required to build the RHCOS image on a non-aarch64 machine.


### Clone the project
The project contains Mellanox's bfscripts as a git submoudle, so be sure to clone it as well:
```bash
git clone --recursive https://github.com/rh-ecosystem-edge/rhcos-bfb-builder.git
```

### Build the RHCOS image
First use an openshift cluster to check the release image for the RHCOS version you want to build.
```bash
export RHCOS_VERSION="4.20.0-ec.4"

export TARGET_IMAGE=$(oc adm release info --image-for rhel-coreos "quay.io/openshift-release-dev/ocp-release:"$RHCOS_VERSION"-aarch64")
export BUILDER_IMAGE=$(oc adm release info --image-for driver-toolkit "quay.io/openshift-release-dev/ocp-release:"$RHCOS_VERSION"-aarch64")
```

Make sure you export PULL_SECRET, you can obtain it from console.redhat.com.
```bash
export PULL_SECRET=<path to pull secret file>
```

Set Nvidia DPU stack versions:
```bash
export OFED_VERSION="25.04-0.6.0.0"
export DOCA_VERSION="3.0.0"
export DOCA_DISTRO="rhel9.4"
```

```bash
podman build -f rhcos-bfb.Containerfile \
--authfile $PULL_SECRET \
--build-arg D_ARCH=aarch64 \
--build-arg D_DOCA_VERSION=$DOCA_VERSION \
--build-arg D_OFED_VERSION=$OFED_VERSION \
--build-arg D_BASE_IMAGE=$BUILDER_IMAGE \
--build-arg D_FINAL_BASE_IMAGE=$TARGET_IMAGE \
--build-arg D_DOCA_DISTRO=$DOCA_DISTRO \
--tag "rhcos-bfb:$RHCOS_VERSION-latest"
```

### Creating disk boot images
```bash
skopeo copy containers-storage:localhost/rhcos-bfb:$RHCOS_VERSION-latest oci-archive:rhcos-bfb_$RHCOS_VERSION.ociarchive
```

You can follow the instructions at [custom-coreos-disk-images](/custom-coreos-disk-images/README.md) to generate the live artifacts.
```bash
# In Fedora based system:
sudo dnf install -y osbuild osbuild-tools osbuild-ostree podman jq xfsprogs
sudo custom-coreos-disk-images/custom-coreos-disk-images.sh \
  --ociarchive rhcos-bfb_$RHCOS_VERSION.ociarchive \
  --platforms live \
  --metal-image-size 5000
```

### Creating a BFB image
```bash
./make_bfb.sh
```

### Flashing to DPU
```bash
bfb-install --rshim /dev/rshim0 --config worker.ign --bfb rhcos.bfb
```
