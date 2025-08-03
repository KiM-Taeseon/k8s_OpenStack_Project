```bash
#           축하합니다! 모든 배포가 완료되었습니다!          #

이제 아래 명령어로 클러스터에 접근할 수 있습니다:

export KUBECONFIG=./kubeconfig
kubectl get nodes

$ export KUBECONFIG=./kubeconfig
$ kubectl get nodes
NAME         STATUS   ROLES           AGE   VERSION
k8s-master   Ready    control-plane   5m    v1.28.0
k8s-worker-1 Ready    <none>          4m    v1.28.0

$ kubectl cluster-info
Kubernetes control plane is running at https://10.0.1.100:6443
CoreDNS is running at https://10.0.1.100:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```
