# AWS Fleet Maintenance & Secure Access Lab

This capstone lab demonstrates the most modern and secure operational patterns for the **AWS SysOps Administrator Associate**: managing a fleet of instances with zero SSH overhead and performing automated rolling updates.

## Architecture Overview

The system implements a secure, scalable, and automated fleet management model:

1.  **Identity-Based Access:** An IAM Role and Instance Profile grant instances the permissions for AWS Systems Manager (SSM). This enables **Session Manager**, allowing terminal access without SSH keys or open inbound ports.
2.  **Highly Available Network:** A custom VPC with multi-AZ subnets ensures the fleet is resilient to zone-level failures.
3.  **Dynamic Fleet Management:** An Auto Scaling Group (ASG) maintains a desired capacity of instances based on a versioned Launch Template.
4.  **Automated Maintenance:** The **ASG Instance Refresh** feature is configured to perform rolling updates of the entire fleet, ensuring zero downtime when updating AMIs or configuration.
5.  **Operational Observability:** An EventBridge (CloudWatch Events) rule monitors the status of fleet refreshes, providing visibility into the automated maintenance lifecycle.

## Key Components

-   **SSM Session Manager:** Secure, auditable terminal access via the AWS CLI or Console.
-   **Launch Template:** The versioned blueprint for fleet configuration.
-   **Auto Scaling Group:** The engine for fleet management and rolling updates.
-   **EventBridge Rule:** Monitors automated fleet maintenance events.

## Prerequisites

-   [Terraform](https://www.terraform.io/downloads.html)
-   [LocalStack Pro](https://localstack.cloud/)
-   [AWS CLI / awslocal](https://github.com/localstack/awscli-local)
-   [SSM Session Manager Plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html) (optional for CLI access)

## Deployment

1.  **Initialize and Apply:**
    ```bash
    terraform init
    terraform apply -auto-approve
    ```

## Verification & Testing

To observe the modern fleet management in action:

1.  **Verify Managed Instances:**
    Check that your instances are registered with Systems Manager:
    ```bash
    awslocal ssm describe-instance-information
    aws ssm describe-instance-information
    ```

2.  **Start a Secure Session (Conceptual):**
    In a real environment, you would access an instance without SSH:
    ```bash
    aws ssm start-session --target <INSTANCE_ID>
    ```

3.  **Perform an Instance Refresh:**
    Simulate a fleet-wide rolling update (e.g., after updating the Launch Template):
    ```bash
    awslocal autoscaling start-instance-refresh --auto-scaling-group-name ssm-managed-fleet
    aws autoscaling start-instance-refresh --auto-scaling-group-name ssm-managed-fleet
    ```

4.  **Monitor Refresh Status:**
    Track the progress of the rolling update:
    ```bash
    awslocal autoscaling describe-instance-refreshes --auto-scaling-group-name ssm-managed-fleet
    aws autoscaling describe-instance-refreshes --auto-scaling-group-name ssm-managed-fleet
    ```

## Cleanup

To tear down the infrastructure:
```bash
terraform destroy -auto-approve
```

---

💡 **Pro Tip: Using `aws` instead of `awslocal`**

If you prefer using the standard `aws` CLI without the `awslocal` wrapper or repeating the `--endpoint-url` flag, you can configure a dedicated profile in your AWS config files.

### 1. Configure your Profile
Add the following to your `~/.aws/config` file:
```ini
[profile localstack]
region = us-east-1
output = json
# This line redirects all commands for this profile to LocalStack
endpoint_url = http://localhost:4566
```

Add matching dummy credentials to your `~/.aws/credentials` file:
```ini
[localstack]
aws_access_key_id = test
aws_secret_access_key = test
```

### 2. Use it in your Terminal
You can now run commands in two ways:

**Option A: Pass the profile flag**
```bash
aws iam create-user --user-name DevUser --profile localstack
```

**Option B: Set an environment variable (Recommended)**
Set your profile once in your session, and all subsequent `aws` commands will automatically target LocalStack:
```bash
export AWS_PROFILE=localstack
aws iam create-user --user-name DevUser
```

### Why this works
- **Precedence**: The AWS CLI (v2) supports a global `endpoint_url` setting within a profile. When this is set, the CLI automatically redirects all API calls for that profile to your local container instead of the real AWS cloud.
- **Convenience**: This allows you to use the standard documentation commands exactly as written, which is helpful if you are copy-pasting examples from AWS labs or tutorials.
