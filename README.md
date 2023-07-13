<p align="center">
   <img src="./docs/images/open-operator-logo.svg" width=300>
</p>

<h1 align="center" style="margin-bottom: 0;">
    Open Operator
    <br><sub>Decentralized Watchtower Service</sub>
    <br />
    <a href="https://github.com/valory-xyz/open-operator-watchtower/blob/main/LICENSE"><img alt="License: Apache-2.0" src="https://img.shields.io/github/license/valory-xyz/open-operator-watchtower"></a>
    <a href="https://aws.amazon.com/"><img alt="Cloud: AWS" src="https://img.shields.io/badge/cloud-AWS-orange"></a>
    <!-- <a href="https://docs.docker.com/compose/"><img alt="Deployment: Docker Compose" src="https://img.shields.io/badge/deployment-Docker%20Compose-blue"></a> -->
    <a href="https://pypi.org/project/open-autonomy/0.10.8/"><img alt="Framework: Open Autonomy 0.10.8" src="https://img.shields.io/badge/framework-Open%20Autonomy%200.10.8-blueviolet"></a>
    <!-- <a href="https://github.com/valory-xyz/open-operator-watchtower/releases/latest">
    <img alt="Latest release" src="https://img.shields.io/github/v/release/valory-xyz/open-operator-watchtower"></a> -->
</h1>

This repository contains tooling to deploy the [Decentralized Watchtower Service](https://github.com/valory-xyz/decentralized-watchtower), built with the [Open Autonomy framework](https://docs.autonolas.network/open-autonomy/), on the Amazon Web Services (AWS) cloud. The repository is designed to facilitate the deployment process through Terraform and [GitHub actions](https://github.com/features/actions).

<p align="center">
   <img src="./docs/images/deploy-steps.svg">
</p>

You can also clone the repository locally on your machine and execute the deployment steps manually.

There are two types of deployment available:

- **Docker Compose:** The agent will be run through Docker Compose within a [`screen`](https://www.gnu.org/software/screen/) session in a single [AWS EC2](https://aws.amazon.com/ec2/) instance.
- **Kubernetes:** The agent will be running in a Kubernetes cluster composed of several worker and controller [AWS EC2](https://aws.amazon.com/ec2/) instances.

By default, the deployments run in the AWS Region `us-east-2`. Read our FAQ to learn how to [deploy in a different region](./docs/faq-troubleshooting.md#deploy-different-region).

> **Warning** <br />
> **Please note that deploying services in AWS using this repository may result in costs being incurred in your AWS account. These costs can include, but are not limited to, EC2 instance usage and cloud storage.**
>
> **Before proceeding with any deployment, it is important that you thoroughly review and understand the pricing details of the services involved. We recommend consulting the [AWS documentation](https://aws.amazon.com/pricing/) and enabling appropriate billing and [cost management](https://docs.aws.amazon.com/cost-management/latest/userguide/what-is-costmanagement.html) measures to effectively monitor and control your expenses.**

## Prerequisites

1. **Set up your AWS account.** Sign in to the AWS Management Console and configure the following parameters.

   1. In case you don't have one, you need to create an IAM user with an access key. Within the AWS Management Console, create a new user (IAM/Users), and [create an access key](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html) for that user (Security credentials/Access keys). The IAM user must have, _at least_, the following permissions, depending on the deployment type you choose:

      <table>
      <thead>
      <tr>
      <th>Docker Compose</th>
      <th>Kubernetes</th>
      </tr>
      </thead>
      <tbody>
      <tr>
      <td valign="top">
      <code>AmazonEC2FullAccess</code><br /><code>AmazonS3FullAccess</code><br />
      </td>
      <td valign="top">
      <code>AmazonEC2FullAccess</code><br /><code>AmazonS3FullAccess</code><br /> <code>AmazonElasticFileSystemFullAccess</code><br /><code>AmazonRoute53FullAccess</code><br /></td>
      </tr>
      </table>

      Note down the *AWS Access Key ID* and *AWS Secret Access Key*.
  
   2. [Create an *S3 bucket*](https://docs.aws.amazon.com/AmazonS3/latest/userguide/create-bucket-overview.html) in the region `us-east-2` to store the Terraform state. You must follow the [AWS guidelines](https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucketnamingrules.html) for naming your bucket. Note down the bucket name.

2. **Prepare an SSH key pair.** This key pair will be used to access the deployed AWS EC2 instance(s) where the service will be running. You can use one of the commands below. **Do not enter a passphrase even if prompted to do so:**

   | To use a 2048-bit RSA key pair                | To use an ED25519 key pair                    |
   |-----------------------------------------------|-----------------------------------------------|
   | `ssh-keygen -t rsa -b 2048 -N  ""  -f id_rsa` | `ssh-keygen -t ed25519 -N  ""  -f id_ed25519` |

   Store securely both the public and private key.

3. **Prepare the service parameters.** The following data refers to the GitHub repository where the service is developed. You will need these data when configuring the deployment:
   - service repository URL,
   - public ID of the service,
   - release tag.

   The release tag corresponds to the version of the service you want to deploy. If you don't define it, the script will deploy the latest available release.

   You also need to prepare the following files:

   - `service_vars.env` with the service variables,
   - `keys.json` with the service agent keys.

   Finally, if the GitHub repository of the service is private, make sure that your GitHub user has read access. In this case, you will need to [create a *GitHub personal access token*](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token) with `repo` permissions enabled.

## Deploy the service using GitHub actions

The repository is prepared to facilitate the service deployment using GitHub actions. This is the easiest way to deploy your service. **Currently only Docker Compose deployments are supported through GitHub actions.**

1. **Fork this repository.**
2. **Configure cloud credentials and service parameters.**
   First, [define the following secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets#creating-encrypted-secrets-for-a-repository) and [variables](https://docs.github.com/en/actions/learn-github-actions/variables#creating-configuration-variables-for-a-repository) in the forked repository. We recommend that you use the GitHub website UI to define them:

   > **Warning** <br />
   > **Please make sure to avoid any leading or trailing white spaces or newlines when defining secrets and variables.**

   <small>
   <table>
   <thead>
   <tr>
   <th>Name</th>
   <th>Type</th>
   <th>Description</th>
   </tr>
   </thead>
   <tbody>
   <tr>
   <td>
   <code>AWS_ACCESS_KEY_ID</code>
   </td>
   <td>Secret</td>
   <td>AWS Access Key ID (20-character alphanumeric string).</td>
   </tr>
   <tr>
   <td>
   <code>AWS_SECRET_ACCESS_KEY</code>
   </td>
   <td>Secret</td>
   <td>AWS Secret Access Key (40-character alphanumeric string).</td>
   </tr>
   <tr>
   <td>
   <code>OPERATOR_SSH_PRIVATE_KEY</code>
   </td>
   <td>Secret</td>
   <td>SSH private key to access the deployed AWS EC2 instance(s). It must include the opening and closing lines. Example:
   <pre>
   <code>-----BEGIN OPENSSH PRIVATE KEY-----
   b3BlbnNzaC1rZXktdjEAAAAA...
   ...aVBhTV8D6Oya/qZU7SzeQT==
   -----END OPENSSH PRIVATE KEY-----</code>
   </pre>
   </tr>
   <tr>
   <td>
   <code>GH_TOKEN</code>
   </td>
   <td>Secret<br /><b>(Optional)</b></td>
   <td>GitHub access token. This is only required if the service repository is private. Example:<br />
   <code>ghp_000000000000000000000000000000000000</code>
   </td>
   </tr>
   <tr>
   <td>
   <code>TFSTATE_S3_BUCKET</code>
   </td>
   <td>Variable</td>
   <td>AWS S3 bucket name to store the Terraform state.</td>
   </tr>
   <tr>
   <td>
   <code>SERVICE_REPO_URL</code>
   </td>
   <td>Variable</td>
   <td>Service repository URL.<br />
   <code>https://github.com/valory-xyz/decentralized-watchtower</code>
   </td>
   </tr>
   <tr>
   <td>
   <code>SERVICE_ID</code>
   </td>
   <td>Variable</td>
   <td>Public ID of the service. One of the following:
   <code>valory/decentralized_watchtower_goerli:0.1.0</code><br />
   <code>valory/decentralized_watchtower:0.1.0</code><br />
   <code>valory/decentralized_watchtower_gnosis:0.1.0</code><br />
   </td>
   </tr>
   <tr>
   <td>
   <code>SERVICE_REPO_TAG</code>
   </td>
   <td>Variable<br /></td>
   <td>Release tag corresponding to the version of the service you want to deploy<br />
   <code>v0.1.0</code>
   </td>
   </tr>
   </tbody>
   </table><br />

   Next, Populate, commit and push the files with the service configuration parameters:

   <table>
   <thead>
   <tr>
   <th>File</th>
   <th>Description</th>
   </tr>
   </thead>
   <tbody>
   <tr>
   <td valign="top">
   <code>./config/keys.json</code>
   </td>
   <td>
   It must contain the address(es) and key(s) for the agents to be deployed. Example (for a single agent):

   ```json
   [
    {
     "address": "0x1000000000000000000000000000000000000000",
     "private_key": "0x0123456789abcdef0123456789abcdef...0"
    }
   ]
   ```

   > **Warning** <br />
   > **Typically, it is not advisable to expose the `keys.json` file in the repository. Therefore, [we provide a mechanism](./docs/faq-troubleshooting.md#variable-overrides) where you can [define the GitHub secret](https://docs.github.com/en/actions/security-guides/encrypted-secrets#creating-encrypted-secrets-for-a-repository) `KEYS_JSON` with the contents of the file.**
   </td>
   </tr>
   <tr>
   <td valign="top">
   <code>./config/service_vars.env</code>
   </td>
   <td>

   It contains the service-specific variables:
   <pre>
   <code>ALL_PARTICIPANTS='["0x1000000000000000000000000000000000000000"]'
   SAFE_CONTRACT_ADDRESS=0x5000000000000000000000000000000000000000
   USE_ACN=true
   COW_API_URL=https://api.cow.fi/goerli/api/v1
   SERVICE_REGISTRY_ADDRESS=0x9c7d6D8D6c11e5F146628fd8478f73FAcc10C6B3
   ON_CHAIN_SERVICE_ID=53
   CHAIN_ID=5
   TENDERMINT_P2P_URL_0=$(curl -s icanhazip.com):26656
   
   HTTP_RPC=&lt;http_rpc&gt;
   WS_RPC=&lt;ws_rpc&gt;</code>
   </pre>

   > **Warning** <br />
   > **Typically, it is not advisable to expose secret/confidential variables in the repository. Therefore, [we provide a mechanism](./docs/faq-troubleshooting.md#variable-overrides) where you can you can assign them a blank value (or a placeholder value) in the file `service_vars.env`, and override their values by [defining GitHub secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets#creating-encrypted-secrets-for-a-repository) matching the corresponding variables' names.**

   </td>
   </tr>
   </tbody>
   </table>
   </small>

3. **Deploy the infrastructure and the service to AWS.** Run the "Deploy service" workflow using the GitHub interface. This workflow will create the necessary resources on AWS. Once the workflow has finished in the GitHub runner, the deployment process will continue on the AWS EC2 instance(s).

   <p align="center"><img src="docs/images/deploy-service-workflow.png" alt="Deploy service workflow" width=80%></p>

   Please wait until the AWS EC2 instance finishes completing the service deployment. The IP of the created AWS EC2 instance can be retrieved in the *Summary* step in the *Deploy service* workflow.

   <p align="center"><img src="docs/images/deploy-service-summary.png" alt="Deploy service summary" width=80%></p>

4. **Interact with the deployed infrastructure.** You can connect to the AWS EC2 instance as the user `ubuntu` using the SSH private key specified:

   ```bash
   ssh -i /path/to/private_key ubuntu@<AWS_EC2_PUBLIC_IP>
   ```

   Track the progress of the service deployment by checking the log file:

   ```bash
   cat ~/deploy_service.log
   ```

   Once the service agent is up and running, you can attach to its `screen` session:

   ```bash
   screen -r service_screen_session
   ```

   Use `Ctrl+A D` to detach from the session. Alternatively, you can also follow the Docker logs:

   ```bash
   docker logs abci0 --follow  # For the agent
   docker logs node0 --follow  # For the Tendermint node
   ```

5. **Destroy the infrastructure.**  Run the "Destroy infrastructure" workflow using the GitHub interface. This will destroy the resources created on AWS. Alternatively, you can also remove the resources using the AWS Management Console.

   <p align="center"><img src="docs/images/destroy-infrastructure-workflow.png" alt="Deploy service workflow" width=80%></p>

## Advanced usage: deploy the service through the command line interface

For greater control over the deployment process, you have the option to customize the provided scripts and manually execute the deployment steps on your local machine. This approach allows you to tailor the options according to your specific requirements. Follow the links below for the complete instructions.

- [Manual Docker Compose deployment](./docs/deployment-docker-compose.md)
- [Manual Kubernetes deployment](./docs/deployment-kubernetes.md)

## FAQ and troubleshooting

Read our [FAQ and troubleshooting guide](./docs/faq-troubleshooting.md), which contains advice for resolving common error situations.
