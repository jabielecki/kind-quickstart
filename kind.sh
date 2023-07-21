#!/bin/bash

cd "$(dirname $0)"

echo ----------- kind -----------------

EX=$(sudo -H which kind)
if [[ -n "$EX" && "$EX" != /usr/local/bin/kind ]] ; then
	echo "This script will install /usr/local/bin/kind, but then it would use $EX anyway."
	echo "This seems wrong."
	exit 1
fi

echo The existing /usr/local/bin/kind binary:
sudo -H kind --version

# Subsequent `sudo kind` might not search GOPATH or GOBIN, but it will hopefully see /usr/local/bin.
T=$(mktemp -d)

GOBIN=$T   go install sigs.k8s.io/kind@v0.20.0

sudo mv "$T/kind" /usr/local/bin/kind
sudo chown root:root /usr/local/bin/kind

rmdir "$T"

sudo -H kind delete cluster 2> /dev/null
sudo -H kind create cluster --config ./kind.yaml

mkdir -p ~/.kube
sudo -H kind get kubeconfig --name="kind" > ~/.kube/kind
sudo chmod 0600 ~/.kube/kind
export KUBECONFIG=~/.kube/kind
kubectl cluster-info

echo ""
echo ""
echo ----------- metallb -----------------
echo ""

kubectl get configmap kube-proxy -n kube-system -o yaml | grep -i "strictARP"
kubectl get configmap kube-proxy -n kube-system -o yaml | sed -e "s/strictARP: false/strictARP: true/" | kubectl replace -f - -n kube-system

kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.10/config/manifests/metallb-native.yaml

kubectl wait --namespace metallb-system \
                --for=condition=ready pod \
                --selector=app=metallb \
                --timeout=90s

kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"

ip -o -4 a sh dev br-$(docker network ls -f name=kind -q) || true

SUBNET=$(sudo -H docker network inspect kind --format "{{(index .IPAM.Config 0).Subnet}}" | sed 's%[.]0/[1-9][0-9]*%.128/25%' )

# Earlier metallb expected 1.1.1.2-1.1.1.3 and somehow network "bridge" worked.
# (First try to convert .0.0/16, then try to convert .128.0/24.)
# SUBNET=$(sudo -H docker network inspect bridge | jq -r '.[0].IPAM.Config[0].Subnet | sub("(?<c>.*).0.0/16"; .c + ".80.2-" + .c + ".80.254" ; "") | sub("(?<c>.*).128.0/24"; .c + ".128.230-" + .c + ".128.254" ; "")')
if ! echo "$SUBNET" | grep -E '[0-9]/[1-9]' ; then
    echo "Problem: cannot determine metallb subnet"
    exit 1
fi

kubectl apply -f - <<- EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: ippool-ns-service-alloc-sample
  namespace: metallb-system
spec:
  avoidBuggyIPs: true
  addresses:
    - $SUBNET
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: example
  namespace: metallb-system
EOF

echo ""
echo ""
echo ----------- helm --------------------
echo ""

curl -L https://get.helm.sh/helm-v3.9.2-linux-amd64.tar.gz | tar zvxf - linux-amd64/helm
sudo mv linux-amd64/helm /usr/local/bin/helm
rmdir linux-amd64/
# helm repo add stable https://kubernetes-charts.storage.googleapis.com/
# helm repo update
# export PATH="$(go env GOPATH)/bin:$PATH"

cat << '__EOF__'

--- Commands to try now: ----------------

export KUBECONFIG=~/.kube/kind
source <(kubectl completion bash)
source <(helm    completion bash)
helm search hub nginx             # See: https://helm.sh/docs/intro/quickstart/#initialize-a-helm-chart-repository
helm help install

--- test the LB

helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install bitnami/nginx --generate-name
kubectl get svc

--- testshop

helm repo add cloud-native-toolkit https://charts.cloudnativetoolkit.dev
helm install my-robot-shop cloud-native-toolkit/robot-shop

--- cleanup

sudo -H kind delete cluster

-----------------------------------------

__EOF__
