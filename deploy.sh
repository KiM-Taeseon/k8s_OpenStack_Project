#!/bin/bash
set -e # 스크립트 실행 중 오류 발생 시 즉시 중단

echo "오픈스택에 쿠버네티스 배포를 시작합니다..."

# 0. 사전 확인
if ! command -v terraform &> /dev/null; then
    echo "Terraform이 설치되어 있지 않습니다. 설치 후 다시 시도해주십시오."
    exit 1
fi
if ! command -v ansible-playbook &> /dev/null; then
    echo "Ansible이 설치되어 있지 않습니다. 설치 후 다시 시도해주십시오."
    exit 1
fi
if ! command -v jq &> /dev/null; then
    echo "jq가 설치되어 있지 않습니다. 설치 후 다시 시도해주십시오."
    exit 1
fi
if [ ! -f "admin-openrc_.sh" ]; then
    echo "openrc.sh 파일이 없습니다. OpenStack 대시보드에서 다운로드 받아서 복사해주십시오."
    exit 1
fi
if [ ! -f "$HOME/.ssh/id_rsa" ]; then
    echo "SSH Key 파일이 없습니다. SSH Key 파일을 생성해주십시오."
    exit 1
fi

# OpenStack 인증 정보 로드
source ./admin-openrc_.sh
echo "OpenStack 인증 정보를 로드 중입니다..."

# 1. Terraform으로 인프라 생성
echo "Terraform으로 인프라를 생성합니다...(시간이 다소 소요될 수 있습니다!)"
cd terraformlab
terraform init -upgrade
terraform apply -auto-approve

# Terraform 결과물(IP 주소)을 JSON 파일로 저장
terraform output -json > ../tf_outputs.json
cd ..
echo "인프라 프로비저닝이 성공적으로 완료되었습니다!"

# 2. Ansible 인벤토리 생성
echo "Ansible 인벤토리 생성 중 입니다..."
MASTER_IP=$(jq -r '.master_ip.value' tf_outputs.json)
MASTER_PRIVATE_IP=$(jq -r '.master_private_ip.value' tf_outputs.json)
WORKER_PRIVATE_IPS=$(jq -r '.worker_private_ip.value' tf_outputs.json)

# Ansible 인벤토리 파일 생성
cat > ansiblelab/inventory.ini << EOL
[master]
k8s-master ansible_host=${MASTER_IP} master_private_ip=${MASTER_PRIVATE_IP}

[workers]
EOL


# 워커 IP 목록 추가
for IP in $WORKER_PRIVATE_IPS; do
  echo "k8s-worker-0 ansible_host=${IP} ansible_ssh_common_args='-o ProxyCommand=\"ssh -i /root/proj/ssh_key -W %h:%p -q ubuntu@${MASTER_IP}\"'" >> ansiblelab/inventory.ini
done
# 워커는 Private IP로만 접근하므로 Master의 Floating IP를 Bastion/Proxy로 사용합니다.

cat >> ansiblelab/inventory.ini << EOL
[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=/root/proj/ssh_key

EOL

echo "Ansible 인벤토리가 생성되었습니다!"
cat ansiblelab/inventory.ini

# 잠시 대기 (VM 부팅 및 SSH 준비 시간)
echo "9분만 기다려주십시오...! (오픈스택 환경에서는 VM이 부팅되고 SSH를 연결하는데 매우 오랜 시간이 걸립니다...)"
sleep 540

# 3. Ansible 플레이북 실행
echo "Ansible로 Kubernetes 클러스터를 생성하고 있습니다...잠시만 기다려주세요!(시간이 오래 걸릴 수 있습니다)"
cd ansiblelab
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory.ini playbook.yml
cd ..
echo "Kubernetes 클러스터가 생성되었습니다!"

# 4. Kubeconfig 파일 로컬로 다운로드 및 수정
echo "kubeconfig 파일을 다운로드 중 입니다..."
scp -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa_k8s centos@${MASTER_IP}:/home/centos/.kube/config ./kubeconfig

# 다운로드한 kubeconfig 파일의 서버 주소를 내부 IP에서 외부 Floating IP로 변경
sed -i -e "s/server: https:\/\/.*:6443/server: https:\/\/${MASTER_IP}:6443/g" kubeconfig
chmod 600 ./kubeconfig

echo "Kubeconfig 파일이 준비되었습니다!"

# 5. 최종 확인
echo "축하합니다! 모든 배포 과정이 완료되었습니다!"
echo "--------------------------------------------------"
echo "이제 아래 명령어로 클러스터에 접근할 수 있습니다~"
echo "export KUBECONFIG=$(pwd)/kubeconfig"
echo "kubectl get nodes"
echo "--------------------------------------------------"

# export KUBECONFIG=$(pwd)/kubeconfig
# kubectl get nodes
