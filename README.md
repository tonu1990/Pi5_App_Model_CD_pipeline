# **Pi5_App_Model_CD_pipeline**
Orchestration repo for deploying an Edge‑AI **model** and **application** to a Raspberry Pi using **GitHub Actions** with a **self‑hosted runner** on the Pi.

The reference device used while developing this pipeline: **Raspberry Pi 5 / 8GB**.

---

## **Project design**
This template provides **two deployment lanes** and a **one‑time runner setup**:

1) **Model Deployment lane – Model_CD** (ships your trained `.onnx` + metadata to the Pi)  
2) **Application Deployment lane – App_CD** (runs your app container on the Pi: **Web** or **GUI**)  
3) **Set up Self‑Hosted Runner** (one‑time on the Pi so GitHub Actions can target it)

For a quick visual, here’s the high‑level architecture:
## Architecture Overview

![CI/CD Pipeline Flowchart](readme_images/architecture.png)

### **1. Model Deployement lane - Model_CD**
See **Actions** in this repo → workflow **“Model CD - Deploy Model (.ONNX) and labels.json to Pi”** (defined at `.github/workflows/model_CD.yml`).

This workflow picks the final model (`.onnx`) and ships it to the Pi 5 via the self‑hosted runner.

While you use this template ensure the below:

**1. Model Availability**  
The final model after training and validation has to be made available to **GitHub Release** or **inside the repo (preferably at `/Model_dev/artifacts`)** for deploying the model to Pi5 (`.onnx` format preferred for Raspberry Pi). Optional to keep **label file (`.json`)** as well.

**2. Model directory in Pi**  
User can choose the Model directory in Pi where the model and artifacts will be stored. They will have to ensure they mount this directory at application runtime. The following model items will be present on Raspberry Pi:  
`<pi5_dir_location>/models`, `<pi5_dir_location>/manifests`, `<pi5_dir_location>/deployments.log`, `<pi5_dir_location>/current.onnx`, `<pi5_dir_location>/labels.json` (optional).

**What the workflow does (summary)**  
- Supports **two sources**: pull ONNX from a **GitHub Release** or pick it from the **repo** and upload to the `latest` release.  
- Computes **sha256** (model identity), writes a **manifest.json**, and uploads a bundle.  
- On the Pi: verifies checksum, **idempotency check**, free‑space check, versioned copy, **atomic symlink swap** (`current.onnx` → new, preserve `previous.onnx`), **retain last 10** models, and append to `deployments.log`.

---
## **Model directory layout on Pi (reference)**
```
/opt/edge/<project>/
├─ models/               # versioned .onnx files
├─ manifests/            # one manifest per deployed model
├─ tmp/                  # staging during deploy
├─ current.onnx -> models/<...>.onnx  # active model (symlink)
├─ previous.onnx -> models/<...>.onnx # previous model (symlink, if any)
├─ deployments.log
└─ labels.json           # optional

### **2. Application Deployment lane - App_CD**
This lane is for deploying the multi‑arch Docker image (**amd64/arm64**) of the App from **GHCR** to the Pi 5.  
So **to use this template, build your final Web/GUI application (with ONNX Runtime) as a multi‑arch Docker image and push it to GHCR**.

There are **two workflows** under this lane:

#### **2.1 GUI App CD – Launcher Script with Icons to Pi**
**Workflow:** `.github\workflows\app_CD_GUI.yml`

**Purpose**  
Install a **click‑to‑run launcher** and **desktop/menu icons** so non‑technical users can start the GUI container from the Raspberry Pi desktop.

**Inputs (typical)**  
- **image-name** (`ghcr.io/...`), **tag** (`latest`), **container-name** (also used as the menu/desktop label),  
- **model-mount-dir** (default `/opt/edge/<repo_name>`), **extra-args** (e.g., camera/GPU flags).

**What it installs**  
- `/usr/local/bin/<slug>.sh` – a launcher script that:  
  - auto‑detects `/dev/video*` (or uses `$CAM_DEVICE`),  
  - sets X11 env (`DISPLAY`, XDG dirs),  
  - can run the container **as the current user**,  
  - mounts the model base as **read‑only** at `/models`,  
  - sets `MODEL_DIR=/models`, `MODEL_PATH=/models/current.onnx`.
- System menu entry: `/usr/share/applications/<slug>.desktop` (icon appears in the desktop/menu).  
- Uninstall helper: `/usr/local/sbin/<slug>_uninstall.sh` + menu entry (uses `pkexec`).

**Runtime notes**  
- Requires access to X11 (`/tmp/.X11-unix`) and camera device (adds `--group-add video`).  
- You can override the host model directory at launch with env var `MODEL_MOUNT_DIR` if needed.

---

#### **2.2 Web App CD – Deploy Web App Image from GHCR to Pi5**
**Workflow:** `.github\workflows\app_CD_WEB.yml`

**Purpose**  
Run your web application container on the Pi and expose it on a chosen host port.

**Inputs (typical)**  
- **image-name**: Application image (e.g., `ghcr.io/<owner>/<app>`). If blank, uses repo variable `IMAGE_NAME`.  
- **tag**: Image tag (default `latest`).  
- **container-name**: Name for the container (blank → `.env: APP_NAME` → `pi_app`).  
- **host-port**: Port on the Pi (blank → `.env: HOST_PORT` → `8000`).  
- **model-mount-dir**: Model base dir on the Pi (blank → `/opt/edge/<repo_name>`).  
- **extra-args**: Extra `docker run` args (e.g., `--env KEY=VAL`).

**Behavior (summary)**  
1) Resolves parameters from inputs / repo variables / `.env`.  
2) Logs into **GHCR**, pulls the image, and removes any old container with the same name.  
3) Checks for **host‑port conflicts**.  
4) Verifies the **model base directory** and shows the `current.onnx` symlink if present.  
5) Runs the container with:  
   - `-p <HOST_PORT>:<APP_PORT>` (where `APP_PORT` comes from `.env` or defaults to **8080**)  
   - `-e MODEL_PATH="<MODEL_DIR>/current.onnx"`  
   - `-v <MODEL_DIR>:<MODEL_DIR>:ro` (read‑only mount)  
   - any `extra-args` you provide  
6) Verifies the container is **running**, performs a light **health check** (`/health` or `/`).  
7) Optionally **cleans up older images** and posts a **Deployment Summary**.

**App contract (expected)**  
Your app should read the model from the environment variable **`MODEL_PATH`**. Keep the container’s internal port (`APP_PORT`) stable or pass it via `.env`.

---

### **3. Set up Self Hosted Runner (one‑time)**
Both lanes run **on your Pi** via a GitHub **self‑hosted runner**—a small agent that lets Actions execute jobs on your own hardware.

**Steps (Pi 5, ARM64):**
1. In your GitHub repo: **Settings → Actions → Runners → New self‑hosted runner** → Image: **Linux**, Architecture: **ARM64**. Keep the generated commands open.  
2. On the Pi (SSH or local Terminal):  
   ```bash
   sudo mkdir -p /opt/edge/app_model_cd_runner
   cd /opt/edge/app_model_cd_runner
   # Download the ARM64 runner (version from step 1)
   curl -o actions-runner-linux-arm64-<ver>.tar.gz -L https://github.com/actions/runner/releases/download/v<ver>/actions-runner-linux-arm64-<ver>.tar.gz
   # (Optional) Validate checksum
   echo "<sha256>  actions-runner-linux-arm64-<ver>.tar.gz" | shasum -a 256 -c
   tar xzf actions-runner-linux-arm64-<ver>.tar.gz
   # Configure (use your repo URL + token + labels)
   ./config.sh --url https://github.com/<owner>/<repo> --token <REG_TOKEN> --name <runner_name> --labels "pi5,app_model_cd" --unattended
   # Install as a service
   sudo ./svc.sh install
   sudo ./svc.sh start
   sudo ./svc.sh status
   ```
3. Verify in **Settings → Actions → Runners** that your runner is **Idle** and labeled `pi5, app_model_cd`.  
4. (Recommended) Auto‑start on boot:  
   ```bash
   # Find the service name at /etc/systemd/system, then enable:
   sudo systemctl enable actions.runner.<owner>-<repo>.<runner_name>.service
   ```
**Useful commands**
```bash
# Stop / uninstall the service
sudo ./svc.sh stop
sudo ./svc.sh uninstall

# Remove configuration
./config.sh remove

# Ensure the runner user can use Docker without sudo
sudo usermod -aG docker $USER && newgrp docker
docker info
```

## **Quick start**
1) **Runner**: complete the self‑hosted runner setup (labels: `pi5, app_model_cd`).  
2) **Model**: publish your `.onnx` (Release or repo path).  
3) **Deploy model**: run **Model_CD** → confirms `current.onnx` on the Pi.  
4) **Deploy app**: run **Web App CD** (or **GUI App CD**) → container starts and reads `MODEL_PATH=/models/current.onnx`.  
5) **Use it**: open `http://<pi-hostname>:<HOST_PORT>` (Web) or click the desktop icon (GUI).

---

