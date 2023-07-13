# Kubernetes deployment on AWS

The following guide describes how to deploy a [Typhoon](https://typhoon.psdn.io/) Kubernetes cluster on AWS and deploy your service. The cluster uses the [AWS EFS](https://aws.amazon.com/efs/) file system.

## Configure your domain

To deploy a Kubernetes cluster you need a domain name and an AWS hosted zone.

1. In case you don't have one, register a domain name. You can [register the domain through AWS](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/domain-register.html), or use any other registrar of your choice, like [GoDaddy](https://www.godaddy.com/), [OVH](https://www.ovhcloud.com/), etc.
2. Create a [public hosted zone on AWS Route 53](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/CreatingHostedZone.html). Use you registered domain name.
3. Open the [hosted zone details](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/GetInfoAboutHostedZone.html) and note down:
   - the hosted zone ID, and
   - the name servers.
4. Go to your registrar and update the nameservers (NS entries) of your domain to match the nameservers of the AWS hosted zone

> **Note** <br />
> **Generally, it may take anywhere from a few minutes to several hours for the changes on the DNS to propagate over the Internet. In some cases, it can take up to 24-48 hours for the changes to fully propagate globally. You can track DNS propagation, e.g., using [DNS Checker](https://dnschecker.org/).**

## Deploy the cluster

Ensure that you have the required software:

- [AWS CLI](https://aws.amazon.com/cli/)
- [Terraform](https://developer.hashicorp.com/terraform)
- [Kubernetes CLI](https://kubernetes.io/docs/tasks/tools/)
- [Open Autonomy](https://docs.autonolas.network/open-autonomy/guides/set_up/)

Make the necessary adjustment to the Terraform scripts `./infra/aws/kubernetes/` (or use `TF_VARs` as shown below), and follow these steps:

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
      export TF_VAR_hosted_zone=<your_aws_route53_hosted_zone_name>
      export TF_VAR_hosted_zone_id=<your_aws_route53_hosted_zone_id>
      export TFSTATE_S3_BUCKET=<your_aws_tfstate_s3_bucket>
      export SERVICE_REPO_URL=https://github.com/valory-xyz/decentralized-watchtower

      # One of the following
      export SERVICE_ID=valory/decentralized_watchtower_goerli:0.1.0
      # export SERVICE_ID=valory/decentralized_watchtower:0.1.0
      # export SERVICE_ID=valory/decentralized_watchtower_gnosis:0.1.0
      
      export DEPLOYMENT_TYPE=kubernetes
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
      cd ./infra/aws/kubernetes/
      terraform init -backend-config="bucket=$TFSTATE_S3_BUCKET"
      terraform plan -target=module.aws_cluster
      terraform apply -target=module.aws_cluster
      terraform plan
      terraform apply
      export KUBECONFIG=$PWD/kubefiles/kubeconfig
      ```

      Enter `yes` when prompted (twice, one per each `terraform apply`). You should see the the following output once the command finishes:

      ```text
      Apply complete! Resources: N added, 0 changed, 0 destroyed.

      Outputs:

      worker_security_groups = [
      "sg-01234567890abcdef",
      ]
      worker_target_group_http = "arn:aws:elasticloadbalancing:us-east-2:012345678901:targetgroup/as-cluster-workers-http/01234567890abcde"
      ```

      Confirm that the cluster has been successfully created:

      ```bash
      kubectl get nodes
      ```

      You should see

      ```text
      NAME             STATUS   ROLES    AGE     VERSION
      ip-10-0-16-147   Ready    <none>   6m00s   v1.27.2
      ip-10-0-19-178   Ready    <none>   6m00s   v1.27.2
      ip-10-0-38-203   Ready    <none>   3m00s   v1.27.2
      ip-10-0-38-209   Ready    <none>   0m30s   v1.27.2
      ```

   2. Generate the service deployment script:

      ```bash
      # Position on the root of the repository
      cd ../../..
      ./scripts/generate_service_deployment.sh
      ```

      The script will generate the file `deploy_service.sh`, which contains the necessary commands to deploy the service to the cluster.

   3. Deploy the service to the Kubernetes cluster. Recall that you need the [Open Autonomy](https://docs.autonolas.network/open-autonomy/guides/set_up/) framework to run this command.

      ```bash
      # Remove previous deployments
      sudo rm -rf fetched_service

      ./deploy_service.sh
      ```

4. **Interact with the cluster.** You can either create a dashboard or interact directly via the `kubectl` command. Ensure that the environment variable `KUBECONFIG` points to the `kubeconfig` file pointed in the previous section.

   1. Create and connect to a dashboard.

      ```bash
      kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
      kubectl apply -f ./infra/aws/kubernetes/dashboard-admin.yaml 
      kubectl -n kubernetes-dashboard create token admin-user
      # Note down the Bearer Token created
      kubectl proxy
      ```

      You can now connect to the dashboard by opening a browser on [http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/](http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/). Use the Bearer Token created in the previous step to access the dashboard.

   2. Interact via `kubectl`, for example:

      ```bash
      # Get the agent-node-i pods' name
      kubectl get pods

      # Connect to the aea agent container
      kubectl exec -it <agent-node-i-pod-name> -c aea -- /bin/sh

      # Connect to the Tendermint node
      kubectl exec -it <agent-node-i-pod-name> -c node0 -- /bin/sh
      ```

      You can now access the logs, which are mounted on the root folder `/logs`.

5. **Destroy the infrastructure.**

   ```bash
   cd ./infra/aws/kubernetes/
   terraform destroy
   ```

   Enter `yes` when prompted. This will destroy the resources created on AWS. Alternatively, you can also remove the resources using the AWS Management Console.
