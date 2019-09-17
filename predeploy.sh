#!/bin/bash
set -x

# touch /var/log/swarm-${CLUSTER_NAMESPACE}.log
# echo -e "Starting Pre-deploy Check for namespace: ${CLUSTER_NAMESPACE}" 2>&1 | tee -a ./logs/swarm-${CLUSTER_NAMESPACE}.log

# mkdir /home/pipeline/logs
# touch /home/pipeline/logs/predeploy-otc.log
#
# /opt/mt-logstash-forwarder/init/deb-init.d/mt-logstash-forwarder.init start
#
# echo 'LSF_INSTANCE_ID="swarm-otc-logs"' > /etc/mt-logstash-forwarder/mt-lsf-config.sh
# echo 'LSF_TARGET="ingest.logging.ng.bluemix.net:9091"' >> /etc/mt-logstash-forwarder/mt-lsf-config.sh
# echo 'LSF_TENANT_ID="a:ad5d072102214f4395eab22f03bbb2f9"' >> /etc/mt-logstash-forwarder/mt-lsf-config.sh
# echo 'LSF_PASSWORD="5fHX1j4UDBMV"' >> /etc/mt-logstash-forwarder/mt-lsf-config.sh
# echo 'LSF_GROUP_ID="swarm-otc-logging"' >> /etc/mt-logstash-forwarder/mt-lsf-config.sh
#
# echo '# The list of files configurations
# {
#     "files": [
#         {
#         "paths": ["/home/pipeline/logs/predeploy-otc.log"],
#         "fields": { "type": "swarm-otc" },
#         "is_json": false
#     }
#     ]
# }' > /etc/mt-logstash-forwarder/conf.d/sockstore.conf
#
# /opt/mt-logstash-forwarder/init/deb-init.d/mt-logstash-forwarder.init force-reload

# apt-get install -y curl
# curl -fsSL https://clis.ng.bluemix.net/install/linux | sh
#
ibmcloud login --apikey ${API_KEY} -a ${API_URL}
ibmcloud plugin install container-service -r Bluemix
ibmcloud cs init

CLUSTER_CONFIG="$(ibmcloud cs cluster-config ${CLUSTER_NAME})"
KUBE_CONFIG=`echo "${CLUSTER_CONFIG}" | grep -Po 'KUBECONFIG=\K.*'`
export KUBECONFIG=${KUBE_CONFIG}

#ibmcloud cs cluster-config ${CLUSTER_NAME} | ggrep -Po 'KUBECONFIG=\K.*'
#export KUBECONFIG=/root/.bluemix/plugins/container-service/clusters/swarm-mzr-ussouth/kube-config-dal12-swarm-mzr-ussouth.yml

apt-get install -y apt-transport-https
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
touch /etc/apt/sources.list.d/kubernetes.list
echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" | tee -a /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubectl

curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh

# echo -e "${BUILD_ID}: Starting Pre-deploy Check for namespace: ${CLUSTER_NAMESPACE}" 2>&1 | tee -a /home/pipeline/logs/predeploy-otc.log

# SET CHART_NAME
echo -e "Looking for chart under ./sockstore/deploy/kubernetes/helm-chart/<CHART_NAME>"

if [ -d ./sockstore/deploy/kubernetes/helm-chart ]; then
  #CHART_NAME=$(find chart/. -maxdepth 2 -type d -name '[^.]?*' -printf %f -quit)
  #CHART_NAME=$(find ./sockstore/deploy/kubernetes/helm-chart/. -maxdepth 2 -type d -name '[^.]?*' -printf %f -quit)
  export CHART_NAME="helm-chart"
fi
if [ -z "${CHART_NAME}" ]; then
    echo -e "No Helm chart found for Kubernetes deployment under ./sockstore/deploy/kubernetes/helm-chart."
    exit 1
else
    echo -e "Helm chart found for Kubernetes deployment : ./sockstore/deploy/kubernetes/helm-chart"
fi

# SET REGISTRY_URL
export REGISTRY_URL="registry.ng.bluemix.net"

# SET vars
source ./sockstore/scripts/otc/set-vars.sh
echo "FRONT_END_IMAGE_NAME=${FRONT_END_IMAGE_NAME}"
echo "FRONT_END_IMAGE_TAG=${FRONT_END_IMAGE_TAG}"

echo "CHART_NAME=${CHART_NAME}"
echo "REGISTRY_URL=${REGISTRY_URL}"
echo "REGISTRY_NAMESPACE=${REGISTRY_NAMESPACE}"

# also run 'env' command to find all available env variables
# or learn more about the available environment variables at:
# https://console.bluemix.net/docs/services/ContinuousDelivery/pipeline_deploy_var.html#deliverypipeline_environment

# Input env variables from pipeline job
echo "PIPELINE_KUBERNETES_CLUSTER_NAME=${CLUSTER_NAME}"
echo "CLUSTER_NAMESPACE=${CLUSTER_NAMESPACE}"

#Check cluster availability
echo "=========================================================="
echo "CHECKING CLUSTER readiness and namespace existence"
IP_ADDR=$(ibmcloud cs workers ${CLUSTER_NAME} | grep normal | awk '{ print $2 }')
if [ -z "${IP_ADDR}" ]; then
  echo -e "${CLUSTER_NAME} not created or workers not ready"
  exit 1
fi
echo "Configuring cluster namespace"
if kubectl get namespace ${CLUSTER_NAMESPACE}; then
  echo -e "Namespace ${CLUSTER_NAMESPACE} found."
else
  kubectl create namespace ${CLUSTER_NAMESPACE}
  echo -e "Namespace ${CLUSTER_NAMESPACE} created."
fi

#Check AppID Service availability
echo "=========================================================="
echo "CHECKING AppID readiness and existence"
kubectl config set-context $(kubectl config current-context) --namespace=${CLUSTER_NAMESPACE}
if kubectl get secret binding-${APPID_ALIAS}; then
  echo -e "Secret binding-${APPID_ALIAS} found."
else
  echo -e "Secret binding-${APPID_ALIAS} not found."
  exit 1
fi

# Grant access to private image registry from namespace $CLUSTER_NAMESPACE
# reference https://console.bluemix.net/docs/containers/cs_cluster.html#bx_registry_other
echo "=========================================================="
# echo -e "CONFIGURING ACCESS to private image registry from namespace ${CLUSTER_NAMESPACE}"
# # IMAGE_PULL_SECRET_NAME="ibmcloud-toolchain-${PIPELINE_TOOLCHAIN_ID}-${REGISTRY_URL}"
#
# echo -e "Checking for presence of ${IMAGE_PULL_SECRET_NAME} imagePullSecret for this toolchain"
# if ! kubectl get secret ${IMAGE_PULL_SECRET_NAME} --namespace ${CLUSTER_NAMESPACE}; then
#   echo -e "${IMAGE_PULL_SECRET_NAME} not found in ${CLUSTER_NAMESPACE}, creating it"
#   # for Container Registry, docker username is 'token' and email does not matter
#   kubectl create secret docker-registry ${IMAGE_PULL_SECRET_NAME} --namespace ${CLUSTER_NAMESPACE} --docker-server=${REGISTRY_URL} --docker-password=${PIPELINE_BLUEMIX_API_KEY} --docker-username=iamapikey --docker-email=a@b.com || echo "Unable to create secret"
# else
#   echo -e "Namespace ${CLUSTER_NAMESPACE} already has an imagePullSecret for this toolchain."
# fi
#
# # echo "Checking ability to pass pull secret via Helm chart"
# CHART_PULL_SECRET=$( grep 'pullSecret' ./sockstore/deploy/kubernetes/${CHART_NAME}/values.yaml || : )
# if [ -z "$CHART_PULL_SECRET" ]; then
#   echo "WARNING: Chart is not expecting an explicit private registry imagePullSecret. Will patch the cluster default serviceAccount to pass it implicitly for now."
#   echo "Going forward, you should edit the chart to add in:"
#   echo -e "[./sockstore/deploy/kubernetes/${CHART_NAME}/templates/deployment.yaml] (under kind:Deployment)"
#   echo "    ..."
#   echo "    spec:"
#   echo "      imagePullSecrets:               #<<<<<<<<<<<<<<<<<<<<<<<<"
#   echo "        - name: __not_implemented__   #<<<<<<<<<<<<<<<<<<<<<<<<"
#   echo "      containers:"
#   echo "        - name: __not_implemented__"
#   echo "          image: "__not_implemented__:__not_implemented__"
#   echo "    ..."
#   echo -e "[./sockstore/deploy/kubernetes/${CHART_NAME}/values.yaml]"
#   echo "or check out this chart example: https://github.com/open-toolchain/hello-helm/tree/master/chart/hello"
#   echo "or refer to: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/#create-a-pod-that-uses-your-secret"
#   echo "    ..."
#   echo "    image:"
#   echo "repository: webapp"
#   echo "  tag: 1"
#   echo "  pullSecret: regsecret            #<<<<<<<<<<<<<<<<<<<<<<<<"
#   echo "  pullPolicy: IfNotPresent"
#   echo "    ..."
#   echo "Enabling default serviceaccount to use the pull secret"
#   #kubectl patch -n ${CLUSTER_NAMESPACE} serviceaccount/default -p '{"imagePullSecrets":[{"name":"'"${IMAGE_PULL_SECRET_NAME}"'"}]}'
#   echo "default serviceAccount:"
#   kubectl get serviceAccount default -o yaml
#   echo -e "Namespace ${CLUSTER_NAMESPACE} authorizing with private image registry using patched default serviceAccount"
# else
#   echo -e "Namespace ${CLUSTER_NAMESPACE} authorizing with private image registry using Helm chart imagePullSecret"
# fi

echo "=========================================================="
echo "CONFIGURING TILLER enabled (Helm server-side component)"
helm init --upgrade
kubectl rollout status -w deployment/tiller-deploy --namespace=kube-system
helm version

echo "=========================================================="
echo -e "CHECKING HELM releases in this namespace: ${CLUSTER_NAMESPACE}"
helm list --namespace ${CLUSTER_NAMESPACE}

# echo -e "${BUILD_ID}: Finished Pre-deploy Check for namespace: ${CLUSTER_NAMESPACE}" 2>&1 | tee -a /home/pipeline/logs/predeploy-otc.log
# echo -e "\n" >> /home/pipeline/logs/predeploy-otc.log
# cat /home/pipeline/logs/predeploy-otc.log

# sleep 1m
