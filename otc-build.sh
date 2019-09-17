#!/bin/bash
set -x
echo "Build environment variables:"
echo "REGISTRY_URL=${REGISTRY_URL}"
echo "REGISTRY_NAMESPACE=${REGISTRY_NAMESPACE}"
echo "IMAGE_NAME=${IMAGE_NAME}"
echo "GIT_COMMIT=${GIT_COMMIT}"
# echo "ARCHIVE_DIR=${ARCHIVE_DIR}"
# also run 'env' command to find all available env variables
# or learn more about the available environment variables at:
# https://console.bluemix.net/docs/services/ContinuousDelivery/pipeline_deploy_var.html#deliverypipeline_environment

# To review or change build options use:
# ibmcloud cr build --help

echo -e "Existing images in registry"
ibmcloud cr images

echo "=========================================================="
echo -e "BUILDING CONTAINER IMAGE: ${IMAGE_NAME}:${GIT_COMMIT}"
set -x
ibmcloud cr build --no-cache -t ${REGISTRY_URL}/${REGISTRY_NAMESPACE}/${IMAGE_NAME}:${GIT_COMMIT} .
set +x
ibmcloud cr image-inspect ${REGISTRY_URL}/${REGISTRY_NAMESPACE}/${IMAGE_NAME}:${GIT_COMMIT}

# When 'ibmcloud' commands are in the pipeline job config directly, the image URL will automatically be passed
# along with the build result as env variable PIPELINE_IMAGE_URL to any subsequent job consuming this build result.
# When the job is sourc'ing an external shell script, or to pass a different image URL than the one inferred by the pipeline,
# please uncomment and modify the environment variable the following line.
export PIPELINE_IMAGE_URL="$REGISTRY_URL/$REGISTRY_NAMESPACE/$IMAGE_NAME:$GIT_COMMIT"
echo "TODO - remove once no longer needed to unlock VA job ^^^^"

ibmcloud cr images

echo "=========================================================="
# echo "COPYING ARTIFACTS needed for deployment and testing (in particular build.properties)"
#
# echo "Checking archive dir presence"
# mkdir -p $ARCHIVE_DIR

# Persist env variables into a properties file (build.properties) so that all pipeline stages consuming this
# build as input and configured with an environment properties file valued 'build.properties'
# will be able to reuse the env variables in their job shell scripts.

# CHART information from build.properties is used in Helm Chart deployment to set the release name
# CHART_NAME=$(find chart/. -maxdepth 2 -type d -name '[^.]?*' -printf %f -quit)
# echo "CHART_NAME=${CHART_NAME}" >> $ARCHIVE_DIR/build.properties

# IMAGE information from build.properties is used in Helm Chart deployment to set the release name
# echo "IMAGE_NAME=${IMAGE_NAME}" >> $ARCHIVE_DIR/build.properties
# echo "GIT_COMMIT=${GIT_COMMIT}" >> $ARCHIVE_DIR/build.properties

# REGISTRY information from build.properties is used in Helm Chart deployment to generate cluster secret
# echo "REGISTRY_URL=${REGISTRY_URL}" >> $ARCHIVE_DIR/build.properties
# echo "REGISTRY_NAMESPACE=${REGISTRY_NAMESPACE}" >> $ARCHIVE_DIR/build.properties
# echo "File 'build.properties' created for passing env variables to subsequent pipeline jobs:"
# cat $ARCHIVE_DIR/build.properties
#
# echo "Copy pipeline scripts along with the build"
# # Copy scripts (incl. deploy scripts)
# if [ -d ./scripts/ ]; then
#   if [ ! -d $ARCHIVE_DIR/scripts/ ]; then # no need to copy if working in ./ already
#     cp -r ./scripts/ $ARCHIVE_DIR/
#   fi
# fi

# echo "Copy Helm chart along with the build"
# if [ ! -d $ARCHIVE_DIR/chart/ ]; then # no need to copy if working in ./ already
#   cp -r ./chart/ $ARCHIVE_DIR/
# fi
