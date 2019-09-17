#!/bin/bash
set -x
echo -e "Test environment variables:"
echo "REGISTRY_URL=${REGISTRY_URL}"
echo "REGISTRY_NAMESPACE=${REGISTRY_NAMESPACE}"
echo "IMAGE_NAME=${IMAGE_NAME}"
echo "IMAGE_TAG=${IMAGE_TAG}"

# default value for PIPELINE_IMAGE_URL -- uncomment and customize as needed
# export PIPELINE_IMAGE_URL="$REGISTRY_URL/$REGISTRY_NAMESPACE/$IMAGE_NAME:$IMAGE_TAG"
echo "PIPELINE_IMAGE_URL=${PIPELINE_IMAGE_URL}"

# Learn more about the available environment variables at:
# https://console.bluemix.net/docs/services/ContinuousDelivery/pipeline_deploy_var.html#deliverypipeline_environment


for iteration in {1..6}
do
  [[ $(ibmcloud cr va $PIPELINE_IMAGE_URL) == *No\ vulnerability\ scan* ]] || break
  echo -e "A vulnerability report was not found for the specified image, either the image doesn't exist or the scan hasn't completed yet. Waiting for scan to complete.."
  sleep 30
done

#set +e
#ibmcloud cr va $PIPELINE_IMAGE_URL
#set -e
[[ $(ibmcloud cr va $PIPELINE_IMAGE_URL) == *NO\ ISSUES* ]] || { echo "ERROR: The vulnerability scan was not successful, check the output of the command and try again."; exit 1; }
