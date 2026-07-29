# Project 5: CI/CD Pipeline with GitHub Actions

## Overview

Your development team needs an automated pipeline that tests code on every commit and deploys successful builds to production. Instead of manually running tests and deployments, you will implement a CI/CD pipeline using GitHub Actions that automatically lints, tests, and deploys your application to AWS with zero manual intervention.

The pipeline uses IAM OIDC federation for keyless authentication — no AWS access keys are stored in GitHub. On every push, GitHub Actions assumes an IAM role via a short-lived token, runs the CI checks, and syncs the build artifacts to an S3 bucket configured for static website hosting.

## Architecture

```
  Developer Workstation
         │
         │ git push
         ▼
  ┌─────────────────────────────────────────────────────────┐
  │  GitHub                                                  │
  │                                                          │
  │  ┌────────────────────────────────────────────────────┐  │
  │  │  GitHub Actions                                     │  │
  │  │                                                     │  │
  │  │  ┌──────────┐   ┌──────────┐   ┌───────────────┐   │  │
  │  │  │ Checkout  │──▶│  Lint    │──▶│     Test      │   │  │
  │  │  │          │   │ (ESLint) │   │    (Jest)     │   │  │
  │  │  └──────────┘   └──────────┘   └───────┬───────┘   │  │
  │  │                                         │           │  │
  │  │                              (main branch only)     │  │
  │  │                                         │           │  │
  │  │                                         ▼           │  │
  │  │                                ┌───────────────┐    │  │
  │  │                                │  OIDC Auth    │    │  │
  │  │                                │  (AssumeRole) │    │  │
  │  │                                └───────┬───────┘    │  │
  │  └────────────────────────────────────────┼────────────┘  │
  └───────────────────────────────────────────┼───────────────┘
                                              │
                              OIDC Federation │ (short-lived token)
                                              │
  ┌───────────────────────────────────────────┼───────────────┐
  │  AWS Account                              │               │
  │                                           ▼               │
  │  ┌─────────────────┐          ┌───────────────────────┐   │
  │  │  IAM OIDC        │◀─trust──│  GitHubActionsRole    │   │
  │  │  Provider         │         │  (S3FullAccess)       │   │
  │  └─────────────────┘          └───────────┬───────────┘   │
  │                                           │               │
  │                                    s3 cp  │               │
  │                                           ▼               │
  │                               ┌───────────────────────┐   │
  │                               │  S3 Bucket            │   │
  │                               │  (Private)            │   │
  │                               │  deploy-v1.0.0.zip    │   │
  │                               └───────────────────────┘   │
  │                                                           │
  └───────────────────────────────────────────────────────────┘
```



## What You Will Build


| Resource                       | Purpose                                                                  |
| ------------------------------ | ------------------------------------------------------------------------ |
| GitHub Repository              | Hosts the Node.js application source code                                |
| GitHub Actions Workflows       | Automated CI (lint + test) and CD (deploy) pipelines                     |
| IAM OIDC Provider              | Trusts GitHub's OIDC tokens for keyless authentication                   |
| IAM Role (`GitHubActionsRole`) | Assumed by GitHub Actions to access AWS resources                        |
| S3 Bucket                      | Private bucket that stores versioned deployment artifacts (zip packages) |
| GitHub Secrets                 | Stores AWS Account ID and S3 bucket name securely                        |




## Project Structure

```text
A05-cicd-pipeline/
├── .github/
│   └── workflows/
│       └── ci-cd.yml          # Reference combined CI/CD workflow
├── setup-project.sh           # Scaffolds the sample Node.js app and workflows
├── configure-aws.sh           # Provisions AWS resources (OIDC, IAM, S3)
├── cleanup-aws.sh             # Tears down all AWS resources
└── README.md                  # This file — manual + automated guide
```

After running `setup-project.sh`, a `my-app/` directory is created:

```text
my-app/
├── .github/
│   └── workflows/
│       ├── ci.yml             # Build, lint, test pipeline
│       └── deploy.yml         # AWS deployment pipeline
├── src/
│   └── index.js               # Express REST API
├── tests/
│   └── index.test.js          # Jest unit tests
├── package.json
├── eslint.config.js
└── .gitignore
```



## Prerequisites

- GitHub account with a repository (public or private)
- AWS account with IAM and S3 permissions
- Node.js and npm installed locally
- AWS CLI installed and configured
- Git installed for version control
- GitHub CLI (`gh`) installed (optional, for secret management)

---



## Step 1 — Create the Sample Node.js Application

Before setting up any CI/CD infrastructure, you need an application to test and deploy. We'll create a minimal Express REST API with Jest tests and ESLint configuration.

### Initialize the Project

```bash
mkdir my-cicd-app && cd my-cicd-app
npm init -y
npm install express
npm install --save-dev jest eslint @eslint/js globals supertest
```



### Create the Express Application

Create `src/index.js`:

```javascript
const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

app.get('/', (req, res) => {
  res.json({
    message: 'Hello from CI/CD Pipeline!',
    version: '1.0.0',
    timestamp: new Date().toISOString()
  });
});

app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    uptime: process.uptime()
  });
});

app.get('/api/info', (req, res) => {
  res.json({
    app: 'my-app',
    environment: process.env.NODE_ENV || 'development',
    node_version: process.version
  });
});

// Only start listening if this file is run directly (not imported for testing)
if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
  });
}

module.exports = app;
```



### Create Jest Tests

Create `tests/index.test.js`:

```javascript
const request = require('supertest');
const app = require('../src/index');

describe('GET /', () => {
  it('should return welcome message', async () => {
    const res = await request(app).get('/');
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('message');
    expect(res.body.message).toBe('Hello from CI/CD Pipeline!');
  });
});

describe('GET /health', () => {
  it('should return healthy status', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('healthy');
    expect(res.body).toHaveProperty('uptime');
  });
});

describe('GET /api/info', () => {
  it('should return app info', async () => {
    const res = await request(app).get('/api/info');
    expect(res.statusCode).toBe(200);
    expect(res.body.app).toBe('my-app');
    expect(res.body).toHaveProperty('environment');
    expect(res.body).toHaveProperty('node_version');
  });
});
```



### Configure ESLint

ESLint v9+ uses the flat config format. Create `eslint.config.js` (not `.eslintrc.json`):

```javascript
const globals = require('globals');
const js = require('@eslint/js');

module.exports = [
  js.configs.recommended,
  {
    languageOptions: {
      ecmaVersion: 'latest',
      globals: {
        ...globals.node,
        ...globals.jest
      }
    },
    rules: {
      'no-unused-vars': 'warn',
      'no-console': 'off'
    }
  }
];
```



### Update package.json Scripts

Edit `package.json` and update the `scripts` section:

```json
{
  "scripts": {
    "start": "node src/index.js",
    "test": "jest --verbose --forceExit",
    "lint": "eslint src/ tests/"
  }
}
```



### Create .gitignore

Create `.gitignore`:

```
node_modules/
coverage/
.env
*.log
```



### Verify Locally

```bash
npm test       # Run Jest tests — all 3 should pass
npm run lint   # Run ESLint — should report no errors
npm start      # Start server on http://localhost:3000
```

Test the running server in a separate terminal:

```bash
curl http://localhost:3000/
curl http://localhost:3000/health
curl http://localhost:3000/api/info
```

---



## Step 2 — Create GitHub Actions CI Workflow

Now that the app works locally, create the CI workflow that runs linting and tests on every push.

### Create the Workflow File

Create `.github/workflows/ci.yml` inside `my-app/`:

```yaml
name: CI Pipeline

on:
  push:
    branches: ['*']
  pull_request:
    branches: [main]

jobs:
  build-and-test:
    name: Build, Lint & Test
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '24'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run ESLint
        run: npm run lint

      - name: Run Jest tests
        run: npm test
```

> **What is** `npm ci`**?** Unlike `npm install`, `npm ci` does a clean install from `package-lock.json`. It's faster and more deterministic — exactly what you want in CI where reproducibility matters.

---



## Step 3 — Create IAM OIDC Provider for GitHub Actions

GitHub Actions can authenticate to AWS without storing long-lived access keys. Instead, GitHub's OIDC provider issues short-lived tokens that AWS trusts via an IAM Identity Provider.

1. Go to **IAM → Identity providers → Add provider**
2. Configure:
  - **Provider type:** OpenID Connect
  - **Provider URL:** `https://token.actions.githubusercontent.com`
  - **Audience:** `sts.amazonaws.com`
3. Click **Add provider**
4. After creation, go to the provider details → **Endpoint verification** — you'll see a thumbprint already populated. AWS automatically fetches and verifies the thumbprint for well-known OIDC providers like GitHub.

> **Do I need to manually verify the thumbprint?** No. GitHub's OIDC provider uses a certificate signed by a trusted root CA in AWS's built-in trust store. AWS maintains the thumbprint in your configuration but doesn't actually rely on it for validation — the trusted CA chain handles security instead.

> **Why OIDC instead of access keys?** Access keys are long-lived secrets that can be leaked or stolen. OIDC tokens are short-lived (valid for ~15 minutes), scoped to a specific workflow run, and never stored as plaintext. If a token is compromised, it expires before an attacker can do meaningful damage.

---



## Step 4 — Create IAM Role for GitHub Actions

The IAM role defines what GitHub Actions is allowed to do in your AWS account. The trust policy restricts role assumption to your specific GitHub repository.

1. Go to **IAM → Roles → Create role**
2. **Trusted entity type:** Web identity
3. **Identity provider:** `token.actions.githubusercontent.com`
4. **Audience:** `sts.amazonaws.com`
5. The console now shows GitHub-specific fields:
  - **GitHub organization:** your GitHub username (e.g., `pratiksanganii`)
  - **GitHub repository:** your repo name (e.g., `my-cicd-app`)
  - **GitHub branch:** leave empty (allows all branches to assume the role)
6. Click **Next**
7. **Permissions:** Search and attach **AmazonS3FullAccess** → click **Next**
8. **Role name:** `GitHubActionsRole` → click **Create role**

After creation, open the role → **Trust relationships** tab to verify the auto-generated trust policy. It should look like this:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<YOUR_ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:pratiksanganii/my-cicd-app:*"
        }
      }
    }
  ]
}
```



## Step 5 — Create S3 Bucket for Deployment Artifacts

The S3 bucket stores versioned deployment artifacts (zip packages). It stays **fully private** — no public access is needed since this is an artifact store, not a website host.

1. Go to **S3 → Create bucket**
  - **Bucket name:** a globally unique name, e.g. `myapp-cicd-artifacts-<random-suffix>`
  - **Region:** `ap-south-1` (or your preferred region)
  - **Keep** Block *all* public access **checked** (default)
2. Click **Create bucket**

That's it — no static website hosting, no bucket policy, no public access. The `GitHubActionsRole` created in Step 4 already has `AmazonS3FullAccess`, which grants it permission to upload artifacts to this bucket.

> **Why keep the bucket private?** This bucket stores deployment packages, not a public website. Only the CI/CD pipeline (via the IAM role) needs write access. No one else needs to read from it directly. If you later need to serve static content publicly, you'd use a separate bucket with CloudFront + OAC (like Project 1).

---



## Step 6 — Copy Your AWS Account ID

The Account ID is required for configuring OIDC authentication in the GitHub Actions workflow.

1. Click your account name in the top-right corner of the AWS Console
2. Click **Account**
3. Copy the 12-digit **Account ID** (e.g., `123456789012`)

---



## Step 7 — Create the Deploy Workflow

Now create the deployment workflow that authenticates via OIDC and uploads a versioned zip artifact to S3. This workflow only runs on pushes to `main` — feature branches only trigger CI.

Create `.github/workflows/deploy.yml` inside `my-app/`:

```yaml
name: Deploy to AWS

on:
  push:
    branches: [main]

permissions:
  id-token: write    # Required for OIDC authentication
  contents: read     # Required for actions/checkout

jobs:
  deploy:
    name: Deploy to S3
    runs-on: ubuntu-latest
    environment: production

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '24'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run tests before deploy
        run: npm test

      - name: Package artifact
        run: |
          TIMESTAMP=$(date +%Y%m%d-%H%M%S)
          SHORT_SHA=${GITHUB_SHA::7}
          ARTIFACT_NAME="deploy-${TIMESTAMP}-${SHORT_SHA}.zip"
          zip -r "$ARTIFACT_NAME" src/ package.json package-lock.json \
            --exclude "node_modules/*" --exclude "tests/*" --exclude ".github/*"
          echo "ARTIFACT_NAME=$ARTIFACT_NAME" >> $GITHUB_ENV

      - name: Configure AWS Credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/GitHubActionsRole
          aws-region: ap-south-1

      - name: Upload artifact to S3
        run: |
          aws s3 cp "$ARTIFACT_NAME" s3://${{ secrets.S3_BUCKET_NAME }}/artifacts/
          echo "✅ Uploaded: s3://${{ secrets.S3_BUCKET_NAME }}/artifacts/$ARTIFACT_NAME"
```

> **What does** `permissions: id-token: write` **do?** It grants the workflow permission to request an OIDC token from GitHub. Without this, the `aws-actions/configure-aws-credentials` action cannot generate the short-lived token needed to assume the IAM role. The `contents: read` permission is needed for `actions/checkout` to clone the repository.

> **Why a versioned zip instead of** `s3 sync`**?** Each deployment produces a uniquely named artifact (`deploy-20260729-143000-a1b2c3d.zip`) with a timestamp and commit SHA. This gives you a full deployment history in S3 — you can see exactly what was deployed and when, and roll back by re-deploying an older artifact.

---



## Step 8 — Push Code to GitHub and Add Secrets



### Initialize Git and Push

```bash
cd my-app
git init
git add .
git commit -m "Initial CI/CD setup"

# Using GitHub CLI (recommended)
gh repo create <repo-name> --public --source=. --remote=origin

# Or manually: create the repo on github.com, then:
# git remote add origin https://github.com/<username>/<repo-name>.git

git branch -M main
git push -u origin main
```



### Add Repository Secrets

The workflow references two secrets that must be added to GitHub:

**Using GitHub CLI (from inside** `my-app/`**):**

```bash
gh secret set AWS_ACCOUNT_ID --body "<your-12-digit-account-id>"
gh secret set S3_BUCKET_NAME --body "<your-bucket-name>"
```

**Using the GitHub Console:**

1. Go to your repository on GitHub → **Settings → Secrets and variables → Actions**
2. Click **New repository secret** and add:
  - **Name:** `AWS_ACCOUNT_ID` | **Value:** your 12-digit account ID
  - **Name:** `S3_BUCKET_NAME` | **Value:** your bucket name (e.g., `myapp-cicd-deploy-12345`)
3. Click **Add secret** for each

> **Why use secrets instead of hardcoding?** The Account ID and bucket name aren't passwords, but they are environment-specific configuration that changes per deployment. Secrets keep workflows portable — the same YAML works for any AWS account without code changes.

---



## Step 9 — Monitor Pipeline Execution

After pushing to `main`, both workflows trigger automatically: CI runs lint + tests, and Deploy syncs to S3.

### Using GitHub CLI

```bash
# List recent workflow runs
gh run list

# Stream logs for the latest run in real time
gh run watch
```



### Using the GitHub Console

1. Go to your repository → **Actions** tab
2. Click on the latest workflow run to see job details
3. Expand each step to view logs



### Verify the Deployment

After the deploy job completes successfully, verify the artifact is in S3:

```bash
aws s3 ls s3://<your-bucket-name>/artifacts/
```

You should see a zip file like `deploy-20260729-143000-a1b2c3d.zip`.

---



## Step 10 — Trigger a New Deployment

To verify the full pipeline end-to-end, make a small change and push:

```bash
cd my-app
echo "// Updated $(date)" >> src/index.js
git add src/index.js
git commit -m "Trigger CI/CD pipeline"
git push
```

Monitor the run:

```bash
gh run watch
```

After the deploy job completes, confirm a new artifact appeared in S3:

```bash
aws s3 ls s3://<your-bucket-name>/artifacts/
```

---



## CI/CD Workflow Overview



### CI Pipeline (`ci.yml`)

Triggers on every push to any branch and pull requests to `main`:

```
Checkout → Setup Node.js (cached) → npm ci → ESLint → Jest
```

If any step fails, the workflow stops and reports the failure. Pull requests show a red/green status check on GitHub.

### Deploy Pipeline (`deploy.yml`)

Triggers only on pushes to `main`:

```
Checkout → Setup Node.js → npm ci → Jest → Package Zip → OIDC Auth → S3 Upload
```

Tests run again before deployment as a safety gate — even though CI already passed, this ensures the `main` branch is always in a deployable state.

### Combined Reference (`ci-cd.yml`)

A single-file version combining both pipelines is provided in the project directory (`.github/workflows/ci-cd.yml`) for reference. It demonstrates conditional deployment using `if: github.ref == 'refs/heads/main'` instead of separate workflow files.

---



## Verification Checklist

- [ ] Application runs locally (`npm start`) and all endpoints respond
- [ ] All Jest tests pass locally (`npm test`)
- [ ] ESLint reports no errors locally (`npm run lint`)
- [ ] IAM OIDC Provider exists for `token.actions.githubusercontent.com`
- [ ] `GitHubActionsRole` trust policy is scoped to your repository
- [ ] S3 bucket exists and Block Public Access is enabled (private)
- [ ] GitHub secrets `AWS_ACCOUNT_ID` and `S3_BUCKET_NAME` are set
- [ ] CI workflow passes on push (Actions tab shows green)
- [ ] Deploy workflow completes and a versioned zip artifact appears in S3

---



## Cleanup

> ⚠️ **Always clean up after finishing to avoid unexpected S3 storage charges.**

Delete resources in this order:

1. **S3** → open your bucket → select all objects → **Delete objects** → then **Delete bucket**
2. **IAM → Roles** → select `GitHubActionsRole`:
  - **Permissions** tab → remove all attached policies
  - Click **Delete** on the role
3. **IAM → Identity providers** → select `token.actions.githubusercontent.com` → **Delete**
4. **GitHub** → (optional) delete the repository or remove the secrets

> **Cleanup order matters.** Empty the S3 bucket before deleting it — non-empty buckets cannot be deleted. Detach policies from the IAM role before deleting the role.

---



## Learning Objectives

After completing this project, you will understand:

- GitHub Actions workflow syntax, triggers, jobs, and steps
- Setting up CI pipelines for automated linting and testing
- Using IAM OIDC identity federation for keyless AWS authentication from GitHub Actions
- Configuring IAM trust policies scoped to specific GitHub repositories
- Deploying application artifacts to Amazon S3 via `aws s3 sync`
- Storing versioned deployment artifacts in S3 for auditability and rollback
- Managing repository secrets in GitHub for environment-specific configuration
- Monitoring and troubleshooting failed workflow runs

---



## Troubleshooting


| Problem                                                          | Solution                                                                                                                                                  |
| ---------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| OIDC authentication fails                                        | Verify the trust policy contains the correct GitHub username, repository name, and Account ID. Ensure `id-token: write` permission is set in the workflow |
| `Error: Not authorized to perform sts:AssumeRoleWithWebIdentity` | GitHub OIDC `sub` claims may append internal numeric IDs (e.g. `repo:user@123/repo@456:ref:...`). Use strict scoping: `repo:<user>@*/<repo>@*:ref:refs/heads/*` or `token.actions.githubusercontent.com:job_workflow_ref`. |
| Tests fail in CI but pass locally                                | Check for environment-specific issues (hardcoded paths, timezone differences). Reproduce with `npm test` in a clean environment                           |
| Deployment fails with Access Denied                              | Confirm the IAM role has `AmazonS3FullAccess` attached and the `S3_BUCKET_NAME` secret matches the actual bucket name                                     |
| Workflow not triggering                                          | Check the `on:` trigger branches match the branch you pushed to. Verify the workflow file is in `.github/workflows/`                                      |
| `npm ci` fails in CI                                             | Ensure `package-lock.json` is committed to the repository. `npm ci` requires it                                                                           |
| Artifact not appearing in S3                                     | Check the deploy workflow logs for errors. Verify the `S3_BUCKET_NAME` secret matches the actual bucket name                                              |


