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
│   └── outputs.tf              # Terraform outputs
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
        *   `SNS_TOPIC_ARN`: (Optional for initial run, will be output by Terraform) The ARN of the SNS topic.
        *   `AWS_REGION`: (Optional, defaults to us-west-2 in script if not set) Your target AWS region.
        *   You might also need to set `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` if not configured globally via AWS CLI profiles.

4.  **Provision Infrastructure with Terraform**:
    *   Navigate to the Terraform directory:
        ```bash
        cd terraform
        ```
    *   Initialize Terraform:
        ```bash
        terraform init
        ```
    *   (Optional) Review the plan:
        ```bash
        terraform plan
        ```
    *   Apply the configuration:
        ```bash
        terraform apply
        ```
        Confirm with `yes`. Note the output `sns_topic_drift_notifications_arn` and update your `.env` file if you haven't already.

5.  **Configure SNS Topic Subscriptions**:
    *   Go to the AWS SNS console.
    *   Find the topic created by Terraform (e.g., `my-eks-drift-demo-drift-notifications`).
    *   Create a subscription (e.g., email, SMS, Lambda) to receive notifications.

6.  **Run the Drift Detector Script Manually**:
    *   Navigate back to the `scripts` directory (or project root):
        ```bash
        cd ../scripts  # Or cd .. if already in project root
        ```
    *   Ensure your `.env` file is in the project root or accessible.
    *   Execute the script:
        ```bash
        python drift_detector.py
        ```
    *   Check the console output for logs and any SNS notifications you've configured.

### GitHub Actions Setup (for automated runs)

1.  **Push to GitHub**: Ensure the project code is pushed to your GitHub repository.
2.  **Configure Repository Secrets**:
    *   In your GitHub repository, go to `Settings > Secrets and variables > Actions`.
    *   Add the following repository secrets:
        *   `AWS_ACCESS_KEY_ID`: Your AWS IAM user access key ID.
        *   `AWS_SECRET_ACCESS_KEY`: Your AWS IAM user secret access key.
        *   `OPENAI_API_KEY`: Your OpenAI API key.
        *   `SNS_TOPIC_ARN`: The ARN of the SNS topic created by Terraform.
        *   (Optional) `AWS_REGION`: If you want to override the default in the workflow.
    *   **Important IAM Permissions**: The AWS credentials used must have sufficient permissions for Terraform to read AWS resources (for `plan`) and for `boto3` to publish to the SNS topic. If you later implement auto-apply, it will need write permissions.

3.  **Enable and Monitor Workflow**:
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
6.  **Notification**:
    *   An SNS message is published containing the drift details and the AI's analysis.
    *   Subscribers to the SNS topic (e.g., DevOps team via email) receive the alert.
7.  **Logging & Artifacts**: Logs are available in the GitHub Actions run. The Terraform plan files are uploaded as artifacts for inspection.

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
