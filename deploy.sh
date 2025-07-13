set -euo pipefail

# 스크립트의 절대 경로를 기준으로 작업 디렉토리 설정 (안정성 향상)
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
cd "$SCRIPT_DIR"


# 인프라 생성 및 Ansible 준비

echo "오픈스택에 쿠버네티스 배포를 시작합니다!"

# OpenStack 인증 정보 로드

source ./admin-openrc_.sh
echo "OpenStack 인증 정보를 로드했습니다."

# Terraform으로 인프라 생성
echo "Terraform으로 인프라를 생성합니다..."
cd terraformlab
terraform init -upgrade
terraform apply -auto-approve
# 생성된 Output을 JSON 파일로 저장
terraform output -json > ../tf_outputs.json
cd ..
echo "인프라 프로비저닝이 성공적으로 완료되었습니다!"

# Terraform Output에서 변수 추출 및 검증
echo "Terraform Output에서 변수 정보를 추출합니다..."
MASTER_IP=$(jq -r '.master_ip.value' tf_outputs.json)
WORKER_IPS=$(jq -r '.worker_ips.value[]' tf_outputs.json | tr '\n' ' ')
SSH_KEY_PATH=$(jq -r '.ssh_private_key_path.value' tf_outputs.json)

if [[ -z "${MASTER_IP}" || "${MASTER_IP}" == "null" ]]; then
    echo "오류: 마스터 노드의 IP를 가져올 수 없습니다. tf_outputs.json 파일을 확인하세요."
    exit 1
fi
# 워커 IP가 비어있는지 문자열로 확인
if [[ -z "${WORKER_IPS}" ]]; then
    echo "오류: 워커 노드의 IP를 가져올 수 없습니다. tf_outputs.json 파일을 확인하세요."
    exit 1
fi
if [[ ! -f "${SSH_KEY_PATH}" ]]; then
    echo "오류: SSH 개인 키 파일(${SSH_KEY_PATH})을 찾을 수 없습니다."
    exit 1
fi

# Ansible 인벤토리 파일 생성
echo "Ansible 인벤토리 파일을 생성합니다..."
INVENTORY_FILE="ansiblelab/inventory.ini"

cat > "${INVENTORY_FILE}" << EOL
[masters]
k8s-master ansible_host=${MASTER_IP}

[workers]
EOL

# 워커 IP 목록을 하나씩 추가
# for 루프는 공백으로 구분된 문자열을 순회할 수 있습니다.
for IP in ${WORKER_IPS}; do
  HOSTNAME="k8s-worker-${IP//./-}"
  echo "${HOSTNAME} ansible_host=${IP}" >> "${INVENTORY_FILE}"
done

# [all:vars] 섹션 추가
cat >> "${INVENTORY_FILE}" << EOL

[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=${SSH_KEY_PATH}
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
EOL

echo "Ansible 인벤토리가 성공적으로 생성되었습니다:"
cat "${INVENTORY_FILE}"


# 인프라 안정화 대기


echo "모든 노드의 SSH 연결 준비를 확인합니다..."

ALL_NODES="${MASTER_IP} ${WORKER_IPS}"

for IP in ${ALL_NODES}; do
    echo "  - 노드(${IP}) 확인 중..."
    NODE_READY=false
    # 최대 10분간 10초 간격으로 SSH 접속 시도
    for i in {1..60}; do
        if ssh -o ConnectTimeout=10 -o BatchMode=yes -i "${SSH_KEY_PATH}" "ubuntu@${IP}" 'echo "OK"' &>/dev/null; then
            echo "노드(${IP}) SSH 준비 완료!"
            NODE_READY=true
            break
        fi
        echo -n "."
        sleep 10
    done
    
    if [[ "$NODE_READY" != "true" ]]; then
        echo -e "\n오류: 노드(${IP}) 접속에 실패했습니다. VM 상태를 확인해주세요."
        exit 1
    fi
done

echo "모든 노드의 SSH 연결이 확인되었습니다."
echo "Ansible 실행 전 시스템 안정화를 위해 추가 대기 (30초)..."
sleep 30


# Ansible 실행


echo "Ansible로 Kubernetes 클러스터를 생성합니다..."
cd ansiblelab
ansible-playbook -i inventory.ini playbook.yml -vvv
cd ..
echo "Kubernetes 클러스터 생성이 완료되었습니다!"


# 4. 마무리 작업


KUBECONFIG_PATH="${SCRIPT_DIR}/kubeconfig"
echo "kubeconfig 파일을 다운로드하여 '${KUBECONFIG_PATH}'에 저장합니다..."
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "${SSH_KEY_PATH}" "ubuntu@${MASTER_IP}":/home/ubuntu/.kube/config "${KUBECONFIG_PATH}"

# kubeconfig 파일의 서버 주소를 공인 IP로 변경
sed -i -e "s|server: https://.*:6443|server: https://${MASTER_IP}:6443|g" "${KUBECONFIG_PATH}"
chmod 600 "${KUBECONFIG_PATH}"
echo "kubeconfig 파일 준비 완료!"

echo
echo 
echo "#           축하합니다! 모든 배포가 완료되었습니다!          #"
echo 
echo
echo "이제 아래 명령어로 클러스터에 접근할 수 있습니다:"
echo
echo "export KUBECONFIG=${KUBECONFIG_PATH}"
echo "kubectl get nodes"
echo