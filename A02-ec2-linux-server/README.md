# Project 2: Hardened Linux Server Setup on AWS EC2

This project is a comprehensive guide to launching, configuring, securing, and automating a Linux web server on AWS EC2. It follows a progressive roadmap to build a deep, production-grade understanding of AWS infrastructure, Linux administration, and DevOps automation.

---

## The Roadmap

1. **Phase 0: Local Verification**: Verify the application works locally in a Python virtual environment before deploying to AWS.

---

## Project Structure

```text
A02-ec2-linux-server/
├── app.py            # Flask web application (Port 8080)
├── requirements.txt  # Python dependencies (Flask, Werkzeug)
└── README.md         # This practice guide
```

---

## Phase 0: Local Verification

Before launching resources on AWS, test the Flask application locally to ensure it runs correctly and returns fallback values when outside the EC2 environment.

### Step 1: Open Terminal and Navigate
Open your terminal and navigate to the project directory:
```bash
cd D:/Projects/Cloud-Engineering/A02-ec2-linux-server
```

### Step 2: Create a Virtual Environment
Initialize a local isolated Python environment:
```bash
python -m venv venv
```

### Step 3: Activate the Virtual Environment
Activate the environment depending on your operating system:
* **Windows (PowerShell)**:
  ```powershell
  .\venv\Scripts\Activate.ps1
  ```
* **Windows (CMD)**:
  ```cmd
  .\venv\Scripts\activate.bat
  ```
* **macOS / Linux**:
  ```bash
  source venv/bin/activate
  ```

### Step 4: Install Dependencies
Install the required packages pinned in `requirements.txt`:
```bash
pip install -r requirements.txt
```

### Step 5: Start the Application
Run the Flask server:
```bash
python app.py
```

### Step 6: Verify in Browser & API Endpoints
1. Open your browser and go to `http://127.0.0.1:8080`.
2. Confirm the page displays:
   * **Server Status**: `HEALTHY` (green badge)
   * **Server Name**: `dev-instance-<your-hostname>`
   * **Server IP**: Local IP address (fallback)
   * **Security Group**: `local-development-sg`
   * **Engine Mode**: `Local / Fallback Mode` (colored badge)
3. Check the API Endpoints:
   * **Health**: Open `http://127.0.0.1:8080/health` -> Expect `{"status": "healthy"}`
   * **Metrics**: Open `http://127.0.0.1:8080/metrics` -> Expect JSON payload containing timestamp, status: `running`, and your local hostname.

Press `Ctrl+C` in your terminal to stop the server once verification is complete.

---