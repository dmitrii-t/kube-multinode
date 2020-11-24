#!/bin/bash

set -xe

NODE=worker

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

echo "Setting up Node"
multipass exec ${NODE} -- bash -c 'sudo systemctl enable kubelet.service'

multipass exec ${NODE} -- bash -c "sudo mkdir -p /home/ubuntu/.kube/"
multipass exec ${NODE} -- bash -c "sudo chown ubuntu:ubuntu /home/ubuntu/.kube/"
multipass transfer .kube/config ${NODE}:/home/ubuntu/.kube/config
multipass exec ${NODE} -- bash -c "kubeadm token create --print-join-command >> kube-join-command.sh"
multipass exec ${NODE} -- bash -c "sudo /bin/bash kube-join-command.sh"

KUBECONFIG=.kube/config kubectl label node ${NODE} node-role.kubernetes.io/node=
