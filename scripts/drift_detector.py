import json
import subprocess
import os
import logging
import openai
import boto3
from botocore.exceptions import ClientError

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

TERRAFORM_DIR = os.path.join(os.path.dirname(__file__), '..', 'terraform')
PLAN_FILE = "tfplan.json" # Output plan file as JSON
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
SNS_TOPIC_ARN = os.getenv("SNS_TOPIC_ARN") # Get SNS topic ARN from environment variable

def get_sns_client():
    """Initializes and returns the Boto3 SNS client."""
    try:
        aws_region = os.getenv("AWS_REGION", "us-west-2") # Default region if not set
        client = boto3.client('sns', region_name=aws_region)
        return client
    except Exception as e:
        logging.error(f"Failed to initialize Boto3 SNS client: {e}")
        return None

def publish_sns_message(sns_client, topic_arn, subject, message):
    """
    Publishes a message to the specified SNS topic.

    Args:
        sns_client: Initialized Boto3 SNS client.
        topic_arn (str): ARN of the SNS topic.
        subject (str): Subject of the message.
        message (str): Body of the message.

    Returns:
        bool: True if successful, False otherwise.
    """
    if not sns_client:
        logging.error("SNS client not available. Cannot publish message.")
        return False
    if not topic_arn:
        logging.warning("SNS_TOPIC_ARN not set. Skipping SNS notification.")
        return False

    try:
        response = sns_client.publish(
            TopicArn=topic_arn,
            Subject=subject,
            Message=message,
            MessageStructure='string' # Or 'json' if you want to send a JSON object
        )
        logging.info(f"Message published to SNS topic {topic_arn}. Message ID: {response.get('MessageId')}")
        return True
    except ClientError as e:
        logging.error(f"Failed to publish message to SNS topic {topic_arn}: {e}")
        return False
    except Exception as e:
        logging.error(f"An unexpected error occurred while publishing to SNS: {e}")
        return False

def get_openai_client():
    """Initializes and returns the OpenAI client if the API key is available."""
    if not OPENAI_API_KEY:
        logging.warning("OPENAI_API_KEY not found in environment variables. AI analysis will be skipped.")
        return None
    try:
        client = openai.OpenAI(api_key=OPENAI_API_KEY)
        return client
    except Exception as e:
        logging.error(f"Failed to initialize OpenAI client: {e}")
        return None

def run_terraform_plan():
    """
    Runs 'terraform init' and 'terraform plan' in the specified Terraform directory
    and saves the plan output as JSON.

    Returns:
        str: Path to the JSON plan file if successful, None otherwise.
    """
    try:
        logging.info(f"Changing directory to {TERRAFORM_DIR}")
        os.chdir(TERRAFORM_DIR)

        logging.info("Running 'terraform init'...")
        init_process = subprocess.run(["terraform", "init", "-input=false", "-no-color"],
                                      capture_output=True, text=True, check=True)
        logging.info("Terraform init successful.")
        logging.debug(f"Terraform init stdout: {init_process.stdout}")

        plan_output_path = os.path.join(TERRAFORM_DIR, PLAN_FILE)
        logging.info(f"Running 'terraform plan -out={PLAN_FILE}.binary'...") # Plan first to a binary file
        plan_process = subprocess.run(
            ["terraform", "plan", "-input=false", "-no-color", f"-out={PLAN_FILE}.binary"],
            capture_output=True, text=True, check=True
        )
        logging.info("Terraform plan successful.")
        logging.debug(f"Terraform plan stdout: {plan_process.stdout}")

        logging.info(f"Converting plan to JSON: 'terraform show -json {PLAN_FILE}.binary' > {plan_output_path}")
        with open(plan_output_path, "w") as f_out:
            show_process = subprocess.run(
                ["terraform", "show", "-json", f"{PLAN_FILE}.binary"],
                capture_output=True, text=True, check=True, stdout=f_out
            )
        logging.info(f"Terraform show (JSON conversion) successful. Output at {plan_output_path}")

        return plan_output_path

    except subprocess.CalledProcessError as e:
        logging.error(f"Terraform command failed: {e.cmd}")
        logging.error(f"Stdout: {e.stdout}")
        logging.error(f"Stderr: {e.stderr}")
        return None
    except FileNotFoundError:
        logging.error("Terraform command not found. Ensure Terraform is installed and in PATH.")
        return None
    except Exception as e:
        logging.error(f"An unexpected error occurred: {e}")
        return None
    finally:
        # Go back to the original directory if needed, though for GitHub Actions this might not be strictly necessary
        # For local execution, it's good practice.
        os.chdir(os.path.join(os.path.dirname(__file__), '..'))


def parse_terraform_plan(plan_file_path):
    """
    Parses the JSON output of 'terraform plan' to detect drift.

    Args:
        plan_file_path (str): Path to the JSON plan file.

    Returns:
        dict: A dictionary containing information about the drift,
              or None if no drift or an error occurs.
              Example: {"has_drift": True, "changes": [...]}
    """
    if not plan_file_path or not os.path.exists(plan_file_path):
        logging.error(f"Plan file not found at {plan_file_path}")
        return None

    try:
        with open(plan_file_path, 'r') as f:
            plan_data = json.load(f)

        # Drift is indicated by the "resource_changes" array.
        # Other indicators could be "output_changes" or "planned_values" (for create/destroy)

        resource_changes = plan_data.get("resource_changes", [])
        output_changes = plan_data.get("output_changes", {}) # Output changes are a dict

        drift_details = {
            "has_drift": False,
            "summary": "No changes detected.",
            "resource_changes_count": 0,
            "output_changes_count": 0,
            "changes": []
        }

        if resource_changes:
            drift_details["has_drift"] = True
            drift_details["resource_changes_count"] = len(resource_changes)
            for change in resource_changes:
                change_summary = {
                    "address": change.get("address"),
                    "type": change.get("type"),
                    "name": change.get("name"),
                    "actions": change.get("change", {}).get("actions", [])
                }
                # Add more details if needed, like before and after values
                # change_summary["before"] = change.get("change", {}).get("before")
                # change_summary["after"] = change.get("change", {}).get("after_unknown") # or "after"
                drift_details["changes"].append(change_summary)

        if output_changes: # Check if output_changes dictionary is not empty
            drift_details["has_drift"] = True # Also consider output changes as drift
            drift_details["output_changes_count"] = len(output_changes)
            for output_name, change in output_changes.items():
                 drift_details["changes"].append({
                     "address": f"output.{output_name}",
                     "type": "output",
                     "name": output_name,
                     "actions": change.get("actions", [])
                 })


        if drift_details["has_drift"]:
            drift_details["summary"] = (
                f"Drift detected: {drift_details['resource_changes_count']} resource change(s) "
                f"and {drift_details['output_changes_count']} output change(s) planned."
            )
            logging.info(drift_details["summary"])
        else:
            logging.info("No drift detected in the plan.")

        return drift_details

    except json.JSONDecodeError as e:
        logging.error(f"Error decoding JSON from plan file: {e}")
        return None
    except Exception as e:
        logging.error(f"Error parsing Terraform plan: {e}")
        return None

def handler(event, context):
    logging.info("Starting Terraform drift detection from Lambda...")

    # In Lambda, the current working directory is /var/task. The terraform files are in a subdirectory.
    terraform_dir = "/var/task/terraform"
    plan_file = run_terraform_plan(terraform_dir)

    if plan_file:
        logging.info(f"Terraform plan generated: {plan_file}")
        drift_info = parse_terraform_plan(plan_file)

        if drift_info:
            logging.info("Drift detection summary:")
            logging.info(json.dumps(drift_info, indent=2))
            ai_summary = None  # Initialize ai_summary

            if drift_info["has_drift"]:
                logging.info("Drift detected. Attempting AI analysis...")
                ai_client = get_openai_client()
                if ai_client:
                    ai_summary = analyze_drift_with_ai(ai_client, drift_info)
                    if ai_summary:
                        logging.info("AI Analysis Summary:")
                        logging.info(ai_summary)
                    else:
                        logging.warning("AI analysis failed or returned no summary.")
                else:
                    logging.warning("OpenAI client not available. Skipping AI analysis.")

                # Send SNS notification about the drift
                sns_client = get_sns_client()
                if sns_client and SNS_TOPIC_ARN:
                    subject = f"Infrastructure Drift Detected: {drift_info.get('summary', 'Unknown drift')}"
                    message_body = f"Drift Details:\n{json.dumps(drift_info, indent=2)}\n\n"
                    if ai_summary:
                        message_body += f"AI Analysis:\n{ai_summary}"
                    else:
                        message_body += "AI analysis was not available or failed."
                    publish_sns_message(sns_client, SNS_TOPIC_ARN, subject, message_body)
            else:
                logging.info("No drift. All good!")
        else:
            logging.error("Failed to parse Terraform plan.")
            sns_client = get_sns_client()
            if sns_client and SNS_TOPIC_ARN:
                publish_sns_message(sns_client, SNS_TOPIC_ARN, "Drift Detection Error: Parse Failure", "Failed to parse the Terraform plan. Check logs for details.")
    else:
        logging.error("Failed to generate Terraform plan.")
        sns_client = get_sns_client()
        if sns_client and SNS_TOPIC_ARN:
            publish_sns_message(sns_client, SNS_TOPIC_ARN, "Drift Detection Error: Plan Generation Failure", "Failed to generate the Terraform plan. Check logs for details.")

    return {
        'statusCode': 200,
        'body': json.dumps('Drift detection complete.')
    }

def analyze_drift_with_ai(client, drift_info):
    """
    Sends drift information to an OpenAI model and returns its analysis.

    Args:
        client: OpenAI API client.
        drift_info (dict): Parsed drift information from Terraform plan.

    Returns:
        str: AI-generated summary and recommendation, or None if an error occurs.
    """
    if not client:
        logging.error("OpenAI client is not initialized.")
        return None

    if not drift_info or not drift_info.get("has_drift"):
        logging.info("No drift information to analyze.")
        return "No drift detected based on the provided plan."

    # Prepare the prompt for the AI
    # We can customize this prompt to be more specific about what we expect.
    prompt_changes = []
    for change in drift_info.get("changes", []):
        prompt_changes.append(
            f"- Resource: {change.get('address')}\n"
            f"  Type: {change.get('type')}\n"
            f"  Name: {change.get('name')}\n"
            f"  Actions: {', '.join(change.get('actions', []))}"
        )

    changes_str = "\n".join(prompt_changes)

    prompt = f"""Terraform Plan Analysis:
The following drift has been detected in the infrastructure:

{changes_str}

Total resource changes: {drift_info.get('resource_changes_count', 0)}
Total output changes: {drift_info.get('output_changes_count', 0)}

Please analyze this drift.
Provide a concise summary of the changes.
For each change, assess its potential impact (low, medium, high).
Recommend whether it's safe to apply these changes automatically.
If not safe, explain why and suggest manual review steps.
Consider that this infrastructure is for a serverless application running on AWS Lambda.
Output format should be clear and actionable. For example:

Summary: [Your concise summary]
Impact Assessment:
  - [Resource Address 1]: [Impact Level (Low/Medium/High)] - [Brief Justification]
  - [Resource Address 2]: [Impact Level (Low/Medium/High)] - [Brief Justification]
Recommendation: [Safe to apply / Requires manual review]
Justification: [Explanation for recommendation]
Manual Review Steps (if any): [Steps]

"""

    try:
        logging.info("Sending drift information to OpenAI for analysis...")
        response = client.chat.completions.create(
            model="gpt-3.5-turbo", # Or "gpt-4" if you have access and prefer it
            messages=[
                {"role": "system", "content": "You are an expert DevOps engineer specializing in Terraform and AWS Lambda. Your task is to analyze Terraform plan outputs for infrastructure drift."},
                {"role": "user", "content": prompt}
            ],
            temperature=0.5, # Adjust for creativity vs. determinism
            max_tokens=500 # Adjust as needed
        )

        ai_response = response.choices[0].message.content.strip()
        logging.info("Received analysis from OpenAI.")
        return ai_response

    except openai.APIError as e:
        logging.error(f"OpenAI API Error: {e}")
        return None
    except Exception as e:
        logging.error(f"An unexpected error occurred during AI analysis: {e}")
        return None

