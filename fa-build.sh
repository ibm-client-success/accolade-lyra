#!/bin/bash
echo "Build environment variables:"
echo "REGISTRY_URL=${REGISTRY_URL}"
echo "REGISTRY_NAMESPACE=${REGISTRY_NAMESPACE}"
echo "IMAGE_NAME=${IMAGE_NAME}"
echo "GIT_COMMIT=${GIT_COMMIT}"
echo "ARCHIVE_DIR=${ARCHIVE_DIR}"
echo "GIT_BRANCH=${GIT_BRANCH}"
echo "BUILD_NUMBER=${BUILD_NUMBER}"

# View build properties
if [ -f build.properties ]; then
    echo "build.properties:"
    cat build.properties
else
    echo "build.properties : not found"
fi
# Learn more about the available environment variables at:
# https://console.bluemix.net/docs/services/ContinuousDelivery/pipeline_deploy_var.html#deliverypipeline_environment

# To review or change build options use:
# bx cr build --help

echo "=========================================================="
echo "CHECKING DOCKERFILE"
echo "Checking Dockerfile at the repository root"
if [ -f Dockerfile ]; then
  echo "Dockerfile found"
else
    echo "Dockerfile not found"
    exit 1
fi

# echo "Linting Dockerfile"
# npm install -g dockerlint
# dockerlint -f Dockerfile

echo "=========================================================="
echo "CHECKING REGISTRY current plan and quota"
ibmcloud cr plan
ibmcloud cr quota
echo "If needed, discard older images using: ibmcloud cr image-rm"

echo "Current contents of image registry"
ibmcloud cr images --restrict ${REGISTRY_NAMESPACE}

echo "Checking registry namespace: ${REGISTRY_NAMESPACE}"
NS=$( ibmcloud cr namespaces | grep ${REGISTRY_NAMESPACE} ||: )
if [ -z "${NS}" ]; then
    echo "Registry namespace ${REGISTRY_NAMESPACE} not found, creating it."
    ibmcloud cr namespace-add ${REGISTRY_NAMESPACE}
    echo "Registry namespace ${REGISTRY_NAMESPACE} created."
else
    echo "Registry namespace ${REGISTRY_NAMESPACE} found."
fi

echo -e "Existing images in registry"
ibmcloud cr images --restrict ${REGISTRY_NAMESPACE}

# Minting image tag using format: BUILD_NUMBER--BRANCH-COMMIT_ID-TIMESTAMP
# e.g. 3-master-50da6912-20181123114435
# (use build number as first segment to allow image tag as a patch release name according to semantic versioning)
TIMESTAMP=$( date -u "+%Y%m%d%H%M%S")
IMAGE_TAG=${TIMESTAMP}
if [ ! -z "${GIT_COMMIT}" ]; then
GIT_COMMIT_SHORT=$( echo ${GIT_COMMIT} | head -c 8 )
IMAGE_TAG=${GIT_COMMIT_SHORT}-${IMAGE_TAG}
fi
if [ ! -z "${GIT_BRANCH}" ]; then IMAGE_TAG=${GIT_BRANCH}-${IMAGE_TAG} ; fi
IMAGE_TAG=${BUILD_NUMBER}-${IMAGE_TAG}

echo "=========================================================="
echo -e "BUILDING CONTAINER IMAGE: ${IMAGE_NAME}:${IMAGE_TAG}"

set -x
ibmcloud cr build -t ${REGISTRY_URL}/${REGISTRY_NAMESPACE}/${IMAGE_NAME}:${IMAGE_TAG} .
set +x
ibmcloud cr image-inspect ${REGISTRY_URL}/${REGISTRY_NAMESPACE}/${IMAGE_NAME}:${IMAGE_TAG}

# Set PIPELINE_IMAGE_URL for subsequent jobs in stage (e.g. Vulnerability Advisor)
export PIPELINE_IMAGE_URL="$REGISTRY_URL/$REGISTRY_NAMESPACE/$IMAGE_NAME:$IMAGE_TAG"

ibmcloud cr images --restrict ${REGISTRY_NAMESPACE}/${IMAGE_NAME}

######################################################################################
# Copy any artifacts that will be needed for deployment and testing to $WORKSPACE    #
######################################################################################
echo "=========================================================="
echo "COPYING ARTIFACTS needed for deployment and testing (in particular build.properties)"

echo "Checking archive dir presence"
if [ -z "${ARCHIVE_DIR}" ]; then
    echo -e "Build archive directory contains entire working directory."
else
    echo -e "Copying working dir into build archive directory: ${ARCHIVE_DIR} "
    mkdir -p ${ARCHIVE_DIR}
    find . -mindepth 1 -maxdepth 1 -not -path "./$ARCHIVE_DIR" -exec cp -R '{}' "${ARCHIVE_DIR}/" ';'
fi

# Persist env variables into a properties file (build.properties) so that all pipeline stages consuming this
# build as input and configured with an environment properties file valued 'build.properties'
# will be able to reuse the env variables in their job shell scripts.
# If already defined build.properties from prior build job, append to it.
cp build.properties $ARCHIVE_DIR/ || :

# IMAGE information from build.properties is used in Helm Chart deployment to set the release name
echo "IMAGE_NAME=${IMAGE_NAME}" >> $ARCHIVE_DIR/build.properties
echo "IMAGE_TAG=${IMAGE_TAG}" >> $ARCHIVE_DIR/build.properties

# REGISTRY information from build.properties is used in Helm Chart deployment to generate cluster secret
echo "REGISTRY_URL=${REGISTRY_URL}" >> $ARCHIVE_DIR/build.properties
echo "REGISTRY_NAMESPACE=${REGISTRY_NAMESPACE}" >> $ARCHIVE_DIR/build.properties
echo "GIT_BRANCH=${GIT_BRANCH}" >> $ARCHIVE_DIR/build.properties
echo "File 'build.properties' created for passing env variables to subsequent pipeline jobs:"
cat $ARCHIVE_DIR/build.properties

# echo "Copy pipeline scripts along with the build"
# # Copy scripts (incl. deploy scripts)
# if [ -d ./ci-cd-scripts/ ]; then
#   if [ ! -d $ARCHIVE_DIR/scripts/ ]; then # no need to copy if working in ./ already
#     cp -r ./ci-cd-scripts/ $ARCHIVE_DIR/
#   fi
# fi


#list contents of archive dir
set -x
cd $ARCHIVE_DIR
ls
