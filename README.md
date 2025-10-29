# AI-Powered Infrastructure Drift Detection for Serverless Applications

This project demonstrates a system that periodically checks cloud infrastructure (provisioned by Terraform on AWS) for drift and uses an AI agent to evaluate the drift and recommend actions. The primary focus is on a serverless application using AWS Lambda.

## Project Overview

The system is designed to:

1.  **Deploy Infrastructure**: Use GitHub Actions to deploy a serverless application, including a drift detection Lambda function, to AWS using Terraform.
2.  **Scheduled Drift Detection**: The drift detection Lambda function runs on a schedule (defined by a CloudWatch Event Rule) to periodically check the infrastructure for drift.
3.  **AI-Powered Analysis**: When drift is detected, the Lambda function sends the details to an AI model for analysis, impact assessment, and a recommendation.
4.  **Automated Notification**: The AI's analysis is then sent to an SNS topic to notify operators.

## Key Features & Technologies

*   **Infrastructure as Code (IaC)**: [Terraform](https://www.terraform.io/) for provisioning and managing all AWS resources.
*   **Cloud Provider**: [Amazon Web Services (AWS)](https://aws.amazon.com/), featuring Lambda, API Gateway, IAM, SNS, and CloudWatch Events.
*   **Drift Detection Engine**: A Python script packaged as an AWS Lambda function, which runs `terraform plan` to detect drift.
*   **AI Integration**: [OpenAI API](https://openai.com/docs) (GPT models) for intelligent drift analysis.
*   **CI/CD**: [GitHub Actions](https://github.com/features/actions) for automated deployment of the entire serverless application.
*   **Serverless Scheduling**: [AWS CloudWatch Events](https://aws.amazon.com/cloudwatch/features/) to trigger the drift detection Lambda on a regular schedule.
*   **Notifications**: [AWS Simple Notification Service (SNS)](https://aws.amazon.com/sns/) for alerting.
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
│   ├── lambda.tf               # Terraform configuration for the AWS Lambda function and related resources
│   ├── main.tf                 # Main Terraform provider configuration
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
*   **AWS CLI**: Configured with credentials that have permissions to create and manage Lambda, IAM, SNS, and related resources.
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

### GitHub Actions Deployment

1.  **Push to `main` Branch**: The GitHub Actions workflow is configured to trigger on any push to the `main` branch.
2.  **Configure Repository Secrets**:
    *   In your GitHub repository, go to `Settings > Secrets and variables > Actions`.
    *   Add the following repository secrets:
        *   `AWS_ACCESS_KEY_ID`: Your AWS IAM user access key ID.
        *   `AWS_SECRET_ACCESS_KEY`: Your AWS IAM user secret access key.
        *   `OPENAI_API_KEY`: Your OpenAI API key.
3.  **Monitor the Workflow**:
    *   Check the "Actions" tab in your GitHub repository to see the deployment workflow runs and logs.

## How it Works

1.  **CI/CD Pipeline**: When code is pushed to the `main` branch, a GitHub Actions workflow is triggered.
2.  **Lambda Packaging**: The workflow creates two zip files:
    *   `drift_detector.zip`: Contains the `drift_detector.py` script, its Python dependencies, and the entire `/terraform` directory.
    *   `hello_world.zip`: Contains a simple "Hello, World" Lambda function.
3.  **Terraform Deployment**: The workflow then runs `terraform apply` to deploy all the resources defined in the `.tf` files, using the zip files as the source for the Lambda functions.
4.  **Scheduled Drift Scan**: The deployed CloudWatch Event Rule triggers the drift detection Lambda on a fixed schedule.
5.  **AI-Powered Analysis & Notification**: The Lambda function runs `terraform plan`, and if drift is detected, it sends the plan to the OpenAI API for analysis and publishes the results to an SNS topic.

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
*   **Security Vulnerability Assessment**: Use AI to check if planned changes introduce known security vulnerabilities.
*   **Dashboard**: A simple web UI to view drift history and AI recommendations.
*   **Terraform Backend Configuration**: Implement a proper Terraform backend (e.g., S3 with DynamoDB locking) for state management, especially crucial for CI/CD.
*   **Testing**: Add unit tests for the Python script and potentially integration tests for the Terraform configurations.

## Skills Demonstrated

This project aims to showcase skills in:

*   **Cloud Infrastructure Management**: AWS (Lambda, IAM, SNS).
*   **Infrastructure as Code (IaC)**: Terraform.
*   **Automation & CI/CD**: GitHub Actions, Python scripting.
*   **AI/LLM Integration**: OpenAI API for intelligent decision support.
*   **DevOps Practices**: Drift detection, automated alerting, (conceptual) auto-healing.
*   **Security Awareness**: Managing secrets, IAM permissions.
*   **System Design**: Integrating multiple components into a cohesive system.

---

This `README.md` provides a comprehensive overview of the project. Remember to replace placeholders like `<repository_url>` and `<repository_name>` with your actual details.
You will also need to ensure the AWS IAM permissions for the GitHub Actions runner and your local setup are correctly configured for all the services Terraform and the Python script will interact with.
