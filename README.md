# Kind Restart

I see a number of tutorials here and there that start off with "pre-requisites: 1. Have a kubectl configured with some Kubernetes cluster".

This guide will provision a nice setup on a single local system (like my laptop):
  - Kubernetes
    - 3 nodes on 1 system
    - achieved using Kind and Docker
    - supporting Services of type `LoadBalancer` by setting up Metallb
  - Helm 3 (no tiller, yay)

Unfortunately kind clusters don't survive docker daemon restarts. Hence
this script will **destroy the current cluster** and provision a new one.

# Why bother with that LoadBalancer?
Kind does not offer an implementation of load-balancers (mechanisms that provide
traffic to Service objects having `spec.type=LoadBalancer`).

The implementations of load-balancers that Kubernetes does ship with are all glue code
that calls out to various IaaS platforms (GCP, AWS, Azure). As you're not
running on IaaS, `LoadBalancer`s will remain in the inaccessible ("pending")
state indefinitely.

As much as you could convert such Services to one of inferior types
("NodePort" or "externalIP"), it's much easier to just support them via metallb.

# Requirements

  - Linux amd64 (Ubuntu 18 or 19 is fine)
  - RAM: 16 GB
  - root access via sudo
  - `jq` command with version 1.5 or above

# Initial setup

```bash
sudo snap install --classic docker
sudo snap install --classic kubectl
sudo snap install --classic go
sudo snap install jq
```

# Usage

```bash
./kind.sh
```

# Can I run it at system startup?

Yes. Run the script as root. Just make sure that root account has `sudo` access.

# Cleanup

```bash
sudo -H kind delete cluster
```
