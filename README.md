# IBM Continuous Delivery Example scripts

Here is the documentation for setting up a Delivery pipeline using the [IBM Cloud Continuous Delivery Service.](https://cloud.ibm.com/docs/services/ContinuousDelivery?topic=ContinuousDelivery-deliverypipeline_about)

### Helpful Resources & Tutorials

[Tutorial](https://www.ibm.com/cloud/garage/tutorials/tutorial_gm_advocate_otc) - Walks through how to use an open toolchain template to create a Node.js "Hello World" app. The toolchain includes all of the tools that you need to code, build, deploy, and collaborate on the app on IBM Cloud.

[Open Toolchain Github](https://github.com/open-toolchain) - Here you can find many examples of Continuous Delivery configuartion files. 

[Blockchain Starter Kit](https://github.com/sstone1/blockchain-starter-kit/tree/master/.bluemix) - Here you can find an example of the IBM toolchain & delivery pipeline configuration files for building and deploying a blockchain application. 

### Build Examples
- **otc-prebuild.sh**  This bash script checks to make sure there is a Dockerfile where you've specified and that the IBM Container Registry location you've provided has space for a new image to be pushed there.
- **otc-build.sh**  This bash script builds an image based on the given Dockerfile and pushes it to the IBM container registry location provided by [environment variables](https://cloud.ibm.com/docs/services/ContinuousDelivery?topic=ContinuousDelivery-deliverypipeline_environment).
- **otc-vulnerability-scan.sh**  This bash script checks to make sure the new image you've built and pushed has passed IBM's Vulnerability Scans.
- **fa-build.sh** This bash script is basically the otc-prebuild.sh and otc-build.sh put together. One difference is that this file uses a Timestamp in order to uniquely tag the image being built, instead of the Git Commit number. This script also creates a build.properties file that is used to pass information between pipeline stages. 
- **fa-va.sh** This bash script checks to make sure the new image you've built and pushed has passed IBM's Vulnerability Scans. It's almost identical to otc-vulnerability-scan.sh.

### Deploy Example
- **predeploy.sh**  This bash script checks to make sure the environment has the correct packages and Helm chart in place to successfully deploy your application. It checks that the IBM kubernetes cluster and namespace that have been specified actually exist.  It also checks for AppID readiness and existence, as well as configuring Tiller.
- **simple-deploy.sh**  This bash script configures the ibm cloud and cluster setup, sources environment variables, checks cluster and AppID readiness, and basically redoes some of the things listed in predeploy.  Next, it creates an overwrite-values.yaml file given the [environment variables](https://cloud.ibm.com/docs/services/ContinuousDelivery?topic=ContinuousDelivery-deliverypipeline_environment) that were sourced and will be used to overwrite some values in the helm chart.  
- **bluegreen-deploy.sh**  This bash script does the same thing as the simple deploy, but ALSO utilizes the blue green deployment strategy. 
- **fa-predeploy.sh** This bash script is similar to predeploy.sh, it does a bunch of environment checks. It makes sure the Helm chart and cluster are in place, if Helm & Tiller are properly set up with the correct versions, and makes sure there is access to the image registry. 
- **fa-deploy.sh** This bash script does many, but not all of the same checks that happen in fa-predeploy.sh and also actually runs the Helm deploy commands.  
