#!/bin/bash

sudo apt update -y

sudo swapoff -a

sudo hostnamectl set-hostname master

# Command setup

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter


cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF


sudo sysctl --system


#############################-------------lets install & configure containerd--------------###################################

cd /tmp

wget https://github.com/containerd/containerd/releases/download/v1.6.35/containerd-1.6.35-linux-amd64.tar.gz

sudo tar Cxzvf /usr/local containerd-1.6.35-linux-amd64.tar.gz


wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service

sudo mkdir -p /usr/local/lib/systemd/system/

sudo mv containerd.service /usr/local/lib/systemd/system/containerd.service


sudo systemctl daemon-reload

sudo systemctl enable --now containerd


#############

wget https://github.com/opencontainers/runc/releases/download/v1.2.0-rc.2/runc.amd64

sudo install -m 755 runc.amd64 /usr/local/sbin/runc


#############

wget https://github.com/containernetworking/plugins/releases/download/v1.5.1/cni-plugins-linux-amd64-v1.5.1.tgz

sudo mkdir -p /opt/cni/bin

sudo tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.5.1.tgz


sudo apt update -y




sudo mkdir -p /etc/containerd/

sudo chown ubuntu:root /etc/containerd

sudo containerd config default > /etc/containerd/config.toml

sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml

sudo systemctl restart containerd.service

sudo systemctl enable containerd.service


#############################-------------lets install Kubeadm, Kubelet & Kubectl --------------###################################

sudo apt-get update

sudo apt-get install -y apt-transport-https ca-certificates curl gpg

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list


sudo apt-get update

sudo apt update -y

# Note `$apt-cache madison kubeadm` for selecting version

# sudo apt-get install -y kubelet=1.28.1-1.1 kubeadm=1.28.1-1.1 kubectl=1.28.1-1.1

sudo apt-get install -y kubelet kubeadm kubectl

sudo apt-mark hold kubelet kubeadm kubectl

sudo systemctl enable --now kubelet


cd /home/ubuntu/

sudo kubeadm init

sleep 30

mkdir .kube

sudo cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config

sleep 5

#############################------------- 🔰 Installing criclt utility 🔰 -----------------------------####################
VERSION="v1.30.0" # check latest version in /releases page
wget https://github.com/kubernetes-sigs/cri-tools/releases/download/$VERSION/crictl-$VERSION-linux-amd64.tar.gz
sudo tar zxvf crictl-$VERSION-linux-amd64.tar.gz -C /usr/local/bin
rm -f crictl-$VERSION-linux-amd64.tar.gz

sudo groupadd containerd
sudo chgrp containerd /run/containerd/containerd.sock
sudo usermod -aG containerd ubuntu
newgrp containerd
sudo systemctl restart containerd
sudo chgrp containerd /run/containerd/containerd.sock

sleep 3


#############################------------- 🔰 To install Weave CNI Plugin 🔰 -----------------------------####################

# kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml


#############################------------- 🔰 To install Cilium CNI plugin 🔰 ----------------------------################

CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}

sudo apt update -y

#############################------------- 🔰 Change ownership of /opt/cni/bin to ROOT 🔰 ----------------------------################
# below statment resolve a problem of "cilium-agent" in pod "cilium-hf7zn" is waiting to start: PodInitializing
# 🔗 https://github.com/cilium/cilium/issues/33405
# 🔗 https://github.com/cilium/cilium/issues/23838
sudo chown root:root /opt/cni/bin

cilium version --client

sudo chown ubuntu:root /home/ubuntu/.kube/config

echo 'alias k="kubectl"' >> /home/ubuntu/.bashrc
echo 'alias ks="kubectl get all -n kube-system -o wide"' >> /home/ubuntu/.bashrc
echo 'alias kdesc="kubectl describe"' >> /home/ubuntu/.bashrc
echo 'alias kgn="kubectl get nodes -o wide"' >> /home/ubuntu/.bashrc
echo 'alias kgp="kubectl get pods -o wide"' >> /home/ubuntu/.bashrc
echo 'alias kgd="kubectl get deployment -o wide"' >> /home/ubuntu/.bashrc
echo 'alias kgs="kubectl get svc -o wide"' >> /home/ubuntu/.bashrc
echo 'alias kd="kubectl delete"' >> /home/ubuntu/.bashrc
echo 'alias kdd="kubectl delete deployment"' >> /home/ubuntu/.bashrc
echo 'alias kds="kubectl delete service"' >> /home/ubuntu/.bashrc
echo 'alias kdn="kubectl delete namespace"' >> /home/ubuntu/.bashrc
echo 'alias kdp="kubectl delete pod"' >> /home/ubuntu/.bashrc
echo 'alias kaf="kubectl apply -f"' >> /home/ubuntu/.bashrc
echo 'alias kdf="kubectl delete -f"' >> /home/ubuntu/.bashrc

sleep 40

cilium install



# 👇 Installing Helm
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm


cd /tmp

# 🔐 Installing Kubesec
wget https://github.com/controlplaneio/kubesec/releases/download/v2.14.2/kubesec_linux_amd64.tar.gz

tar -xzvf kubesec_linux_amd64.tar.gz

sudo mv kubesec /usr/bin/


# 🔐 Installing Conftest
LATEST_VERSION=$(wget -O - "https://api.github.com/repos/open-policy-agent/conftest/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | cut -c 2-)
ARCH=$(arch)
SYSTEM=$(uname)

wget "https://github.com/open-policy-agent/conftest/releases/download/v${LATEST_VERSION}/conftest_${LATEST_VERSION}_${SYSTEM}_${ARCH}.tar.gz"
tar xzf conftest_${LATEST_VERSION}_${SYSTEM}_${ARCH}.tar.gz

sudo mv conftest /usr/local/bin


# 🔐 Installing Kubelinter
wget https://github.com/stackrox/kube-linter/releases/download/v0.7.1/kube-linter-linux.tar.gz

tar -xzvf kube-linter-linux.tar.gz

sudo mv kube-linter /usr/bin/

# 🔐 Installling AppArmor
sudo apt install apparmor-profiles
sudo apt install apparmor-utils -y

# 🔐 Installling Kube-bench
KUBE_BENCH_VERSION=0.10.1

curl -L https://github.com/aquasecurity/kube-bench/releases/download/v${KUBE_BENCH_VERSION}/kube-bench_${KUBE_BENCH_VERSION}_linux_amd64.deb -o kube-bench_${KUBE_BENCH_VERSION}_linux_amd64.deb

sudo apt install ./kube-bench_${KUBE_BENCH_VERSION}_linux_amd64.deb -f