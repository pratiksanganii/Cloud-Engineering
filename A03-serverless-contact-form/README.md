# Project 3: Serverless Contact Form with Lambda and SES

## Overview
This project builds a fully serverless architecture to process contact form submissions. A static HTML frontend sends data to an AWS API Gateway, which triggers an AWS Lambda function. The Lambda function parses the data and uses Amazon Simple Email Service (SES) to send an email to the support team.

---

## Project Structure
```text
A03-serverless-contact-form/
├── lambda/
│   └── index.js        # Node.js 24.x Lambda handler using AWS SDK v3
├── frontend/
│   └── contact.html    # Glassmorphism UI with vanilla JS fetch
└── README.md           # This documentation
```

---

## Phase 1: Manual Deep Dive

To understand the underlying mechanics of serverless architecture, we first provisioned the entire stack manually using the AWS Console.

### Step 1: Verify Email in Amazon SES
Before AWS allows you to send emails programmatically, the identities must be verified (especially when SES is in Sandbox mode).
1. Go to **AWS Console → SES → Verified identities**.
2. Click **Create identity** → select **Email address**.
3. Entered the sender/recipient email address and clicked **Create identity**.
4. Verified the address by clicking the link sent to the inbox.

### Step 2: Create IAM Role for Lambda (Least Privilege)
An IAM Role requires two distinct policies: a **Trust Policy** (who can assume the role) and a **Permission Policy** (what they can do).
1. Go to **IAM → Roles → Create role**.
2. **Trusted entity type:** AWS service → **Use case:** Lambda. *(This automatically generates the Trust Policy allowing `lambda.amazonaws.com` to assume the role).*
3. Attached the AWS-managed **AWSLambdaBasicExecutionRole** to allow the function to write execution logs to CloudWatch.
4. Named the role `ContactFormLambdaRole` and created it.
5. Opened the new role, clicked **Add permissions → Create inline policy**, and added the following JSON to grant SES send permissions:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [{
       "Effect": "Allow",
       "Action": ["ses:SendEmail", "ses:SendRawEmail"],
       "Resource": "*"
     }]
   }
   ```

### Step 3: Create the Lambda Function
1. Go to **Lambda → Create function**.
2. **Function name:** `ContactFormHandler`
3. **Runtime:** Node.js 24.x
4. Under **Permissions**, chose **Use an existing role** and selected `ContactFormLambdaRole`.
5. Created the function and pasted the local `lambda/index.js` code into the inline editor.
6. Under **Configuration → Environment variables**, added:
   * `SENDER_EMAIL` = (verified email)
   * `RECIPIENT_EMAIL` = (verified email)
7. Deployed the function.

### Step 4: Create API Gateway & Configure CORS
1. Go to **API Gateway → Create API → REST API** (not private).
2. Named it `ContactFormAPI`.
3. Created a new Resource named `contact`.
4. **Create POST Method:**
   * Method type: `POST`
   * Integration type: `Lambda function`
   * **Lambda proxy integration:** `ON` *(Crucial for passing headers and body directly to Lambda)*
   * Lambda function: `ContactFormHandler`
5. **Configure CORS:**
   * Selected the `/contact` resource and clicked **Enable CORS**.
   * Ensured `POST` and `OPTIONS` were checked, and saved. *(This automatically creates the OPTIONS method and MOCK integrations required for browser preflight checks).*
6. Clicked **Deploy API** to a new stage named `prod` and copied the Invoke URL.

### Step 5: Test the Frontend Locally
1. Opened `frontend/contact.html` locally.
2. Replaced the `API_ENDPOINT` constant with the copied API Gateway Invoke URL (e.g., `https://xxxxxx.execute-api.us-east-1.amazonaws.com/prod/contact`).
3. Submitted the form in the browser.
4. Verified that the UI showed a success message and the email successfully arrived in the verified inbox.

---

## Cleanup
To prevent any unexpected charges or clutter, the manual resources should be deleted when testing is complete:
1. **API Gateway:** Delete `ContactFormAPI`.
2. **Lambda:** Delete `ContactFormHandler`.
3. **IAM:** Delete the inline SES policy, detach the Basic Execution policy, and delete `ContactFormLambdaRole`.
4. **SES:** Delete the verified email identity.
