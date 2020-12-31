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
# environment level components
declare -a COMPONENTS=( "runtime" "sync" "udca" )

#**
# @brief    Displays usage details.
#
usage() {
    echo -e "$*\n usage: $(basename "$0")" \
        "-o <org> -e <env> -c <component> -n <namespace>\n" \
        "example: $(basename "$0") -o my-org -e test -c runtime \n" \
        "Parameters:\n" \
        "-o --org       : Apigee organization name (mandatory parameter)\n" \
        "-e --env       : Apigee environment name (mandatory parameter)\n" \
        "-c --component : Apigee component name (one of runtime, synchronizer or udca)\n" \
        "-n --namespace : Apigee namespace name (optional parameter; defaults to apigee)\n" \
        "--all-org      : Restart all components in an organization\n" \
        "--all-env      : Restart all components in an environment\n" \
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
        -e|--env)
        ENV="$2"
        shift 
        shift 
        ;;
        -c|--component)
        COMPONENT="$2"
        shift 
        shift 
        ;;
        -n|--namespace)
        NAMESPACE="$2"
        shift 
        shift 
        ;;
        --all-env)
        ALL_ENV="yes"
        shift 
        ;;
        --all-org)
        ALL_ORG="yes"
        shift 
        ;;
        --dry-run)
        DRY_RUN=" -o yaml --dry-run=true "
        shift 
        ;;                
        *)
        PARAMETERS+=("$1") 
        shift 
        ;;
    esac
done

set -- "${PARAMETERS[@]}"

if [[ -z $ORG ]]; then
    usage "org name is a mandatory parameter"
fi

if [[ -n $ALL_ORG && -n $ALL_ENV ]]; then
  usage "Flags --all-org and --all-env cannot be used together"
fi

if [[ -n $COMPONENT && -n $ALL_ENV ]]; then
  usage "Flags -c and --all-env cannot be used together"
fi

if [[ -z $NAMESPACE ]]; then
  #set the default namespace
  NAMESPACE="apigee"
  echo "Using default namespace " $NAMESPACE
fi

if [[ -n $ALL_ORG ]]; then
  echo "Restarting components for org " $ORG 
  kubectl -n $NAMESPACE patch ad $(kubectl get ad -n $NAMESPACE --template '{{range .items}}{{.metadata.name}}{{" "}}{{end}}' -l org=$ORG) -p '{"release":{"replaceWithClone":true}}' --type=merge $DRY_RUN
  RESULT=$?
  exit $RESULT
fi 

#environment is mandatory past this stage
if [[ -z $ENV ]]; then
    usage "Either use --all-org or --env for a specific environment"
fi

if [[  $ALL_ENV == "yes" ]]; then
    echo "Restarting components for env " $ENV " in org " $ORG
    kubectl -n $NAMESPACE patch ad $(kubectl get ad -n $NAMESPACE --template '{{range .items}}{{.metadata.name}}{{" "}}{{end}}' -l org=$ORG,env=$ENV) -p '{"release":{"replaceWithClone":true}}' --type=merge $DRY_RUN
    RESULT=$?
    exit $RESULT
fi

# component is mandatory past this stage
if [[ -z $COMPONENT ]]; then
    usage "component name is a mandatory parameter, must be one of runtime, synchronizer or udca"
else 
    if [[ ! " ${COMPONENTS[@]} " =~ $COMPONENT ]]; then
      usage "component name is a mandatory parameter, must be one of runtime, synchronizer or udca"
    fi
    echo "Restarting component " $COMPONENT " in env " $ENV " in org " $ORG
    kubectl -n $NAMESPACE patch ad $(kubectl get ad -n $NAMESPACE --template '{{range .items}}{{.metadata.name}}{{" "}}{{end}}' -l org=$ORG,env=$ENV,app=apigee-$COMPONENT) -p '{"release":{"replaceWithClone":true}}' --type=merge $DRY_RUN
    RESULT=$?
    exit $RESULT    
fi


