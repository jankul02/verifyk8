

namespace=default

kpswd_origin=$1

namespace=${namespace:-"default"}

if [ x$kpswd_origin != x ]
then
kpswd=$(printf $kpswd_origin  | base64 -w0)
echo kpswd new 
else
kpswd=dGFwb3dhMDEK
echo kpswd standard
fi
printf "" > cluster.issuer.yaml
printf "" > keystore.secrets.yaml
printf "" > certificates.yaml



# bootstrap the issuer
cat << EOFISSUER >> cluster.issuer.yaml 
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: dataproxy-selfsigned-issuer
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: dataproxy-selfsigned-ca
  namespace: ${namespace}
spec:
  isCA: true
  commonName: dataproxy-selfsigned-ca
  secretName: dataproxy-root-secret
  privateKey:
    algorithm: ECDSA
    size: 256
  issuerRef:
    name: dataproxy-selfsigned-issuer
    kind: ClusterIssuer
    group: cert-manager.io
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: dataproxy-ca-issuer
  namespace: ${namespace}
spec:
  ca:
    secretName: dataproxy-root-secret
EOFISSUER




for KEYST in zk-0 zk-1 zk-2 kafka-0 kafka-1 kafka-2 kafka-client-0 zk-client-0
do
cat << EOF >>keystore.secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: keystore-password-${KEYST}
  namespace: ${namespace}
  labels:
    app: zk
type: Opaque
data:
  keystorepassword: ${kpswd}
---
EOF

cat << EOF0 >>certificates.yaml
# 1. bootstrap the the issuer
# 2. create a keystore secret 
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: certificate-${KEYST}
  namespace: ${namespace}
spec:
  # Secret names are always required.
  secretName: secret-${KEYST}
  keystores:
    jks:
      create: true
      passwordSecretRef:
        name: keystore-password-${KEYST}
        key: keystorepassword


  # Secret template is optional. If set, these annotations
  # and labels will be copied to the secret named example-com-tls.
  secretTemplate:
    annotations:
      secret-annotation-1: "happy secret"
      secret-annotation-2: "kept secretly"
    labels:
      kafka: ${KEYST}

  duration: 21600h # 90d
  renewBefore: 360h # 15d
  subject:
    organizations:
      - dataproxy
  # The use of the common name field has been deprecated since 2000 and is
  # discouraged from being used.
  commonName: dataproxy.com
  isCA: false
  privateKey:
    algorithm: RSA
    encoding: PKCS1
    size: 2048
  usages:
    - server auth
    - client auth
  # At least one of a DNS Name, URI, or IP address is required.
  dnsNames:
    - ${KEYST}.default.svc.cluster.local
    - ${KEYST}.default
    - ${KEYST}
    - zk-client.default.svc.cluster.local
    - zk-client.default
    - zk-client
  # uris:
  #   - spiffe://cluster.local/ns/sandbox/sa/example
  # ipAddresses:
  #   - 192.168.0.5
  # Issuer references are always required.
  issuerRef:
    name: dataproxy-ca-issuer
    # We can reference ClusterIssuers by changing the kind here.
    # The default value is Issuer (i.e. a locally namespaced Issuer)
    kind: Issuer
    # This is optional since cert-manager will default to this value however
    # if you are using an external issuer, change this to that issuer group.
    group: cert-manager.io
---
EOF0
done

echo run:
echo "kubectl  apply -f cluster.issuer.yaml &&  kubectl  apply -f keystore.secrets.yaml &&  kubectl  apply -f certificates.yaml"