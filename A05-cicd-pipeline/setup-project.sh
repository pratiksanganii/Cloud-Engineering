#!/bin/bash
# Project 5: Setup Sample Project & GitHub Actions Workflow

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🚀 Setting up Node.js sample application & GitHub Actions workflow...${NC}"
echo "------------------------------------------------------------"

if [ -z "$1" ] || [ -z "$2" ]; then
    echo -e "${RED}❌ Error: Missing arguments.${NC}"
    echo "Usage: ./setup-project.sh <github-username> <repo-name>"
    echo "Example: ./setup-project.sh johndoe my-awesome-app"
    exit 1
fi

GITHUB_USER="$1"
REPO_NAME="$2"
TARGET_DIR="my-app"

# Check prerequisites
for cmd in node npm git; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}❌ Error: $cmd is not installed or not in PATH.${NC}"
        exit 1
    fi
done

echo -e "${BLUE}Step 1: Creating project directory '${TARGET_DIR}'...${NC}"
mkdir -p "$TARGET_DIR/src" "$TARGET_DIR/tests" "$TARGET_DIR/.github/workflows"
cd "$TARGET_DIR"

# package.json
cat > package.json << 'EOF'
{
  "name": "my-app",
  "version": "1.0.0",
  "description": "Sample Express app for CI/CD pipeline",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "test": "jest --verbose --forceExit",
    "lint": "eslint src/ tests/"
  },
  "dependencies": {
    "express": "^4.19.2"
  },
  "devDependencies": {
    "@eslint/js": "^9.0.0",
    "eslint": "^9.0.0",
    "globals": "^15.0.0",
    "jest": "^29.7.0",
    "supertest": "^7.0.0"
  }
}
EOF

# eslint.config.js
cat > eslint.config.js << 'EOF'
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
EOF

# src/index.js
cat > src/index.js << 'EOF'
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

if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
  });
}

module.exports = app;
EOF

# tests/index.test.js
cat > tests/index.test.js << 'EOF'
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
EOF

# .gitignore
cat > .gitignore << 'EOF'
node_modules/
coverage/
.env
*.log
*.zip
EOF

# CI/CD Workflow (.github/workflows/ci-cd.yml)
cat > .github/workflows/ci-cd.yml << EOF
name: CI/CD Pipeline

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  id-token: write
  contents: read

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
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run ESLint
        run: npm run lint

      - name: Run Jest tests
        run: npm test

  deploy:
    name: Deploy to S3
    needs: build-and-test
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Package artifact
        run: |
          TIMESTAMP=\$(date +%Y%m%d-%H%M%S)
          SHORT_SHA=\${GITHUB_SHA::7}
          ARTIFACT_NAME="deploy-\${TIMESTAMP}-\${SHORT_SHA}.zip"
          zip -r "\$ARTIFACT_NAME" src/ package.json package-lock.json \\
            --exclude "node_modules/*" --exclude "tests/*" --exclude ".github/*"
          echo "ARTIFACT_NAME=\$ARTIFACT_NAME" >> \$GITHUB_ENV

      - name: Configure AWS Credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::\${{ secrets.AWS_ACCOUNT_ID }}:role/GitHubActionsRole
          aws-region: ap-south-1

      - name: Upload artifact to S3
        run: |
          aws s3 cp "\$ARTIFACT_NAME" s3://\${{ secrets.S3_BUCKET_NAME }}/artifacts/
          echo "✅ Uploaded: s3://\${{ secrets.S3_BUCKET_NAME }}/artifacts/\$ARTIFACT_NAME"
EOF

echo -e "${BLUE}Step 2: Installing dependencies locally...${NC}"
npm install --silent

echo -e "${BLUE}Step 3: Running local verification tests...${NC}"
npm test
npm run lint

echo "------------------------------------------------------------"
echo -e "${GREEN}✅ Application setup complete!${NC}"
echo -e "Location: ${BLUE}$(pwd)${NC}"
echo ""
echo "Next steps:"
echo "1. Run ../configure-aws.sh $GITHUB_USER $REPO_NAME to provision AWS resources."
echo "2. Push this application code to GitHub."
