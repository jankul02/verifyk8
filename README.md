# presetup

## default namespace to kafka

kubectl config set-context --current --namespace=kafka




# Cert Manager setup

kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.5.3/cert-manager.yaml

curl -L -o kubectl-cert-manager.tar.gz https://github.com/jetstack/cert-manager/releases/latest/download/kubectl-cert_manager-linux-amd64.tar.gz
tar xzf kubectl-cert-manager.tar.gz
sudo mv kubectl-cert_manager /usr/local/bin
rm kubectl-cert-manager.tar.gz


kubectl cert-manager renew # allows you to manually trigger a renewal of a specific certificate.

#uninstall
kubectl delete -f https://github.com/jetstack/cert-manager/releases/download/v1.5.3/cert-manager.yaml
sudo rm  /usr/local/bin/kubectl-cert_manager



# jks cert-manager
https://cert-manager.io/docs/release-notes/release-notes-1.2/

apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: jks-example
spec:
  secretName: jks-keystore
  jks:
    create: true
    passwordSecretRef:
      name: supersecret
      key: password


# what about:
Enable mTLS on Pods with CSI: https://cert-manager.io/docs/usage/csi/