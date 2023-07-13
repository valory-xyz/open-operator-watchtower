# Docker Compose deployment on AWS

Ensure that you have the required software:

- [AWS CLI](https://aws.amazon.com/cli/)
- [Terraform](https://developer.hashicorp.com/terraform)

Make the necessary adjustment to the Terraform scripts (`./infra/aws/docker-compose/`), and follow these steps:

1. **Clone this repository to your local machine.**
2. **Configure cloud credentials and service parameters.**

   1. Set up the AWS CLI. Configure your local machine to work with your AWS credentials (*AWS Access Key ID* and *AWS Secret Access Key*):

      ```bash
      aws configure
      ```

      You can check if it has been properly configured by examining the files

      ```bash
      cat ~/.aws/config
      cat ~/.aws/credentials
      ```

   2. Define the following environment variables. See the description of the variables in Step 2 in [this section](../README.md#deploy-the-service-using-github-actions):

      ```bash
      export TF_VAR_operator_ssh_pub_key_path=<path/to/your/ssh_public_key>
      export TFSTATE_S3_BUCKET=<your_aws_tfstate_s3_bucket>
      export SERVICE_REPO_URL=https://github.com/valory-xyz/decentralized-watchtower
      export SERVICE_ID=valory/decentralized_watchtower_goerli:0.1.0
      # export SERVICE_ID=valory/decentralized_watchtower:0.1.0
      # export SERVICE_ID=valory/decentralized_watchtower_gnosis:0.1.0
      export DEPLOYMENT_TYPE=docker
      export SERVICE_REPO_TAG=v0.1.0

      # Optional variables
      export GH_TOKEN=ghp_000000000000000000000000000000000000
      ```

   3. Populate the files with the service configuration parameters. See the description of the files in Step 2 in [this section](../README.md#deploy-the-service-using-github-actions):

      - `./config/keys.json`
      - `./config/service_vars.env`

3. **Deploy the infrastructure and the service to AWS.**
   1. Deploy the infrastructure:

      ```bash
      cd ./infra/aws/docker-compose/
      terraform init -backend-config="bucket=$TFSTATE_S3_BUCKET"
      terraform plan
      terraform apply
      ```

      Enter `yes` when prompted. You should see the the following output once the command finishes:

      ```text
      Apply complete! Resources: 10 added, 0 changed, 0 destroyed.

      Outputs:

      instance_id = <AWS_EC2_ID>
      instance_public_ip = <AWS_EC2_PUBLIC_IP>
      ```

      The instance will automatically install the [Open Autonomy](https://docs.autonolas.network/open-autonomy/) framework, together with a number of dependencies. You should wait until the AWS EC2 instance is ready (typically, less than 5 minutes). The command below will wait until it is ready:

      ```bash
      aws ec2 wait instance-status-ok --instance-ids <AWS_EC2_ID>
      ```

   2. Generate the service deployment script:

      ```bash
      # Position on the root of the repository
      cd ../../..
      ./scripts/generate_service_deployment.sh
      ```

      The script will generate the file `deploy_service.sh`, which contains the necessary commands to deploy the service in the AWS EC2 instance.
   3. Deploy the agent to the AWS EC2 instance:

      ```bash
      scp ./deploy_service.sh ubuntu@<AWS_EC2_PUBLIC_IP>:~ 
      ssh ubuntu@<AWS_EC2_PUBLIC_IP> 'nohup ~/deploy_service.sh > deploy_service.log 2>&1 &'
      ```

      You might need to indicate the SSH private key path using the `-i` option on the `scp` and `ssh` commands.

4. **Interact with the AWS EC2 instance.** See Step 4 in [this section](../README.md#deploy-the-service-using-github-actions).

5. **Destroy the infrastructure.**

   ```bash
   cd ./infra/aws/docker-compose/
   terraform destroy
   ```

   Enter `yes` when prompted. This will destroy the resources created on AWS. Alternatively, you can also remove the resources using the AWS Management Console.
