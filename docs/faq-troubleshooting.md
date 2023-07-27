# FAQ and troubleshooting

Deployment issues using GitHub Actions often arise from incorrectly defined variables or secrets within the repository. While we have implemented various sanity checks for the necessary variables, there is a possibility that we may have overlooked certain aspects. We strongly advise you to thoroughly **review and ensure the proper definition of the variables and secrets, avoiding any trailing spaces, newlines, or other formatting issues.** Examining the logs of the workflow runs can provide valuable insights to help pinpoint the source of the issue.

## Variable overrides

<details>

<summary><b>How do service variable overrides work in GitHub Actions?</b></summary>

Service variables are defined in the file `./config/service_vars.env`. These variables contain the configuration that the particular service requires to run and will be exported to the deployed infrastructure.

In order to avoid exposing confidential information, you have the option to override the value of any confidential variable in that file by defining a GitHub secret or variable matching its name. It's important to note that you must still include the variable identifier in `./config/service_vars.env` (assigning a blank or placeholder value); otherwise, the variable will not be exported to the deployment. In other words, the deployment process **only** exports the variables present in `./config/service_vars.env`, overridden or not.

</details>

<details>

<summary><b>How does the override of the file <code>keys.json</code> work in Github Actions?</b></summary>

Similar to variable overrides, if you do not want to expose the the private keys of your agent(s) in the file `./config/keys.json`, you can create the GitHub secret `KEYS_JSON` and populate the contents. Note that the value of `KEYS_JSON` must be a valid JSON reflecting the desired contents of the file, for example:

```json
[
  {
    "address": "0x0000000000000000000000000000000000000000",
    "private_key": "0x0000000000000000000000000000000000000000000000000000000000000000"
  }
]
```

Moreover, to mitigate subtle formatting issues when displaying GitHub logs, we recommend that you inline this value before assigning it to `KEYS_JSON`, for example, run locally the following commands:

```bash
LOCAL_KEYS_JSON='[
  {
    "address": "0x0000000000000000000000000000000000000000",
    "private_key": "0x0000000000000000000000000000000000000000000000000000000000000000"
  }
]'
echo $LOCAL_KEYS_JSON
```

 Be careful when using third-party services or websites to format your key file.

</details>

<details>

<summary><b>Which variables are not allowed in the `service_vars.env` file when deploying using GitHub Actions?</b></summary>

For security reasons, the following variables will not be overridden with GitHub secrets or variables, even if present in the file `service_vars.env`:

- `AWS_ACCESS_KEY_ID`,
- `AWS_SECRET_ACCESS_KEY`,
- `OPERATOR_SSH_PRIVATE_KEY`,
- `GH_TOKEN`,
- `KEYS_JSON`,
- `KUBECONFIG`,
- `TFSTATE_S3_BUCKET`.

</details>

## SSH key pairs

<details>

<summary><b>Are passphrase-protected SSH keys supported?</b></summary>

No, currently the repository does not support passphrase-protected SSH keys.

</details>

<details>

<summary><b>What types of SSH keys are supported for AWS EC2 instances?</b></summary>

Please refer to the most up-to-date [AWS documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html) for the currently supported key pairs for Linux instances in Amazon EC2. As of the time of writing this guide, Amazon EC2 supports ED25519 and 2048-bit SSH-2 RSA keys.

You can use either of these commands to create a supported key pair (do not enter a passphrase):

   | To use a 2048-bit RSA key pair                | To use an ED25519 key pair                    |
   |-----------------------------------------------|-----------------------------------------------|
   | `ssh-keygen -t rsa -b 2048 -N  ""  -f id_rsa` | `ssh-keygen -t ed25519 -N  ""  -f id_ed25519` |

Alternatively, you can also use the [AWS Management Console to create a key pair](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/create-key-pairs.html).

</details>

## Terraform scripts

<details>

<summary id="deploy-different-region"><b>Can I deploy in an AWS region other than <code>us-east-2</code>?</b></summary>

If you wish to deploy on another AWS Region, you have to apply a number of changes in the corresponding Terraform scripts:

- Modify the `region` attribute in the `backend` block in the file `main.tf`.
- Modify the Terraform variable `deployment_region` in the file `variables.tf`.
- Provide a valid Amazon Machine Image (AMI) ID for that region (resource `aws_instance` in the file `main.tf`).

</details>

<details>

<summary><b>Terraform appears to be stuck when creating a specific resource. Should I forcefully cancel its execution?</b></summary>

It is normal for certain resources to take longer to create than others. For example, using the default parameters provided, a Docker Compose deployment will take about 6 minutes, whereas a Kubernetes cluster may take 15 minutes to complete. During this time, you may observe periodic waiting messages on the console.

It is important to note that each resource has an allowed timeout for creation. In normal circumstances, if Terraform is unable to create a resource within its allowed timeout, it will log an error on the console, save the current state of the infrastructure, and terminate. In such case, you can then use `terraform destroy` to remove the partially deployed infrastructure.

Forcefully terminating Terraform should only be considered as a **last resort option**, as doing so will not save the infrastructure state in the backend. This would require manual removal of the partially deployed infrastructure, which can be a laborious task.

</details>

<details>

<summary><b>What resources should I manually remove on AWS if Terraform crashes?</b></summary>

In case Terraform encounters a crash or forceful termination, it is essential to properly clean up your AWS resources to avoid incurring unnecessary costs (recall that resources are deployed in the `us-east-2` by default). While this list is not exhaustive, it covers key resources you should consider removing. Additionally, you may want to identify and delete other resources as necessary, in the region(s) where you have deployed:

- EC2 Auto Scaling Groups
- EC2 Load Balancers and Target Groups
- EC2 Instances
- EC2 Launch Templates
- EC2 Security Groups
- EC2 Network Interfaces
- VPCs (incl. subnets, route tables, gateways, etc.)
- VPC Security Groups
- Route 53 records
- EFS file systems

</details>

<details>

<summary><b>Are the Terraform scripts configured to enable state locking in the AWS S3 bucket?</b></summary>

No, for simplicity, the Terraform scripts provided in this repository do not implement [state locking](https://developer.hashicorp.com/terraform/language/state/locking). Therefore, it is important to **ensure that the script is not executed concurrently by different users** in order to prevent potential issues. You might consider implementing state locking in the AWS S3 bucket using [DyanomDB](https://aws.amazon.com/dynamodb/). See for example [this](https://terraformguru.com/terraform-real-world-on-aws-ec2/20-Remote-State-Storage-with-AWS-S3-and-DynamoDB/) or [this](https://blog.gruntwork.io/how-to-manage-terraform-state-28f5697e68fa) tutorial.

</details>

## Known issues

- When deploying the service using GitHub Actions, occasionally, the AWS EC2 instance might notify premature provision completion. This may cause that the service deployment script executed in the AWS EC2 fails to find the required dependencies. You can identify this situation when you connect to the instance and don't see a `service_screen_session` session:

  ```bash
  ssh -i /path/to/private_key ubuntu@<AWS_EC2_PUBLIC_IP>
  screen -ls

  # You should see an output similar to this:
  #
  # There is a screen on:
  #  10054.service_screen_session (01/01/23 08:00:00) (Detached)
  # 1 Socket in /run/screen/S-ubuntu.
  ```

  If you don't see the `screen` session running, execute the service deployment script manually:

  ```bash
  ./deploy_service.sh
  ```
