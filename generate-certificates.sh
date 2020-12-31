#!/bin/bash
# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# initialize params
declare DRY_RUN=" "
# org level components
declare -a orgcomponents=( "apigee-connect-agent" "apigee-mart" "apigee-watcher" )
# certificate expiry is set to 30 days
declare DURATION="30d"
# renew cert 24 hours before expiry
declare RENEW_BEFORE="24h"

#**
# @brief    Displays usage details.
#
usage() {
    echo -e "$*\n usage: $(basename "$0")" \
        "-o <org> -e <env> -c <component> -n <namespace>\n" \
        "example: $(basename "$0") -o my-org -e test1,test2\n" \
        "Parameters:\n" \
        "-o --org       : Apigee organization name (mandatory parameter)\n" \
        "-e --envs      : A comma separated list of Apigee environment names (mandatory parameter)\n" \
        "-n --namespace : Apigee namespace name (optional parameter; defaults to apigee)\n" 
        "--dry-run      : Equivalent of kubectl --dry-run=client"
    exit 1    
}

### Start of mainline code ###

PARAMETERS=()
while [[ $# -gt 0 ]]
do
    param="$1"

    case $param in
        -o|--org)
        ORG="$2"
        shift 
        shift 
        ;;
        -e|--envs)
        ENVS="$2"
        shift 
        shift 
        ;;
        -n|--namespace)
        NAMESPACE="$2"
        shift 
        shift 
        ;;
        --dry-run)
        DRY_RUN=" -o yaml --dry-run=client "
        shift 
        ;;        
        *)
        PARAMETERS+=("$1") 
        shift 
        ;;
    esac
done

set -- "${PARAMETERS[@]}"

IFS=', ' read -r -a envionments <<< "$ENVS"

if [[ -z $ORG ]]; then
    usage "org name is a mandatory parameter"
fi

if [[ -z $NAMESPACE ]]; then
  #set the default namespace
  NAMESPACE="apigee"
  echo "Using default namespace " $NAMESPACE
fi

if [[ -z $ENVS ]]; then
    usage "At least one env name is mandatory"
fi

cat <<EOF | kubectl apply $DRY_RUN -f -
apiVersion: cert-manager.io/v1alpha2
kind: Certificate
metadata:
  name: apigee-cassandra-default
  namespace: $NAMESPACE
spec:
  commonName: apigee-cassandra-default.$NAMESPACE.svc.cluster.local
  dnsNames:
  - apigee-cassandra-default.$NAMESPACE.svc.cluster.local
  issuerRef:
    kind: ClusterIssuer
    name: apigee-ca-issuer
  secretName: apigee-cassandra-default-tls
  duration: $DURATION
  renewBefore: $RENEW_BEFORE
  usages:
  - digital signature
  - key encipherment
  - client auth
  - server auth
EOF

len=$(( ${#orgcomponents[@]} + 1 ))
j=1

for (( i=2; i<=$len; i++ ));
do
NAME=$(apigeectl encode --org $ORG 2>&1 | sed -n ${i}p)
cat <<EOF | kubectl apply $DRY_RUN -f -
apiVersion: cert-manager.io/v1alpha2
kind: Certificate
metadata:
  name: $NAME
  namespace: $NAMESPACE
spec:
  secretName: $NAME-tls
  duration: $DURATION
  renewBefore: $RENEW_BEFORE   
  issuerRef:
    kind: ClusterIssuer
    name: apigee-ca-issuer
  commonName: $NAME
  dnsNames:
  - $NAME.$NAMESPACE.svc.cluster.local
  usages:
  - digital signature
  - key encipherment
  - client auth
  - server auth
EOF
j=$((j+1))
done

for i in "${!environments[@]}"; do
    envname=${environments[i]}
    for (( j=1; j<4; j++ ));
    do
    NAME=$(apigeectl encode --org $ORG --env ${envname} 2>&1 | sed -n ${j}p)
cat <<EOF | kubectl apply $DRY_RUN -f -
apiVersion: cert-manager.io/v1alpha2
kind: Certificate
metadata:
  name: $NAME
  namespace: $NAMESPACE
spec:
  secretName: $NAME-tls
  duration: $DURATION
  renewBefore: $RENEW_BEFORE   
  issuerRef:
    kind: ClusterIssuer
    name: apigee-ca-issuer
  commonName: $NAME
  dnsNames:
  - $NAME.$NAMESPACE.svc.cluster.local
  usages:
  - digital signature
  - key encipherment
  - client auth
  - server auth
EOF
    done
done
