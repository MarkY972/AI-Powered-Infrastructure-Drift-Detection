## Agent Instructions for AI-Powered Infrastructure Drift Detection Project

Welcome, AI Agent! This document provides guidance for working on this project.

### Project Goal
The primary goal of this project is to deploy and manage a serverless application that can detect drift in its own infrastructure. The drift detection is performed by a Lambda function that runs on a schedule, and the deployment is automated via GitHub Actions.

### Key Components
- **Terraform (`./terraform/`)**: Defines the entire AWS infrastructure, including:
    - `lambda.tf`: The core drift detection Lambda function and its scheduler.
    - `sample_app.tf`: A sample serverless application (API Gateway + Lambda) to be monitored.
    - `sns.tf`: The SNS topic for notifications.
- **Python Script (`./scripts/drift_detector.py`)**:
    - The core logic for the drift detection Lambda.
- **GitHub Actions (`.github/workflows/drift_check.yml`)**:
    - A deployment pipeline that triggers on push to `main`.
    - **Packaging**: It creates `drift_detector.zip` and `hello_world.zip` for the Lambda functions.
    - **Deployment**: It runs `terraform apply` to deploy the infrastructure.
- **Dependencies (`./requirements.txt`)**: Python package dependencies.
- **Environment Configuration (`.env.example`, used as `.env`)**: For local development, stores API keys and other configurations.

### Development Guidelines

1.  **Terraform Changes**:
    *   Always run `terraform fmt` in the `terraform` directory after making changes to HCL files.
    *   Ensure any new resources or significant changes are reflected in `variables.tf` and `outputs.tf` as appropriate.
    *   If adding resources that require new IAM permissions, document them.
    *   The target AWS environment is primarily for an EKS cluster. Keep this context in mind.

2.  **Python Script (`drift_detector.py`)**:
    *   Maintain clear logging throughout the script.
    *   Ensure robust error handling, especially for external calls (Terraform CLI, OpenAI API, AWS SDK).
    *   When interacting with the AI model:
        *   The prompt is key. Ensure it's clear, concise, and asks for actionable information.
        *   The current prompt in `analyze_drift_with_ai` provides a good template.
    *   SNS messages should be informative and include key details from the drift and AI analysis.
    *   If adding new environment variables, update `.env.example` and document their purpose.

3.  **GitHub Actions (`drift_check.yml`)**:
    *   Workflows should be efficient and secure.
    *   Clearly define required secrets and environment variables.
    *   Ensure artifacts (like Terraform plans) are uploaded for debugging.
    *   If modifying permissions, adhere to the principle of least privilege.

4.  **Security**:
    *   Never commit secrets (API keys, sensitive credentials) directly to the repository. Use environment variables and GitHub secrets.
    *   Be mindful of IAM permissions granted to the Terraform execution role and the GitHub Actions runner.

5.  **Testing (Future Consideration)**:
    *   Unit tests for Python script logic (e.g., plan parsing) would be beneficial.
    *   Integration tests that run against a temporary AWS environment could be considered for more complex changes.

### AI-Specific Instructions

*   **Understanding Drift**: Your primary analysis task is to interpret the `terraform plan` output. Focus on:
    *   What resources are changing?
    *   What are the actions (create, update, delete, replace)?
    *   What is the potential impact of these changes on a running serverless application and its workloads?
*   **Safety Recommendations**: When asked to recommend if changes are "safe to apply automatically," consider:
    *   **Destructive actions** (delete, replace) are generally unsafe unless very specific conditions are met.
    *   **Updates to critical components** (Lambda function code, IAM roles, triggers) usually require manual review.
    *   **Non-disruptive changes** (adding tags, updating certain metadata) might be considered safe.
    *   Always err on the side of caution. If unsure, recommend manual review.
*   **Clarity**: Your analysis and recommendations should be clear, concise, and easily understandable by a DevOps engineer.

### Current Plan and Next Steps
Refer to the active plan provided by the user or your own internal planning tools. The project is iterative, and features like auto-remediation or more sophisticated alerting are potential future enhancements.

Thank you for your assistance!
