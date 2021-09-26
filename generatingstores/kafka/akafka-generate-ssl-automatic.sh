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

VALIDITY_IN_DAYS=3650
TRUSTSTORE_WORKING_DIRECTORY="truststore"
DEFAULT_TRUSTSTORE_FILENAME="truststore.jks"
CA_CERT_FILE="ca-cert"
KEYSTORE_SIGN_REQUEST="cert-file"
KEYSTORE_SIGN_REQUEST_SRL="ca-cert.srl"
KEYSTORE_SIGNED_CERT="cert-signed"


COUNTRY=${COUNTRY:-DE}
STATE=${STATE:-Bayern}
OU=${ORGANIZATION_UNIT:-dataproxy}
CN=dataproxy
LOCATION=${CITY:-Munich}

function file_exists_and_exit() {
  echo "'$1' cannot exist. Move or delete it before"
  echo "re-running this script."
  exit 1
}

echo "Welcome to the Kafka SSL keystore and trust store generator script."

trust_store_file=""
trust_store_private_key_file=""

  if [ -e "$TRUSTSTORE_WORKING_DIRECTORY" ]; then
    file_exists_and_exit $TRUSTSTORE_WORKING_DIRECTORY
  fi

  mkdir $TRUSTSTORE_WORKING_DIRECTORY
  echo
  echo "OK, we'll generate a trust store and associated private key."
  echo
  echo "First, the private key."
  echo

  openssl req -new -x509 -keyout $TRUSTSTORE_WORKING_DIRECTORY/ca-key  -nodes \
    -subj "/C=$COUNTRY/ST=$STATE/L=$LOCATION/O=$OU/CN=dataproxy" \
    -out $TRUSTSTORE_WORKING_DIRECTORY/ca-cert -days $VALIDITY_IN_DAYS 

  openssl req -new -x509 -keyout $TRUSTSTORE_WORKING_DIRECTORY/ca-key \
    -out $TRUSTSTORE_WORKING_DIRECTORY/ca-cert -days $VALIDITY_IN_DAYS -nodes \
    -subj "/C=$COUNTRY/ST=$STATE/L=$LOCATION/O=$OU/CN=dataproxy"

  trust_store_private_key_file="$TRUSTSTORE_WORKING_DIRECTORY/ca-key"

  echo
  echo "Two files were created:"
  echo " - $TRUSTSTORE_WORKING_DIRECTORY/ca-key -- the private key used later to"
  echo "   sign certificates"
  echo " - $TRUSTSTORE_WORKING_DIRECTORY/ca-cert -- the certificate that will be"
  echo "   stored in the trust store in a moment and serve as the certificate"
  echo "   authority (CA). Once this certificate has been stored in the trust"
  echo "   store, it will be deleted. It can be retrieved from the trust store via:"
  echo "   $ keytool -keystore <trust-store-file> -export -alias CARoot -rfc"

  echo
  echo "Now the trust store will be generated from the certificate."
  echo

  keytool -storetype JKS -keystore $TRUSTSTORE_WORKING_DIRECTORY/$DEFAULT_TRUSTSTORE_FILENAME -alias CARoot -importcert -file $TRUSTSTORE_WORKING_DIRECTORY/ca-cert  -noprompt -keypass $PASS -storepass $PASS
  

  # keytool -storetype JKS -keystore  $TRUSTSTORE_WORKING_DIRECTORY/$DEFAULT_TRUSTSTORE_FILENAME \
  #   -alias CARoot -import -file $TRUSTSTORE_WORKING_DIRECTORY/ca-cert \
  #   -noprompt -keypass $PASS -storepass $PASS
  
  trust_store_file="$TRUSTSTORE_WORKING_DIRECTORY/$DEFAULT_TRUSTSTORE_FILENAME"

  echo
  echo "$TRUSTSTORE_WORKING_DIRECTORY/$DEFAULT_TRUSTSTORE_FILENAME was created."

  # don't need the cert because it's in the trust store.
  rm $TRUSTSTORE_WORKING_DIRECTORY/$CA_CERT_FILE

echo
echo "Continuing with:"
echo " - trust store file:        $trust_store_file"
echo " - trust store private key: $trust_store_private_key_file"

echo "#############################################################"
echo "############        generating keystores  ###################"
echo "#############################################################"
KEYSTORE_FILENAME="keystore.jks"

instances="zk-0 zk-1 zk-2 kafka-0 kafka-1 kafka-2 kafka-client-0 zk-client-0"
printf "" > keystores.base64.secret.yaml
for hostname in $instances
do

KEYSTORE_WORKING_DIRECTORY="keystore-${hostname}"


mkdir $KEYSTORE_WORKING_DIRECTORY

echo
echo "Now, a keystore will be generated. Each broker and logical client needs its own"
echo "keystore. This script will create only one keystore. Run this script multiple"
echo "times for multiple keystores."
echo
echo "     NOTE: currently in Kafka, the Common Name (CN) does not need to be the FQDN of"
echo "           this host. However, at some point, this may change. As such, make the CN"
echo "           the FQDN. Some operating systems call the CN prompt 'first / last name'"

# To learn more about CNs and FQDNs, read:
# https://docs.oracle.com/javase/7/docs/api/javax/net/ssl/X509ExtendedTrustManager.html


keytool -keystore $KEYSTORE_WORKING_DIRECTORY/$KEYSTORE_FILENAME -alias localhost -keyalg RSA -validity $VALIDITY_IN_DAYS \
 -genkey -keypass $PASS -storepass $PASS -dname "C=$COUNTRY, ST=$STATE, L=$LOCATION, O=$OU, CN=${hostname}.zk-hs.default.svc.cluster.local"  -ext SAN=DNS:${hostname}

# keytool -storetype JKS  -keystore $KEYSTORE_WORKING_DIRECTORY/$KEYSTORE_FILENAME \
#   -alias localhost -validity $VALIDITY_IN_DAYS -genkey -keyalg RSA \
#    -noprompt -dname "C=$COUNTRY, ST=$STATE, L=$LOCATION, O=$OU, CN=${hostname}" -keypass $PASS -storepass $PASS

echo
echo "'$KEYSTORE_WORKING_DIRECTORY/$KEYSTORE_FILENAME' now contains a key pair and a"
echo "self-signed certificate. Again, this keystore can only be used for one broker or"
echo "one logical client. Other brokers or clients need to generate their own keystores."

echo
echo "Fetching the certificate from the trust store and storing in $CA_CERT_FILE."
echo

keytool -storetype JKS  -keystore $trust_store_file -export -alias CARoot -rfc -file $CA_CERT_FILE -keypass $PASS -storepass $PASS

echo
echo "Now a certificate signing request will be made to the keystore."
echo
keytool -storetype JKS  -keystore $KEYSTORE_WORKING_DIRECTORY/$KEYSTORE_FILENAME -alias localhost \
  -certreq -file $KEYSTORE_SIGN_REQUEST -keypass $PASS -storepass $PASS

echo
echo "Now the trust store's private key (CA) will sign the keystore's certificate."
echo
openssl x509 -req -CA $CA_CERT_FILE -CAkey $trust_store_private_key_file \
  -in $KEYSTORE_SIGN_REQUEST -out $KEYSTORE_SIGNED_CERT \
  -days $VALIDITY_IN_DAYS -CAcreateserial
# creates $KEYSTORE_SIGN_REQUEST_SRL which is never used or needed.

echo
echo "Now the CA will be imported into the keystore."
echo
keytool -storetype JKS  -keystore $KEYSTORE_WORKING_DIRECTORY/$KEYSTORE_FILENAME -alias CARoot \
  -import -file $CA_CERT_FILE -keypass $PASS -storepass $PASS -noprompt
rm $CA_CERT_FILE # delete the trust store cert because it's stored in the trust store.

echo
echo "Now the keystore's signed certificate will be imported back into the keystore."
echo
keytool -storetype JKS  -keystore $KEYSTORE_WORKING_DIRECTORY/$KEYSTORE_FILENAME -alias localhost -import \
  -file $KEYSTORE_SIGNED_CERT -keypass $PASS -storepass $PASS

echo
echo "All done!"
echo
echo "Deleting intermediate files. They are:"
echo " - '$KEYSTORE_SIGN_REQUEST_SRL': CA serial number"
echo " - '$KEYSTORE_SIGN_REQUEST': the keystore's certificate signing request"
echo "   (that was fulfilled)"
echo " - '$KEYSTORE_SIGNED_CERT': the keystore's certificate, signed by the CA, and stored back"
echo "    into the keystore"

  rm $KEYSTORE_SIGN_REQUEST_SRL
  rm $KEYSTORE_SIGN_REQUEST
  rm $KEYSTORE_SIGNED_CERT

PASSBASE64=$(printf $PASS  | base64 -w0)
cat << EOFKEYSTORE >>keystores.base64.secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: keystore-${hostname}
  namespace: ${namespace}
data:
  keystore.jks: "$(cat $KEYSTORE_WORKING_DIRECTORY/$KEYSTORE_FILENAME | base64 -w0 )"
  truststore.jks: "$(cat $TRUSTSTORE_WORKING_DIRECTORY/$DEFAULT_TRUSTSTORE_FILENAME | base64 -w0)"
---
apiVersion: v1
kind: Secret
metadata:
  name: keystorepasswd-${hostname}
  namespace: ${namespace}
data:
  keystorepassword: ${PASSBASE64} 
  truststorepassword: ${PASSBASE64}
---
EOFKEYSTORE
 rm -rf $KEYSTORE_WORKING_DIRECTORY
done
rm -rf $TRUSTSTORE_WORKING_DIRECTORY  
