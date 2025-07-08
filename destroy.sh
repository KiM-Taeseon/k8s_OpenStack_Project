#!/bin/bash
set -e


echo "생성된 모든 인프라와 로컬 파일 및 자원들을 삭제합니다."
echo -e "이 작업은 되돌릴 수 없습니다! 계속하려면 'y'를 입력하세요."
read confirmation
if [ "$confirmation" != "y" ]; then
    echo "삭제 작업을 취소했습니다."
    exit 0
fi

if [ ! -f "admin-openrc_.sh" ]; then
    echo -e "오류: 'openrc.sh' 파일이 없습니다. Terraform 자원을 삭제할 수 없습니다."
    exit 1
fi

echo -e "OpenStack 인증 정보를 로드합니다..."
source ./admin-openrc_.sh

echo -e "Terraform으로 생성된 인프라를 삭제합니다... 잠시만 기다려주십시오."
(cd terraform && terraform destroy -auto-approve)
cd ..

echo -e "로컬에 생성된 파일을 정리합니다..."
rm -f ansiblelab/inventory.ini
rm -f ../kubeconfig
rm -f tf_outputs.json

echo -e "모든 자원 삭제 및 정리가 완료되었습니다!"