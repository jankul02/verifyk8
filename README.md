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


keystore-secret-kafka-client-0 keystore-secret-zk-0 keystore-secret-zk-1  keystore-secret-zk-2    keystore-secret-zk-client-0  secret-kafka-0 secret-kafka-1 secret-kafka-2 secret-kafka-client-0 secret-zk-0 secret-zk-1 secret-zk-2 secret-zk-client-0


# every broker and/or CLI tool (such as the ZooKeeper security migration tool, ZkSecurityMigrator) must identify itself **using the same Distinguished Name (DN)**

# **client keystore password==key password for ZooKeeper** does not support setting the key password in the ZooKeeper client keystore (broker) to a value different from the keystore password itself


# If using mTLS only (without SASL) and specifying zookeeper.set.acl=true  , do not use certificates with CN=hostname where hostname differs based on the location from which the request originates as a means to satisfy hostname verification. If you do, you may find that brokers cannot access ZooKeeper nodes. Note that the full DN is included in the ZooKeeper ACL, and ZooKeeper only authorizes what is in the ACL.
1. either zookeeper.set.acl=false
or 
2. include a subject alternative name (SAN)