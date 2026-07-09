# Project 2: Hardened Linux Server Setup on AWS EC2

This project is a comprehensive guide to launching, configuring, securing, and automating a Linux web server on AWS EC2. It follows a progressive roadmap to build a deep, production-grade understanding of AWS infrastructure, Linux administration, and DevOps automation.

---

## The Roadmap

1. **Phase 0: Local Verification**: Verify the application works locally in a Python virtual environment before deploying to AWS. (Completed)
2. **Phase 1: Manual Deep Dive**: Provision security groups, IAM roles, and key pairs manually, launch an EC2 instance, SSH in, configure Nginx, and launch the Flask app. (Completed)

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

## Phase 1: Manual Deep Dive

We will manually configure a hardened Ubuntu server in the AWS console to establish a baseline.

### Custom VPC & Networking Setup (For Accounts Without a Default VPC)
If your AWS account does not have a default VPC, you must manually create the networking infrastructure to allow public internet traffic:
1. **Create VPC**:
   * Navigate to the **VPC Dashboard** -> **Create VPC**.
   * Name: `project2-vpc`
   * IPv4 CIDR block: `10.0.0.0/16`
2. **Create Subnet**:
   * Under **Subnets**, click **Create subnet**.
   * Select your `project2-vpc`.
   * Subnet name: `project2-public-subnet`
   * IPv4 CIDR block: `10.0.1.0/24`
3. **Create & Attach Internet Gateway (IGW)**:
   * Under **Internet Gateways**, click **Create internet gateway** (name: `project2-igw`).
   * Select the new gateway -> **Actions** -> **Attach to VPC** -> Choose `project2-vpc`.
4. **Configure Route Table**:
   * Go to **Route Tables** and select the route table associated with your VPC.
   * Go to the **Routes** tab -> **Edit routes**.
   * Add a route: Destination `0.0.0.0/0` -> Target **Internet Gateway** -> Select `project2-igw`.
   * Go to **Subnet Associations** -> **Edit subnet associations** -> Select `project2-public-subnet` to link it.

### Step 1: Create Security Group
1. Navigate to the **EC2 Dashboard** -> **Security Groups** -> **Create security group**.
2. Configure the details:
   * **Security group name**: `project2-web-server-sg`
   * **Description**: `Security group for Project 2 EC2 web server`
   * **VPC**: Select your VPC (default or `project2-vpc`)
3. Add **Inbound rules**:
   * **Rule 1**: SSH | Port 22 | Source: **My IP** (Hardens access to only your public IP)
   * **Rule 2**: HTTP | Port 80 | Source: **Anywhere-IPv4** (`0.0.0.0/0`)
   * **Rule 3**: HTTPS | Port 443 | Source: **Anywhere-IPv4** (`0.0.0.0/0`)
4. Click **Create security group**.

> [!NOTE]
> **Security Note on EC2 Instance Connect**:
> By restricting SSH (Port 22) inbound rules strictly to **My IP**, you will NOT be able to connect using the browser-based **EC2 Instance Connect** button in the AWS Console. This is because AWS Console Connect attempts to SSH into the instance from AWS's own service IP addresses. Direct SSH from your terminal using the `.pem` key works perfectly because the request originates from your personal IP address. This is a design feature proving your firewall rules are active!

### Step 2: Create IAM Role for EC2
1. Open the **IAM Dashboard** -> **Roles** -> **Create role**.
2. Select **AWS service** -> **EC2** as the trusted entity. Click **Next**.
3. Attach the following managed policies:
   * `CloudWatchAgentServerPolicy` (Allows sending server metrics to CloudWatch)
   * `AmazonSSMManagedInstanceCore` (Allows secure browser-based Session Manager access)
4. Name the role `Project2-EC2-Role` and click **Create role**.

### Step 3: Create EC2 Key Pair
1. In the **EC2 Dashboard**, navigate to **Key Pairs** -> **Create key pair**.
2. Configure:
   * **Name**: `project2-key`
   * **Key pair type**: RSA
   * **Private key file format**: `.pem`
3. Click **Create key pair**. Move the downloaded `project2-key.pem` to your working directory.

### Step 4: Launch the EC2 Instance
1. In the **EC2 Dashboard**, click **Launch instances**.
2. Configure settings:
   * **Name**: `Project2-Web-Server`
   * **AMI**: Ubuntu Server 22.04 LTS (HVM)
   * **Instance type**: `t2.micro`
   * **Key pair**: Select `project2-key`
   * **Network settings**: Select existing security group `project2-web-server-sg` and ensure public IP assignment is enabled.
3. Expand **Advanced details**:
   * **IAM instance profile**: Select `Project2-EC2-Role`
4. Click **Launch instance**.

### Step 5: Transfer App Files to the Instance
1. Get the public IP of your instance from the EC2 console.
2. Secure the key permissions to prevent the SSH "permissions are too open" error:
   * **Linux/macOS/WSL/Git Bash**:
     ```bash
     chmod 400 project2-key.pem
     ```
   * **Windows (PowerShell)**:
     ```powershell
     icacls.exe .\project2-key.pem /reset
     icacls.exe .\project2-key.pem /grant:r "$($env:username):(R)"
     icacls.exe .\project2-key.pem /inheritance:r
     ```
   * **Windows (GUI)**:
     1. Right-click `project2-key.pem` -> **Properties** -> **Security** -> **Advanced**.
     2. Click **Disable inheritance** and choose "Remove all inherited permissions".
     3. Click **Add** -> **Select a principal** -> type your user account -> **OK**.
     4. Check only **Read** permission -> **OK** -> **Apply** -> **OK**.
3. Transfer `app.py` and `requirements.txt` to the server using `scp`:
   ```bash
   scp -i project2-key.pem app.py requirements.txt ubuntu@<PUBLIC_IP>:/home/ubuntu/
   ```

### Step 6: Connect and Set Up the Server Manually
1. SSH into the instance:
   ```bash
   ssh -i project2-key.pem ubuntu@<PUBLIC_IP>
   ```
2. Update the system packages:
   ```bash
   sudo apt update -y && sudo apt upgrade -y
   ```
3. Install Python 3, pip, venv, and Nginx:
   ```bash
   sudo apt install -y python3 python3-pip python3-venv nginx
   ```
4. Create a virtual environment and install dependencies:
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   pip install gunicorn
   ```
5. Test running the Flask app locally:
   ```bash
   python3 app.py
   # Press Ctrl+C once verified it starts up successfully on port 8080.
   ```

### Step 7: Configure Flask as a systemd Service
1. Create a systemd service file:
   ```bash
   sudo nano /etc/systemd/system/flask-app.service
   ```
2. Paste the following configuration:
   ```ini
   [Unit]
   Description=Gunicorn instance to serve Flask Web App
   After=network.target

   [Service]
   User=ubuntu
   WorkingDirectory=/home/ubuntu
   ExecStart=/home/ubuntu/venv/bin/gunicorn --workers 3 --bind 127.0.0.1:8080 app:app
   Restart=always

   [Install]
   WantedBy=multi-user.target
   ```
3. Start and enable the service:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl start flask-app
   sudo systemctl enable flask-app
   ```

### Step 8: Configure Nginx as a Reverse Proxy
1. Edit the default Nginx configuration:
   ```bash
   sudo nano /etc/nginx/sites-available/default
   ```
2. Replace the contents of the `server { ... }` block to proxy requests to localhost:8080:
   ```nginx
   server {
       listen 80 default_server;
       listen [::]:80 default_server;
       server_name _;

       location / {
           proxy_pass http://127.0.0.1:8080;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
           proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
           proxy_set_header X-Forwarded-Proto $scheme;
       }
   }
   ```
3. Test and restart Nginx:
   ```bash
   sudo nginx -t
   sudo systemctl restart nginx
   ```

### Step 9: Verify Configuration
1. Open a browser and visit `http://<PUBLIC_IP>`.
2. Confirm the dashboard loads with **HEALTHY** status, showing the host name and IP.
3. Test the health check endpoint: `curl http://localhost/health`.
4. Test the metrics endpoint: `curl http://localhost/metrics`.

### Step 10: Security Checks
1. Try to SSH from an unauthorized network (e.g., cell phone hotspot) and confirm it hangs/times out (Security Group verification).
2. Check if password-based login is rejected: `ssh ubuntu@<PUBLIC_IP>` (without `-i` flag) should refuse connection or fail authentication.

### Step 11: Manual Cleanup (Console)
1. **Terminate Instance**: Select `Project2-Web-Server` -> **Instance state** -> **Terminate instance**.
2. **Delete Security Group**: Delete `project2-web-server-sg`.
3. **Delete Key Pair**: Delete `project2-key`.
4. **Delete IAM Role**: Delete `Project2-EC2-Role`.

---

## Phase 2: Automation with User Data

In this phase, we replace the manual SSH-based setup from Phase 1 with an automated bootstrap script. AWS EC2 allows passing a `user-data.sh` script that runs as `root` during the first boot cycle.

### Step 1: Create the User Data Script
We created a `user-data.sh` bash script that automates:
1. Updating the OS packages.
2. Installing Python 3, Nginx, Git, and security tools (fail2ban).
3. Cloning the repository and setting up the Python virtual environment.
4. Installing dependencies (including `gunicorn`).
5. Creating and enabling the systemd service.
6. Configuring Nginx as a reverse proxy.

### Step 2: Launch Instance with User Data
1. Launch an EC2 instance exactly as done in Phase 1 (same VPC, Security Group, IAM Role, Key Pair).
2. Under **Advanced Details**, scroll down to the **User data** field.
3. Paste the contents of `user-data.sh` into the text box (or select the file).
4. Launch the instance.

### Step 3: Verification
1. Wait a few minutes for the instance to boot and execute the script.
2. Navigate to `http://<PUBLIC_IP>` in your browser. The Flask dashboard will appear automatically without a single SSH command!
3. *(Optional)* If troubleshooting is needed, SSH into the instance and check the logs:
   \`\`\`bash
   cat /var/log/user-data.log
   \`\`\`

### Step 4: Cleanup
Terminate the instance and delete the resources from the AWS Console to prevent charges.