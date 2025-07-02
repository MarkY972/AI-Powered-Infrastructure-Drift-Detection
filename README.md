# AI-Powered Infrastructure Drift Detection and Auto-Healing (Conceptual)

This project demonstrates a system that periodically checks cloud infrastructure (provisioned by Terraform on AWS) for drift and uses an AI agent to evaluate the drift and recommend actions. The primary focus is on an EKS (Elastic Kubernetes Service) cluster.

## Project Overview

The system is designed to:

1.  **Provision Infrastructure**: Define an AWS EKS cluster and supporting resources (VPC, Subnets, IAM Roles, SNS Topic) using Terraform.
2.  **Detect Drift**: Periodically run `terraform plan` to identify any discrepancies between the desired state (Terraform code) and the actual state (AWS infrastructure).
3.  **Parse Drift**: A Python script parses the `terraform plan` output.
4.  **AI Analysis**: The parsed drift information is sent to an AI model (OpenAI GPT) for:
    *   A summary of the detected changes.
    *   An assessment of the potential impact of each change.
    *   A recommendation on whether the changes are safe to apply automatically or require manual review.
5.  **Notify**: Send notifications (e.g., via AWS SNS) to operators about detected drift, including the AI's analysis.
6.  **Automate**: The entire process is orchestrated and scheduled using GitHub Actions.

## Key Features & Technologies

*   **Infrastructure as Code (IaC)**: [Terraform](https://www.terraform.io/) for provisioning and managing AWS resources.
*   **Cloud Provider**: [Amazon Web Services (AWS)](https://aws.amazon.com/), specifically EKS, VPC, EC2 (for nodes), IAM, SNS.
*   **Drift Detection & Parsing**: [Python](https://www.python.org/) script (`scripts/drift_detector.py`) using `subprocess` to run Terraform commands and `json` to parse output.
*   **AI Agent Integration**: [OpenAI API](https://openai.com/docs) (GPT models like `gpt-3.5-turbo` or `gpt-4`) for analyzing drift.
    *   `openai` Python library.
*   **Automation & CI/CD**: [GitHub Actions](https://github.com/features/actions) for scheduled drift checks.
*   **Notifications**: [AWS Simple Notification Service (SNS)](https://aws.amazon.com/sns/) for alerting operators.
    *   `boto3` Python library.
*   **Dependency Management**: `requirements.txt` for Python packages.
*   **Environment Management**: `.env` file (from `.env.example`) for local configuration (API keys, etc.).

## Project Structure

```
.
├── .github/
│   └── workflows/
│       └── drift_check.yml     # GitHub Actions workflow for scheduled drift detection
├── scripts/
│   └── drift_detector.py       # Python script for Terraform plan, parse, AI analysis, SNS notification
├── terraform/
│   ├── main.tf                 # Main Terraform configuration for EKS and supporting resources
│   ├── variables.tf            # Terraform input variables
│   ├── outputs.tf              # Terraform outputs
│   └── backend.tf              # Terraform S3 backend configuration
├── .env.example                # Example environment file for local development
├── AGENTS.md                   # Instructions for AI agents working on this codebase
├── README.md                   # This file
└── requirements.txt            # Python dependencies
```

## Setup and Usage

### Prerequisites

*   **AWS Account**: An active AWS account.
*   **AWS CLI**: Configured with credentials that have permissions to create and manage EKS, VPC, IAM, SNS, and related resources.
*   **Terraform CLI**: Installed (version specified in `drift_check.yml` or latest).
*   **Python**: Installed (version specified in `drift_check.yml`, e.g., 3.10+).
*   **OpenAI API Key**: An API key from OpenAI.
*   **Git & GitHub Repository**: Project hosted on GitHub.

### Local Setup (for development/testing)

1.  **Clone the repository**:
    ```bash
    git clone <repository_url>
    cd <repository_name>
    ```

2.  **Set up Python environment**:
    ```bash
    python -m venv venv
    source venv/bin/activate  # On Windows: venv\Scripts\activate
    pip install -r requirements.txt
    ```

3.  **Configure Environment Variables**:
    *   Copy `.env.example` to `.env`:
        ```bash
        cp .env.example .env
        ```
    *   Edit `.env` and fill in your actual values:
        *   `OPENAI_API_KEY`: Your OpenAI API key.
        *   `SNS_TOPIC_ARN`: The ARN of the SNS topic (output by Terraform after the first successful apply, or if pre-existing).
        *   `AWS_REGION`: Your target AWS region (e.g., `us-west-2`). This will also be used by the S3 backend.
        *   You might also need to set `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` if not configured globally via AWS CLI profiles and not using OIDC for local tests that mimic GitHub Actions.

<br/>

### ‼️ Important: Configure Terraform Backend (First Time Setup)

For collaboration and use with GitHub Actions, a remote backend for Terraform state is crucial. This project is configured to use AWS S3 with DynamoDB for locking. The configuration is in `terraform/backend.tf`.

**You must create the S3 bucket and DynamoDB table *before* running `terraform init` or `terraform apply` for the main EKS infrastructure with the backend configured.**

**1. Create an S3 Bucket for Terraform State:**
   *   **Name:** Choose a globally unique name (e.g., `my-tf-state-bucket-unique-name-123`).
   *   **Region:** Create it in the same AWS region you intend to deploy your EKS cluster.
   *   **Settings:**
        *   Enable **versioning**.
        *   Enable **server-side encryption** (SSE-S3 or SSE-KMS).
        *   **Block all public access**.

   *Example AWS CLI (replace placeholders):*
   ```bash
   aws s3api create-bucket --bucket YOUR_S3_BUCKET_NAME --region YOUR_AWS_REGION --create-bucket-configuration LocationConstraint=YOUR_AWS_REGION
   aws s3api put-bucket-versioning --bucket YOUR_S3_BUCKET_NAME --versioning-configuration Status=Enabled
   aws s3api put-bucket-encryption --bucket YOUR_S3_BUCKET_NAME --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'
   aws s3api put-public-access-block --bucket YOUR_S3_BUCKET_NAME --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
   ```

**2. Create a DynamoDB Table for State Locking:**
   *   **Name:** Choose a name (e.g., `terraform-eks-drift-lock-table`).
   *   **Primary Key:** Must be `LockID` (Type: String).
   *   **Capacity Mode:** On-demand or provisioned (1 RCU/1 WCU is typically sufficient).

   *Example AWS CLI (replace placeholders):*
   ```bash
   aws dynamodb create-table --table-name YOUR_DYNAMODB_TABLE_NAME --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH --billing-mode PAY_PER_REQUEST --region YOUR_AWS_REGION
   # Or for provisioned throughput:
   # aws dynamodb create-table --table-name YOUR_DYNAMODB_TABLE_NAME --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1 --region YOUR_AWS_REGION
   ```

**3. Update `terraform/backend.tf`:**
   *   Open `terraform/backend.tf` and replace the placeholder values for `bucket`, `key`, `region`, and `dynamodb_table` with your actual resource names and desired state file path.

**4. Initialize Terraform:**
   Navigate to the `terraform` directory:
   ```bash
   cd terraform
   terraform init
   ```
   If you previously had local state (`terraform.tfstate` file), Terraform will ask if you want to migrate it to the new S3 backend. Answer `yes`.

<br/>

### Local Infrastructure Provisioning (After Backend Setup)

1.  **Navigate to the Terraform directory**:
    ```bash
    cd terraform
    ```
2.  **(Optional) Review the plan**:
    ```bash
    terraform plan
    ```
3.  **Apply the configuration**:
    ```bash
    terraform apply
    ```
    Confirm with `yes`. Note the output `sns_topic_drift_notifications_arn` and update your `.env` file if you haven't already (especially if you didn't know it beforehand).

<br/>

### Configure SNS Topic Subscriptions
*   After `terraform apply` successfully creates the SNS topic, go to the AWS SNS console.
*   Find the topic (e.g., `my-eks-drift-demo-drift-notifications`).
*   Create a subscription (e.g., email, SMS, Lambda) to receive notifications.

<br/>

### Run the Drift Detector Script Manually
1.  Ensure your `.env` file in the project root is correctly populated (especially `OPENAI_API_KEY`, `SNS_TOPIC_ARN`, `AWS_REGION`).
2.  Navigate to the `scripts` directory: `cd ../scripts` (if you were in `terraform`) or `cd scripts` (from project root).
3.  Execute: `python drift_detector.py`
4.  Check console output and your SNS subscription endpoint for notifications.

<br/>

### GitHub Actions Setup (for automated runs)

1.  **Push to GitHub**: Ensure the project code, including the configured `terraform/backend.tf` (with non-sensitive placeholders if you prefer, and rely on GitHub Actions variables for actual names, though direct naming in `backend.tf` is common), is pushed to your GitHub repository.

2.  **Configure GitHub Repository Secrets**:
    *   Go to `Settings > Secrets and variables > Actions` in your GitHub repository.
    *   **Recommended: AWS OIDC Setup (More Secure)**
        *   `AWS_OIDC_ROLE_ARN`: The ARN of the IAM Role GitHub Actions will assume. See "Setting up AWS OIDC with GitHub Actions" section below.
        *   `AWS_REGION`: Your target AWS region (e.g., `us-west-2`).
        *   `OPENAI_API_KEY`: Your OpenAI API key.
        *   `SNS_TOPIC_ARN`: The ARN of the SNS topic for notifications.
    *   **Fallback: Static AWS Credentials (Less Secure)**
        *   If not using OIDC, you'll need `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`. The workflow has commented-out sections for this.

3.  **Setting up AWS OIDC with GitHub Actions (Recommended)**:
    *   **In AWS IAM:**
        1.  Create an **Identity Provider (OIDC)**:
            *   Provider URL: `https://token.actions.githubusercontent.com`
            *   Audience: `sts.amazonaws.com`
        2.  Create an **IAM Role** for GitHub Actions:
            *   Trusted entity type: "Web identity".
            *   Identity provider: Choose the provider you just created.
            *   Audience: `sts.amazonaws.com`.
            *   (Optional but recommended) Add conditions to restrict which GitHub repositories/branches can assume this role (e.g., `token.actions.githubusercontent.com:sub: repo:YOUR_GITHUB_ORG/YOUR_REPO_NAME:ref:refs/heads/main`).
            *   Attach permissions policies: Grant the minimum necessary permissions for Terraform to plan and read resources, and for SNS publish. (e.g., `ReadOnlyAccess` for plan, plus `sns:Publish` to the specific topic. For `apply`, it would need more extensive permissions).
    *   **In GitHub Secrets:** Store the ARN of this IAM role as `AWS_OIDC_ROLE_ARN`.
    *   The workflow `.github/workflows/drift_check.yml` is pre-configured to attempt OIDC authentication using this role.

4.  **Enable and Monitor Workflow**:
    *   The workflow in `.github/workflows/drift_check.yml` is configured to run on a schedule (e.g., every 6 hours) and can also be triggered manually.
    *   Check the "Actions" tab in your GitHub repository to see workflow runs, logs, and uploaded artifacts (like `tfplan.json`).

## How it Works

1.  **Scheduled Execution**: GitHub Actions triggers the `drift_check.yml` workflow.
2.  **Environment Setup**: The workflow checks out the code, sets up Terraform and Python, and installs dependencies.
3.  **Drift Detection**: `drift_detector.py` is executed.
    *   It runs `terraform init` and `terraform plan -out=tfplan.binary` in the `terraform` directory.
    *   It then runs `terraform show -json tfplan.binary` to convert the plan to JSON.
4.  **Drift Parsing**: The script parses `tfplan.json` to identify any changes (creations, updates, deletions).
5.  **AI Analysis**:
    *   If drift is detected, the relevant parts of the plan are formatted into a prompt.
    *   This prompt is sent to the OpenAI API.
    *   The AI returns an analysis, impact assessment, and safety recommendation.
    *   The script then parses this AI response into a standardized action (e.g., `MANUAL_REVIEW`, `APPLY_SAFE`).
6.  **GitHub Actions Outputs**: The Python script sets outputs for the GitHub Actions workflow:
    *   `drift_detected`: (`true` or `false`)
    *   `ai_parsed_recommendation`: (e.g., `MANUAL_REVIEW`, `APPLY_SAFE`, `NO_DRIFT`, `AI_ANALYSIS_FAILED`)
7.  **Conditional Workflow Actions**: The GitHub Actions workflow can use these outputs:
    *   For example, it creates a GitHub Issue if drift is detected AND the `ai_parsed_recommendation` is `MANUAL_REVIEW`.
8.  **Notification**:
    *   An SNS message is published. The subject and body are now enhanced with the parsed AI recommendation for quicker insights.
    *   Subscribers to the SNS topic (e.g., DevOps team via email) receive the alert.
9.  **Logging & Artifacts**: Logs are available in the GitHub Actions run. The Terraform plan files are uploaded as artifacts for inspection.

## Potential Future Enhancements

*   **Auto-Remediation**:
    *   If the AI deems changes "safe to apply," the system could optionally run `terraform apply -auto-approve`. This requires careful consideration of safety and idempotency.
    *   Implement a more robust "safety score" or confidence level from the AI.
*   **Interactive Slack Bot**:
    *   Instead of just SNS, send alerts to a Slack channel.
    *   Allow operators to request more details or approve/reject remediation via Slack commands.
*   **Advanced AI Prompting**:
    *   Fine-tune prompts for more specific or nuanced analysis.
    *   Use LangChain or similar frameworks for more complex AI interactions or chains of thought.
*   **Cost Analysis**: Integrate AI to estimate the cost implications of planned changes.
*   **Security Vulnerability Assessment**: Use AI to check if planned changes introduce known security vulnerabilities (e.g., by analyzing security group changes).
*   **Dashboard**: A simple web UI to view drift history and AI recommendations.
*   **Terraform Backend Configuration**: Implement a proper Terraform backend (e.g., S3 with DynamoDB locking) for state management, especially crucial for CI/CD.
*   **Testing**: Add unit tests for the Python script and potentially integration tests for the Terraform configurations.

## Skills Demonstrated

This project aims to showcase skills in:

*   **Cloud Infrastructure Management**: AWS (EKS, VPC, IAM, SNS).
*   **Infrastructure as Code (IaC)**: Terraform.
*   **Automation & CI/CD**: GitHub Actions, Python scripting.
*   **AI/LLM Integration**: OpenAI API for intelligent decision support.
*   **DevOps Practices**: Drift detection, automated alerting, (conceptual) auto-healing.
*   **Security Awareness**: Managing secrets, IAM permissions.
*   **System Design**: Integrating multiple components into a cohesive system.

---

This `README.md` provides a comprehensive overview of the project. Remember to replace placeholders like `<repository_url>` and `<repository_name>` with your actual details.
You will also need to ensure the AWS IAM permissions for the GitHub Actions runner and your local setup are correctly configured for all the services Terraform and the Python script will interact with.
