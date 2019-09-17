#********************************************
#!/bin/bash

echo "Build environment variables:"
echo "REGISTRY_URL=${REGISTRY_URL}"
echo "REGISTRY_NAMESPACE=${REGISTRY_NAMESPACE}"
echo "IMAGE_NAME=${IMAGE_NAME}"
echo "GIT_COMMIT=${GIT_COMMIT}"
echo "ARCHIVE_DIR=${ARCHIVE_DIR}"
# also run 'env' command to find all available env variables
# or learn more about the available environment variables at:
# https://console.bluemix.net/docs/services/ContinuousDelivery/pipeline_deploy_var.html#deliverypipeline_environment

echo "=========================================================="
echo "CHECKING DOCKERFILE"
echo "Checking Dockerfile at the repository root"
if [ -f Dockerfile ]; then
  echo "Dockerfile found"
else
    echo "Dockerfile not found"
    exit 1
fi

# echo "=========================================================="
# echo "CHECKING HELM CHART"
# echo "Looking for chart under /chart/<CHART_NAME>"
# if [ -d ./chart ]; then
#   CHART_NAME=$(find chart/. -maxdepth 2 -type d -name '[^.]?*' -printf %f -quit)
# fi
# if [ -z "${CHART_NAME}" ]; then
#     echo -e "No Helm chart found for Kubernetes deployment under /chart/<CHART_NAME>."
#     exit 1
# else
#     echo -e "Helm chart found for Kubernetes deployment : /chart/${CHART_NAME}"
# fi
# echo "Linting Helm Chart"
# helm lint ./chart/${CHART_NAME}

echo "=========================================================="
echo "CHECKING REGISTRY current plan and quota"
ibmcloud cr plan
ibmcloud cr quota
echo "If needed, discard older images using: ibmcloud cr image-rm"

echo "Current content of image registry"
ibmcloud cr images

echo "Checking registry namespace: ${REGISTRY_NAMESPACE}"
NS=$( ibmcloud cr namespaces | grep ${REGISTRY_NAMESPACE} ||: )
if [ -z "${NS}" ]; then
    echo "Registry namespace ${REGISTRY_NAMESPACE} not found, creating it."
    ibmcloud cr namespace-add ${REGISTRY_NAMESPACE}
    echo "Registry namespace ${REGISTRY_NAMESPACE} created."
else
    echo "Registry namespace ${REGISTRY_NAMESPACE} found."
fi
