# **Pi5_App_Model_CD_pipeline**
Orchestration repo for deploying Edge AI app and model to Raspberry Pi using **Self hosted runners**

The Raspberry Pi used during the developement of this pipeline - Pi5/8GB

## **Project design**
The template comes with three workflows belonging to two Deployement lanes; 

### **1. Model Deployement lane - Model_CD**

See Actions tab under the project Repo - look for workflow **"Model CD - Deploy Model (.ONNX) and labels.json to Pi"**. The workflow is defined at .github/workflows/model_CD.yml.

This workflow picks the final model(.ONNX),then ships it to the Pi 5 via a self-hosted runner.

While you use this template ensure the below ;

 **1.Model Availability** :  
    The final model after training and validation has to be made available to **Github release** or **inside the repo (preferably at /Model_dev/artifacts)** for deploying the model to Pi5 (.ONNX format preferred for Raspberry Pi). Optional to keep **label file (.json format)** also.

 **2.Model directory in Pi** : 
 User can choose the Model directory in Pi where the model and arifacts will be stored. They will have to ensure they mount this directory in Application running time. The following Model directories will be in Raspberry Pi <pi5_dir_location>/models ,<pi5_dir_location>/manifests, <pi5_dir_location>/deployements.log, <pi5_dir_location>/current.onnx, <pi5_dir_location>/labels.json (optional).

 
### **2.Application Deployment lane - App_CD**

This lane is for deploying the multi-arch Docker image (amd64/arm64) of the App present in GHCR to the Pi5.

So **to you use this template, the final WebApplication along with ONNX runtime has to be build as a multi-arch Docker image (amd64/arm64) and pushed to GHCR** for deploying the App to Pi5.

 

### **3.Set up Self Hosted Runner**
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

8. Create the runner and start the configuration . The command will look something like ***./config.sh --url https://github.com/your-github-repo --token XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX***. We will execute an extended version of this command as below;

    ***./config.sh --url https://github.com/your-github-repo --token XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX --name <runner_name> --labels "pi5,app_model_cd" --unattended***

    where name can be set as per requirement. The labels ***pi5,app_model_cd*** has to be set the same way as these values will be used during workflow run in Github actions.

    Example : ***./config.sh --url https://github.com/tonu1990/Pi5_App_Model_CD_pipeline --token AN2Q6IQWYOX7ITMWWOSF6C3IX6U6Q  --name tonzz-pi --labels "pi5,app_model_cd" --unattended***

9. Run the self hosted runner . There are two ways to do it . ***./run.sh*** as shown in Github repo steps. This will start the runner procees in the foreground. But we need to run the process in background, and for our use case we wil prefer that approach . For that execute below commands

     ***sudo ./svc.sh install***

     ***sudo ./svc.sh start***

     ***sudo ./svc.sh status***

10. After this step check the runners section in Github repo (Open the Github repo -> Settings -> Actions -> Runners) you can see the runner we created (with status Idle).

11. One potential issue we might come across here is in case the Pi is turned off and On again, the connection between the Github runner and our pi will get lost. You will see our runner with status "Offline" in Repo. We can restart the runner everytime you turn on pi - do ***sudo ./svc.sh start***. 

    If you wish to avoid this mannual restart every time, you can do step 12 , which will help to start the runner automatically at boot.

12. Recommended additional step :  auto-start on boot of Pi. 

    Find the service name for the runner - check the folder /etc/systemd/system and findout the service of our runner . The file name will look something like ***actions.runner.<github_repo>.<runner_name>.service***

    Enable that service as with below command ;

    ***sudo systemctl enable <your_service_name>***

    Example : ***systemctl enable actions.runner.tonu1990-Pi5_App_Model_CD_pipeline.tonzz-pi.service***


13. Additional useful commands :

    a. ***systemctl is-enabled <your_service_name>***

        To check if auto start is enabled

    b. ***sudo systemctl disable <your_service_name>***

        To disable auto start.

    c. ***sudo ./svc.sh stop***

        To stop the self host runner set up in step 9

    d. ***sudo ./svc.sh uninstall***

        To uninstall host runner set up in step 9

    e. ***./config.sh remove***

        To remove configurations set in step 8. You will have to give the token used for setup


![CI/CD Pipeline Flowchart](readme_images/architecture.png)
![CI/CD Pipeline Flowchart](readme_images\architecture.png)