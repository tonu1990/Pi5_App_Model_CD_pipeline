# **Pi5_App_Model_CD_pipeline**
Orchestration repo for deploying Edge AI app and model to Raspberry Pi using Self hosted runners

## **Project design**
The template comes with two workflows ; 

**1. Model_CD**

See Actions tab under the project Repo look for "Model_CD(Ship latest ONNX model stored at Github release to Pi)". The workflow is defined at .github/workflows/model_CD.yml

This workflow pulls the final ONNX from GitHub Releases, validates it, then ships it to the Pi 5 via a self-hosted runner.

So **when you use this template, after model training and validation the final model (.ONNX format) has to be made available to Github release** for deploying the model to Pi5.

Please read readme file under Model_dev section for specific points to keep in mind when you are trianing your model.


**2.App CD**

See Actions tab under the project Repo look for "App CD • deploy Image from GHCR on Pi". The workflow is defined at .github/workflows/app_CD.yml.

This workflow deploys the multi-arch Docker image (amd64/arm64) of the App present in GHCR to the Pi5.

So **when you use this template, after Web Application developement and testing the final model along with ONNX runtime has to be builds as a multi-arch Docker image (amd64/arm64) and pushed to GHCR** for deploying the App to Pi5.

Please read readme file under App_dev section for specific points to keep in mind when you are developing and testing your App.