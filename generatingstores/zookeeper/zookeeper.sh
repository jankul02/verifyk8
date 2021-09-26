#!/usr/bin/env bash

set -eux

namespace=${namespace:-"kafka"}

if [ x${1:-""} != x ]
then
PASS=$1
echo kpswd new 
else
PASS=$(printf dGFwb3dhMDEK | base64 --decode)
echo PASS standard
fi
echo OK



for ((instanceidx=0;instanceidx<8;instanceidx++))
do

keytool -genkeypair -alias zk-${instanceidx}.zk-hs.${namespace}.svc.cluster.local -keyalg RSA -keysize 2048 -dname "cn=zk-${instanceidx}.zk-hs.${namespace}.svc.cluster.local" -keypass $PASS -keystore keystore.jks.${instanceidx} -storepass $PASS
keytool -exportcert -alias zk-${instanceidx}.zk-hs.${namespace}.svc.cluster.local -keystore keystore.jks.${instanceidx} -file zk-${instanceidx}.cer -rfc -storepass $PASS -keypass $PASS
done

for ((instanceidx=0;instanceidx<8;instanceidx++))
do
keytool -importcert -alias zk-${instanceidx}.zk-hs.${namespace}.svc.cluster.local -file zk-${instanceidx}.cer -keystore truststore.jks -storepass $PASS -keypass $PASS  -noprompt
done

printf "" > keystores.base64.secret.yaml

for ((instanceidx=0;instanceidx<8;instanceidx++))
do
PASSBASE64=$(printf $PASS  | base64 -w0)

cat << EOFKEYSTORE >>keystores.base64.secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: keystore-zk-${instanceidx}
  namespace: ${namespace}
data:
  keystore.jks: "$(cat keystore.jks.${instanceidx} | base64 -w0 )"
  truststore.jks: "$(cat truststore.jks | base64 -w0)"
---
apiVersion: v1
kind: Secret
metadata:
  name: keystorepasswd-zk-${instanceidx}
  namespace: ${namespace}
data:
  keystorepassword: ${PASSBASE64} 
  truststorepassword: ${PASSBASE64}
---
EOFKEYSTORE


done

rm -f keystore.jks
rm -f truststore.jks
rm -f keystore.jks.*
rm -f zk-*.cer