helm repo update\n
helm search repo ingress-nginx
helm show values ingress-nginx/ingress-nginx
helm show values ingress-nginx/ingress-nginx > helm-ingress.yaml
helm template --help
helm template ingress ingress-nginx/ingress-nginx > tpl-ingress.yaml
helm install --help
helm show readme ingress-nginx/ingress-nginx | grep controller.*.limit
helm show readme ingress-nginx/ingress-nginx | grep controller.
helm show readme ingress-nginx/ingress-nginx | grep limits
helm show readme ingress-nginx/ingress-nginx | grep limits
 helm show values ingress-nginx/ingress-nginx| grep replicaCount -A 5 -B 5
helm show values ingress-nginx/ingress-nginx| grep resource -A 5 -B 5
helm install --help
helm install -f infrastructure/ingress-nginx/values.yaml --create-namespace ingress-nginx 
helm install ingress-nginx -f infrastructure/ingress-nginx/values.yaml --create-namespace ingress-nginx 
helm install ingress-nginx -f infrastructure/ingress-nginx/values.yaml --create-namespace ingress-nginx ingress-nginx/ingress-nginx 
helm install ingress-nginx -f infrastructure/ingress-nginx/values.yaml --create-namespace -n ingress-nginx ingress-nginx/ingress-nginx
export KUBECONFIG=~/homelab/platform/rancher-proxy.kubeconfig 
helm install ingress-nginx -f infrastructure/ingress-nginx/values.yaml --create-namespace -n ingress-nginx ingress-nginx/ingress-nginx