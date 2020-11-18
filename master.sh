#!/bin/bash

set -xe

NODE=master

mkdir -p .kube

multipass launch ubuntu --name ${NODE} --cpus 2 --mem 2G --disk 8G
multipass mount "$(pwd)/docker" ${NODE}:/home/ubuntu/docker 2> /dev/null 
multipass mount "$(pwd)/kube" ${NODE}:/home/ubuntu/kube 2> /dev/null 
multipass mount "$(pwd)/node" ${NODE}:/home/ubuntu/node 2> /dev/null

echo "Setting up prerequisites"
multipass exec ${NODE} -- bash -c 'sudo apt update && sudo apt install -y ansible'
multipass exec ${NODE} -- bash -c 'ansible-galaxy collection install ansible.posix'
multipass exec ${NODE} -- bash -c 'ansible-playbook docker/docker.yml'
multipass exec ${NODE} -- bash -c 'ansible-playbook kube/kube.yml'
multipass exec ${NODE} -- bash -c 'ansible-playbook node/node.yml'

echo "Setting up Master"
multipass exec ${NODE} -- bash -c 'kubeadm config images pull'
multipass exec ${NODE} -- bash -c 'sudo kubeadm init --pod-network-cidr=192.178.0.0/16' 2> /dev/null
multipass exec ${NODE} -- bash -c 'sudo cat /etc/kubernetes/admin.conf' > .kube/config

echo "Installing CNI Network Plugin"
KUBECONFIG=.kube/config kubectl create -f calico/tigera-operator.yml
KUBECONFIG=.kube/config kubectl create -f calico/custom-resources.yml

sleep 10
KUBECONFIG=.kube/config kubectl rollout status daemonset calico-node -n calico-system

mv ~/.kube/config ~/.kube/config.back
cp .kube/config ~/.kube/config