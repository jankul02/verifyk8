

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
printf "" > keystore.secrets.yaml
printf "" > keystores.yaml




openssl req -new -x509 -keyout ca-key -out ca-cert -days 365 -passin pass:test1234 -passout pass:test1234 -subj "/CN=<YOUR_KAFKA_DOMAIN_HERE>/OU=DevOps/O=AbarCloud/L=FA/ST=Tehran/C=Iran"



instances="zk-0 zk-1 zk-2 kafka-0 kafka-1 kafka-2 kafka-client-0 zk-client-0"

for hostname in $instances
do
keytool -keystore server.keystore.jks -alias localhost -validity {validity} -genkey -keyalg RSA -ext SAN=DNS:{FQDN}
keytool -keystore kafka.server.keystore.jks -alias localhost -keyalg RSA -validity {validity} -genkey -storepass {keystore-pass} -keypass {key-pass} -dname {distinguished-name} -ext SAN=DNS:{hostname}

#  per instance: generate a self-signed certificate and store it together with the private key in keystore.jks. 
keytool -genkeypair -alias ${hostname} -keyalg RSA -keysize 2048 -dname "cn=${hostname}" -keypass password -keystore keystore.jks.${hostname} -storepass $kpswd -ext san=dns:${hostname}.zk-hs.${namespace}.svc.cluster.local

keytool -exportcert -alias ${hostname} -keystore keystore.jks.${hostname} -file ${hostname}.cer -rfc

keytool -importcert -alias ${hostname} -file ${hostname}.cer -keystore truststore.jks.${hostname} -storepass password


done




for hostname in $instances
do
for otherinstance in $instances
do
keytool -importcert -alias ${otherinstance} -file ${otherinstance}.cer -keystore truststore.jks.${hostname} -storepass password
done
done

printf "" > keystores.base64.secret.yaml
for hostname in $instances
do
cat server.keystore.${hostname} | base64 -w0 > server.keystore.${hostname}.base64  
cat server.truststore.${hostname} | base64 -w0 > server.truststore.${hostname}.base64  
cat << EOFKEYSTORE >>keystores.base64.secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: keystore-${hostname}
  namespace: default
data:
  keystore.jks: "$(cat server.keystore.${hostname}.base64)"
  truststore.jks: "$(cat server.keystore.${hostname}.base64)"
---
apiVersion: v1
kind: Secret
metadata:
  name: keystore-${hostname}
  namespace: default
data:
  keystore.jks: "$(cat server.keystore.${hostname}.base64)"
  truststore.jks: "$(cat server.keystore.${hostname}.base64)"
---

EOFKEYSTORE
rm server.keystore.${hostname} server.keystore.${hostname}.base64 
done