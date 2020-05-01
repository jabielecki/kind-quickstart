#!/bin/bash

cd "$(dirname $0)"

echo ----------- kind -----------------

go install sigs.k8s.io/kind
# Version is pinned inside go.mod file; to bump it:
#     go get -u sigs.k8s.io/kind

sudo cp -p "$(go env GOPATH)/bin/kind" /usr/local/bin/kind

sudo -H kind delete cluster 2> /dev/null
sudo -H kind create cluster --config ./kind.yaml

mkdir -p ~/.kube
sudo -H kind get kubeconfig --name="kind" > ~/.kube/kind
export KUBECONFIG=~/.kube/kind
kubectl cluster-info

echo ""
echo ""
echo ----------- metallb -----------------
kubectl apply -f https://raw.githubusercontent.com/google/metallb/v0.8.1/manifests/metallb.yaml
SUBNET=$(sudo -H docker network inspect bridge | jq -r '.[0].IPAM.Config[0].Subnet | sub("(?<c>.*).0.0/16"; .c + ".80.2-" + .c + ".80.254" ; "")')
if ! echo "$SUBNET" | grep -E '[0-9]-[0-9]' ; then
    echo "Problem: cannot determine docker subnet via jq"
    exit 1
fi
kubectl apply -f - <<- EOF
	apiVersion: v1
	kind: ConfigMap
	metadata:
	  namespace: metallb-system
	  name: config
	data:
	  config: |
	    address-pools:
	    - name: default
	      protocol: layer2
	      addresses:
	      - $SUBNET     # previously calculated value
EOF

echo ""
echo ""
echo ----------- helm --------------------

curl -L https://get.helm.sh/helm-v3.2.0-linux-amd64.tar.gz | tar zvxf - linux-amd64/helm
sudo mv linux-amd64/helm /usr/local/bin/helm
rmdir linux-amd64/
helm repo add stable https://kubernetes-charts.storage.googleapis.com/

echo ""
echo ""
echo --- Commands to try now: ----------------
echo 
echo 'export KUBECONFIG=~/.kube/kind'
echo 'source <(kubectl completion bash)'
echo 'source <(helm    completion bash)'
echo
echo helm search hub nginx
echo helm repo update
echo helm install stable/mysql --generate-name
echo -----------------------------------------

