# **Pi5_App_Model_CD_pipeline**
Orchestration repo for deploying Edge AI app and model to Raspberry Pi using Self hosted runners

The Raspberry Pi used during the developement of this pipeline - Pi5/8GB

## **Project design**
The template comes with two workflows ; 

**1. Model_CD**

See Actions tab under the project Repo look for "Model_CD(Ship latest ONNX model stored at Github release to Pi)". The workflow is defined at .github/workflows/model_CD.yml

This workflow pulls the final .ONNX model from GitHub Releases, validates it, then ships it to the Pi 5 via a self-hosted runner.

So **to you use this template, the final model (.ONNX format) after model training and validation has to be made available to Github release** for deploying the model to Pi5.

Please read the readme file under Model_dev section for specific points to keep in mind when you are trianing your model.


**2.App CD**

See Actions tab under the project Repo look for "App CD • deploy Image from GHCR on Pi". The workflow is defined at .github/workflows/app_CD.yml.

This workflow deploys the multi-arch Docker image (amd64/arm64) of the App present in GHCR to the Pi5.

So **to you use this template, the final WebApplication along with ONNX runtime has to be build as a multi-arch Docker image (amd64/arm64) and pushed to GHCR** for deploying the App to Pi5.

Please read readme file under App_dev section for specific points to keep in mind when you are developing and testing your App.

### **One time set up in Raspberry Pi**

The prerequiste for the above two piplelines is to establish an active connection between our Github repo and the Raspberry Pi (where we deploy our App and Model). 

We use **self hosted runners** for this . Setting up a self-hosted runner provides you with the flexibility to run workflows on your own hardware.

Below given is the step by step approach we need to follow to set up self hosted runner in Raspberry Pi. 

1. Open the Github repo -> Settings -> Actions -> Runners -> New Self Hosted Runner -> Select Linux under Runner Image-> Select ARM64 from Architecture drop down. After this step , you will see the commands (to do in Pi). Keep this open for later reference.

2. Log in into Raspberry Pi, and open Terminal (use ssh from your local or RealVNC to connect to Pi5 )

3. Command "***mkdir /opt/edge/app_model_cd_runner***" in Pi - this creates a folder for runner in Pi . 

4. Command "***cd /opt/edge/app_model_cd_runner***" in Pi.

5. Download the latest runner package to the folder - to do this go back to the Github repo commands opened in Step 1.  Look for the command under # Download the latest runner package .
The command will look like ***"curl -o actions-runner-linux-arm64-2.328.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.328.0/actions-runner-linux-arm64-2.328.0.tar.gz"*** . Run that in Pi.

6. Optional: Validate the hash (command will look like echo "b801b9809c4d9301932bccadf57ca13533073b2aa9fa9b8e625a8db905b5d8eb  actions-runner-linux-arm64-2.328.0.tar.gz" | shasum -a 256 -c).

7. Extract the installer - After step 5, now you can see the runner package as a zip file under the folder /opt/edge/app_model_cd_runner. Unzip that using "***tar xzf ./actions-runner-linux-arm64-2.328.0.tar.gz***"

8. Create the runner and start the configuration . The command will look something like ***./config.sh --url https://github.com/<your github repo> --token XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX***. We will execute an extended version of this command as below;

    ***./config.sh --url https://github.com/<your github repo> --token XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX --name tonzz-pi --labels "pi5,app_model_cd" --unattended***

    where name can be set as per requirement. The labels ***pi5,app_model_cd*** has to be set the same way as these values will be used during workflow run in Github actions.