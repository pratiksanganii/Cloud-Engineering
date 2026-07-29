# Cloud Engineering Portfolio

A progressive series of hands-on projects designed to master AWS infrastructure, Linux server administration, DevOps automation, and Infrastructure as Code (IaC). 

This repository documents my journey from manual cloud configuration to fully automated, production-grade architectures.

---

## 🚀 Projects Index

### [Project 1: AWS Serverless Static Website (React/Vite)](https://github.com/pratiksanganii/devutils-static-site)
**Tech Stack:** AWS (S3, CloudFront, ACM), Cloudflare DNS, React 19, TypeScript, Tailwind CSS.
* Engineered a privacy-first suite of client-side developer tools (JSON Formatter, UUID Generator, JWT Decoder).
* Deployed as a highly available static site using S3 and CloudFront with Origin Access Control (OAC).
* Configured custom domain with HTTPS via AWS Certificate Manager (ACM) and Cloudflare DNS.
* Implemented automated CI/CD deployment workflows using GitHub Actions.

### [Project 2: Hardened Linux Web Server on EC2](./A02-ec2-linux-server/README.md)
**Tech Stack:** AWS (EC2, VPC, IAM, Security Groups), Linux (Ubuntu), Nginx, Python/Flask, Bash.
* Started with manual provisioning and networking (custom VPC, Subnets, Route Tables).
* Hardened server security with Fail2ban and strict Security Group ingress rules.
* Automated server bootstrap using `user-data.sh`.
* Fully automated the infrastructure lifecycle using AWS CLI deployment (`deploy.sh`) and cleanup (`cleanup.sh`) scripts.

### [Project 3: Serverless Contact Form (API Gateway + Lambda + SES)](./A03-serverless-contact-form/README.md)
**Tech Stack:** AWS (API Gateway, Lambda, SES, IAM), Node.js (ES Modules), Bash.
* Designed a fully serverless, event-driven backend to process contact form submissions.
* Engineered a secure Lambda function (Node 24.x) utilizing AWS SDK v3, HTML sanitization against XSS, and regex validation.
* Implemented strict IAM Principle of Least Privilege resource policies to restrict API Gateway invocations and SES capabilities.
* Authored idempotent bash automation scripts (`deploy.sh` & `cleanup.sh`) utilizing a centralized `config.sh` to prevent configuration drift.

### [Project 4: RDS Database with Automated Backups](./A04%20-%20RDS%20Database/README.md)
**Tech Stack:** AWS (RDS PostgreSQL, EC2, VPC, CloudWatch), Bash.
* Deployed a managed PostgreSQL database with Multi-AZ redundancy for automatic failover across Availability Zones.
* Architected defense-in-depth networking: private subnets with no internet route, security group chaining (SG-to-SG references), and a bastion host for secure database access.
* Configured automated backups (7-day retention), storage encryption at rest, and custom DB parameter groups for performance tuning.
* Set up CloudWatch alarms for CPU utilization and storage monitoring.

### [Project 5: CI/CD Pipeline with GitHub Actions](./A05-cicd-pipeline/README.md)
**Tech Stack:** GitHub Actions, AWS (IAM OIDC, S3), Node.js, Express, Jest, ESLint, Bash.
* Built automated CI/CD pipelines using GitHub Actions for continuous integration (ESLint + Jest) and deployment to S3.
* Implemented keyless AWS authentication using IAM OpenID Connect (OIDC) identity federation scoped to the GitHub repository.
* Solved real-world OIDC edge cases including user/repository numeric ID claim matching and workflow dependencies (`needs: build-and-test`).
* Authored idempotent bash automation scripts (`setup-project.sh`, `configure-aws.sh` & `cleanup-aws.sh`) backed by a centralized `config.sh`.

---

## 🧠 Core Philosophy
1. **Manual First, Automate Second:** Understand the underlying components (networking, permissions, OS) before abstracting them with tools like Terraform.
2. **Security by Default:** Apply the principle of least privilege, strict firewalls, and secure defaults from day one.
3. **Idempotency & Clean Teardowns:** Infrastructure should be predictably deployed and cleanly destroyed to prevent configuration drift and unexpected costs.
