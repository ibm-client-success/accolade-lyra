#!/bin/bash
set -x

apt-get install -y jq

# IBM Cloud and Cluster setup
ibmcloud plugin install container-registry -r Bluemix
ibmcloud plugin install container-service -r Bluemix
ibmcloud login --apikey ${API_KEY} -a ${API_URL}
ibmcloud cs init
ibmcloud cr region-set ${REGION}
CLUSTER_CONFIG="$(ibmcloud cs cluster-config ${CLUSTER_NAME})"
KUBE_CONFIG=`echo "${CLUSTER_CONFIG}" | grep -Po 'KUBECONFIG=\K.*'`
export KUBECONFIG=${KUBE_CONFIG}

echo -e "Starting Deploy for namespace: ${CLUSTER_NAMESPACE}" 2>&1

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

# SET vars
source ./sockstore/scripts/otc/set-vars.sh

echo "CHART_NAME=${CHART_NAME}"
echo "REGISTRY_URL=${REGISTRY_URL}"
echo "REGISTRY_NAMESPACE=${REGISTRY_NAMESPACE}"

# also run 'env' command to find all available env variables
# or learn more about the available environment variables at:
# https://console.bluemix.net/docs/services/ContinuousDelivery/pipeline_deploy_var.html#deliverypipeline_environment

# Input env variables from pipeline job
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
  # exit 1
fi

echo "=========================================================="
echo "CONFIGURING TILLER enabled (Helm server-side component)"
helm init --upgrade
kubectl rollout status -w deployment/tiller-deploy --namespace=kube-system
helm version

echo "=========================================================="
echo -e "CHECKING HELM releases in this namespace: ${CLUSTER_NAMESPACE}"
helm list --namespace ${CLUSTER_NAMESPACE}

echo "=========================================================="
echo "DEFINE RELEASE by prefixing image (app) name with namespace if not 'default' as Helm needs unique release names across namespaces"
if [[ "${CLUSTER_NAMESPACE}" != "default" ]]; then
  RELEASE_NAME="${CLUSTER_NAMESPACE}-sockstore-app"
else
  RELEASE_NAME="sockstore-app"
fi
echo -e "Release name: ${RELEASE_NAME}"

echo "=========================================================="
echo "Overwriting image tags"
CART_IMAGE_TAG=$(ibmcloud cr images | grep ${CART_IMAGE_NAME} -m1 | awk '{print $2;}')
CART_IMAGE_TAG=$(ibmcloud cr images | grep ${CART_IMAGE_NAME} -m1 | awk '{print $2;}')
CATALOGUE_IMAGE_TAG=$(ibmcloud cr images | grep ${CATALOGUE_IMAGE_NAME} -m1 | awk '{print $2;}')
CATALOGUE_DB_IMAGE_TAG=$(ibmcloud cr images | grep ${CATALOGUE_DB_IMAGE_NAME} -m1 | awk '{print $2;}')
FRONT_END_IMAGE_TAG=$(ibmcloud cr images | grep ${FRONT_END_IMAGE_NAME} -m1 | awk '{print $2;}')
ORDER_IMAGE_TAG=$(ibmcloud cr images | grep ${ORDER_IMAGE_NAME} -m1 | awk '{print $2;}')
PAYMENT_IMAGE_TAG=$(ibmcloud cr images | grep ${PAYMENT_IMAGE_NAME} -m1 | awk '{print $2;}')
QUEUE_MASTER_IMAGE_TAG=$(ibmcloud cr images | grep ${QUEUE_MASTER_IMAGE_NAME} -m1 | awk '{print $2;}')
SHIPPING_IMAGE_TAG=$(ibmcloud cr images | grep ${SHIPPING_IMAGE_NAME} -m1 | awk '{print $2;}')
USER_IMAGE_TAG=$(ibmcloud cr images | grep ${USER_IMAGE_NAME} -m1 | awk '{print $2;}')
USER_DB_IMAGE_TAG=$(ibmcloud cr images | grep ${USER_DB_IMAGE_NAME} -m1 | awk '{print $2;}')

echo "=========================================================="
echo "Creating overwrite-values.yaml"
# FIRST LINE MUST HAVE > INSTEAD OF >> TO OVERWRITE WHATEVER MIGHT BE IN FILE
echo "registry: ${REGISTRY_URL}/${REGISTRY_NAMESPACE}" > overwrite-values.yaml
echo "cart:" >> overwrite-values.yaml
echo "  image: ${CART_IMAGE_NAME}" >> overwrite-values.yaml
echo "  tag: ${CART_IMAGE_TAG}" >> overwrite-values.yaml
echo "catalogue:" >> overwrite-values.yaml
echo "  image: ${CATALOGUE_IMAGE_NAME}" >> overwrite-values.yaml
echo "  tag: ${CATALOGUE_IMAGE_TAG}" >> overwrite-values.yaml
echo "cataloguedb:" >> overwrite-values.yaml
echo "  image: ${CATALOGUE_DB_IMAGE_NAME}" >> overwrite-values.yaml
echo "  tag: ${CATALOGUE_DB_IMAGE_TAG}" >> overwrite-values.yaml
echo "frontend:" >> overwrite-values.yaml
echo "  image: ${FRONT_END_IMAGE_NAME}" >> overwrite-values.yaml
echo "  tag: ${FRONT_END_IMAGE_TAG}" >> overwrite-values.yaml
echo "order:" >> overwrite-values.yaml
echo "  image: ${ORDER_IMAGE_NAME}" >> overwrite-values.yaml
echo "  tag: ${ORDER_IMAGE_TAG}" >> overwrite-values.yaml
echo "payment:" >> overwrite-values.yaml
echo "  image: ${PAYMENT_IMAGE_NAME}" >> overwrite-values.yaml
echo "  tag: ${PAYMENT_IMAGE_TAG}" >> overwrite-values.yaml
echo "queuemaster:" >> overwrite-values.yaml
echo "  image: ${QUEUE_MASTER_IMAGE_NAME}" >> overwrite-values.yaml
echo "  tag: ${QUEUE_MASTER_IMAGE_TAG}" >> overwrite-values.yaml
echo "shipping:" >> overwrite-values.yaml
echo "  image: ${SHIPPING_IMAGE_NAME}" >> overwrite-values.yaml
echo "  tag: ${SHIPPING_IMAGE_TAG}" >> overwrite-values.yaml
echo "user:" >> overwrite-values.yaml
echo "  image: ${USER_IMAGE_NAME}" >> overwrite-values.yaml
echo "  tag: ${USER_IMAGE_TAG}" >> overwrite-values.yaml
echo "userdb:" >> overwrite-values.yaml
echo "  image: ${USER_DB_IMAGE_NAME}" >> overwrite-values.yaml
echo "  tag: ${USER_DB_IMAGE_TAG}" >> overwrite-values.yaml
echo "ingress:" >> overwrite-values.yaml
echo "  host: ${INGRESS_HOST}" >> overwrite-values.yaml
echo "  subdomain: ${INGRESS_SUBDOMAIN}" >> overwrite-values.yaml
echo "appid:" >> overwrite-values.yaml
echo "  alias: ${APPID_ALIAS}" >> overwrite-values.yaml
# cat overwrite-values.yaml

echo "=========================================================="
echo "DEPLOYING HELM chart"
IMAGE_REPOSITORY=${REGISTRY_URL}/${REGISTRY_NAMESPACE}/${IMAGE_NAME}

# Using 'upgrade --install" for rolling updates. Note that subsequent updates will occur in the same namespace the release is currently deployed in, ignoring the explicit--namespace argument".
echo -e "Dry run into: ${CLUSTER_NAME}/${CLUSTER_NAMESPACE}."

helm upgrade --install --debug --dry-run ${RELEASE_NAME} ./sockstore/deploy/kubernetes/${CHART_NAME} -f overwrite-values.yaml --namespace ${CLUSTER_NAMESPACE} --set $newSlot.enabled=true --set $oldSlot.enabled=true --set productionSlot=$oldSlot --reuse-values

echo -e "Deploying into: ${CLUSTER_NAME}/${CLUSTER_NAMESPACE}."

# Read current value of productionSlot to deploy release in other slot
currentSlot=`(helm get values --all ${RELEASE_NAME} | grep -Po 'productionSlot: \K.*')`
if [ "$currentSlot" == "blue" ]; then
    newSlot="green"
    oldSlot="blue"
else
    newSlot="blue"
    oldSlot="green"
fi

echo "currentSlot: $currentSlot"
echo "newSlot: $newSlot"

# Launch new deployment in other slot
helm upgrade --install ${RELEASE_NAME} ./sockstore/deploy/kubernetes/${CHART_NAME} -f overwrite-values.yaml --namespace ${CLUSTER_NAMESPACE} --set $newSlot.enabled=true --reuse-values

kubectl get deploy --namespace ${CLUSTER_NAMESPACE}

# Checking carts
CARTS_READY=$(kubectl get deploy carts-$newSlot -o json --namespace ${CLUSTER_NAMESPACE} | jq '.status.conditions[] | select(.reason == "MinimumReplicasAvailable") | .status' | tr -d '"')
while [[ "$CARTS_READY" != "True" ]]; do
    CARTS_READY=$(kubectl get deploy carts-$newSlot -o json --namespace ${CLUSTER_NAMESPACE} | jq '.status.conditions[] | select(.reason == "MinimumReplicasAvailable") | .status' | tr -d '"')
    sleep 5
done
echo "Carts Ready: $CARTS_READY"

# Checking carts db
CARTS_DB_READY=$(kubectl get deploy carts-db-$newSlot -o json --namespace ${CLUSTER_NAMESPACE} | jq '.status.conditions[] | select(.reason == "MinimumReplicasAvailable") | .status' | tr -d '"')
while [[ "$CARTS_DB_READY" != "True" ]]; do
    CARTS_DB_READY=$(kubectl get deploy carts-db-$newSlot -o json --namespace ${CLUSTER_NAMESPACE} | jq '.status.conditions[] | select(.reason == "MinimumReplicasAvailable") | .status' | tr -d '"')
    sleep 5
done
echo "Carts DB Ready: $CARTS_DB_READY"

# Checking catalogue
CATALOGUE_READY=$(kubectl get deploy catalogue-$newSlot -o json --namespace ${CLUSTER_NAMESPACE} | jq '.status.conditions[] | select(.reason == "MinimumReplicasAvailable") | .status' | tr -d '"')
while [[ "$CATALOGUE_READY" != "True" ]]; do
    CATALOGUE_READY=$(kubectl get deploy catalogue-$newSlot -o json --namespace ${CLUSTER_NAMESPACE} | jq '.status.conditions[] | select(.reason == "MinimumReplicasAvailable") | .status' | tr -d '"')
    sleep 5
done
echo "Catalogue Ready: $CATALOGUE_READY"

# Checking catalogue db
CATALOGUE_DB_READY=$(kubectl get deploy catalogue-db-$newSlot -o json --namespace ${CLUSTER_NAMESPACE} | jq '.status.conditions[] | select(.reason == "MinimumReplicasAvailable") | .status' | tr -d '"')
while [[ "$CATALOGUE_DB_READY" != "True" ]]; do
    CATALOGUE_DB_READY=$(kubectl get deploy catalogue-db-$newSlot -o json --namespace ${CLUSTER_NAMESPACE} | jq '.status.conditions[] | select(.reason == "MinimumReplicasAvailable") | .status' | tr -d '"')
    sleep 5
done
echo "Catalogue DB Ready: $CATALOGUE_DB_READY"

# Checking front-end
FRONT_END_READY=$(kubectl get deploy front-end-$newSlot -o json --namespace ${CLUSTER_NAMESPACE} | jq '.status.conditions[] | select(.reason == "MinimumReplicasAvailable") | .status' | tr -d '"')
while [[ "$FRONT_END_READY" != "True" ]]; do
    FRONT_END_READY=$(kubectl get deploy front-end-$newSlot -o json --namespace ${CLUSTER_NAMESPACE} | jq '.status.conditions[] | select(.reason == "MinimumReplicasAvailable") | .status' | tr -d '"')
    sleep 5
done
echo "Front-End Ready: $FRONT_END_READY"

# Checking orders
ORDERS_READY=$(kubectl get deploy orders-$newSlot -o json --namespace ${CLUSTER_NAMESPACE} | jq '.status.conditions[] | select(.reason == "MinimumReplicasAvailable") | .status' | tr -d '"')
while [[ "$ORDERS_READY" != "True" ]]; do
    ORDERS_READY=$(kubectl get deploy orders-$newSlot -o json --namespace ${CLUSTER_NAMESPACE} | jq '.status.conditions[] | select(.reason == "MinimumReplicasAvailable") | .status' | tr -d '"')
    sleep 5
done
echo "Orders Ready: $ORDERS_READY"

# Checking orders db
ORDERS_DB_READY=$(kubectl get deploy orders-db-$newSlot -o json --namespace ${CLUSTER_NAMESPACE} | jq '.status.conditions[] | select(.reason == "MinimumReplicasAvailable") | .status' | tr -d '"')
while [[ "$ORDERS_DB_READY" != "True" ]]; do
    ORDERS_DB_READY=$(kubectl get deploy orders-db-$newSlot -o json --namespace ${CLUSTER_NAMESPACE} | jq '.status.conditions[] | select(.reason == "MinimumReplicasAvailable") | .status' | tr -d '"')
    sleep 5
done
echo "Orders DB Ready: $ORDERS_DB_READY"

# Checking payment
PAYMENT_READY=$(kubectl get deploy payment-$newSlot -o json --namespace ${CLUSTER_NAMESPACE} | jq '.status.conditions[] | select(.reason == "MinimumReplicasAvailable") | .status' | tr -d '"')
while [[ "$PAYMENT_READY" != "True" ]]; do
    PAYMENT_READY=$(kubectl get deploy payment-$newSlot -o json --namespace ${CLUSTER_NAMESPACE} | jq '.status.conditions[] | select(.reason == "MinimumReplicasAvailable") | .status' | tr -d '"')
    sleep 5
done
echo "Payment Ready: $PAYMENT_READY"

# Checking queue master
QUEUE_MASTER_READY=$(kubectl get deploy queue-master-$newSlot -o json --namespace ${CLUSTER_NAMESPACE} | jq '.status.conditions[] | select(.reason == "MinimumReplicasAvailable") | .status' | tr -d '"')
while [[ "$QUEUE_MASTER_READY" != "True" ]]; do
    QUEUE_MASTER_READY=$(kubectl get deploy queue-master-$newSlot -o json --namespace ${CLUSTER_NAMESPACE} | jq '.status.conditions[] | select(.reason == "MinimumReplicasAvailable") | .status' | tr -d '"')
    sleep 5
done
echo "Queue Master Ready: $QUEUE_MASTER_READY"

# Checking rabbitmq
RABBITMQ_READY=$(kubectl get deploy rabbitmq-$newSlot -o json --namespace ${CLUSTER_NAMESPACE} | jq '.status.conditions[] | select(.reason == "MinimumReplicasAvailable") | .status' | tr -d '"')
while [[ "$RABBITMQ_READY" != "True" ]]; do
    RABBITMQ_READY=$(kubectl get deploy rabbitmq-$newSlot -o json --namespace ${CLUSTER_NAMESPACE} | jq '.status.conditions[] | select(.reason == "MinimumReplicasAvailable") | .status' | tr -d '"')
    sleep 5
done
echo "RabbitMQ Ready: $RABBITMQ_READY"

# Checking session db
SESSION_DB_READY=$(kubectl get deploy session-db-$newSlot -o json --namespace ${CLUSTER_NAMESPACE} | jq '.status.conditions[] | select(.reason == "MinimumReplicasAvailable") | .status' | tr -d '"')
while [[ "$SESSION_DB_READY" != "True" ]]; do
    SESSION_DB_READY=$(kubectl get deploy session-db-$newSlot -o json --namespace ${CLUSTER_NAMESPACE} | jq '.status.conditions[] | select(.reason == "MinimumReplicasAvailable") | .status' | tr -d '"')
    sleep 5
done
echo "Session DB Ready: $SESSION_DB_READY"

# Checking shipping
SHIPPING_READY=$(kubectl get deploy shipping-$newSlot -o json --namespace ${CLUSTER_NAMESPACE} | jq '.status.conditions[] | select(.reason == "MinimumReplicasAvailable") | .status' | tr -d '"')
while [[ "$SHIPPING_READY" != "True" ]]; do
    SHIPPING_READY=$(kubectl get deploy shipping-$newSlot -o json --namespace ${CLUSTER_NAMESPACE} | jq '.status.conditions[] | select(.reason == "MinimumReplicasAvailable") | .status' | tr -d '"')
    sleep 5
done
echo "Shipping DB Ready: $SHIPPING_READY"

# Checking user
USER_READY=$(kubectl get deploy user-$newSlot -o json --namespace ${CLUSTER_NAMESPACE} | jq '.status.conditions[] | select(.reason == "MinimumReplicasAvailable") | .status' | tr -d '"')
while [[ "$USER_READY" != "True" ]]; do
    USER_READY=$(kubectl get deploy user-$newSlot -o json --namespace ${CLUSTER_NAMESPACE} | jq '.status.conditions[] | select(.reason == "MinimumReplicasAvailable") | .status' | tr -d '"')
    sleep 5
done
echo "User Ready: $USER_READY"

# Checking user db
USER_DB_READY=$(kubectl get deploy user-db-$newSlot -o json --namespace ${CLUSTER_NAMESPACE} | jq '.status.conditions[] | select(.reason == "MinimumReplicasAvailable") | .status' | tr -d '"')
while [[ "$USER_DB_READY" != "True" ]]; do
    USER_DB_READY=$(kubectl get deploy user-db-$newSlot -o json --namespace ${CLUSTER_NAMESPACE} | jq '.status.conditions[] | select(.reason == "MinimumReplicasAvailable") | .status' | tr -d '"')
    sleep 5
done
echo "User DB Ready: $USER_DB_READY"

# Promoting deployment to serve production traffic
helm upgrade --install ${RELEASE_NAME} ./sockstore/deploy/kubernetes/${CHART_NAME} -f overwrite-values.yaml --namespace ${CLUSTER_NAMESPACE} --set productionSlot=$newSlot --reuse-values

# Deleting deployment in old slot
helm upgrade --install ${RELEASE_NAME} ./sockstore/deploy/kubernetes/${CHART_NAME} -f overwrite-values.yaml --namespace ${CLUSTER_NAMESPACE} --set $oldSlot.enabled=false --reuse-values


echo "=========================================================="
echo "CHECKING OUTCOME"
echo ""
echo -e "Status for release:${RELEASE_NAME}"
helm status ${RELEASE_NAME}

echo ""
echo -e "History for release:${RELEASE_NAME}"
helm history ${RELEASE_NAME}

echo ""
echo -e "Releases in namespace: ${CLUSTER_NAMESPACE}"
helm list --namespace ${CLUSTER_NAMESPACE}

# echo ""
# echo "Deployed Services:"
# kubectl describe services ${RELEASE_NAME}-${CHART_NAME} --namespace ${CLUSTER_NAMESPACE}
# kubectl describe services --namespace ${CLUSTER_NAMESPACE}

echo ""
echo "Deployed Pods:"
kubectl describe pods --selector app=${CHART_NAME} --namespace ${CLUSTER_NAMESPACE}
