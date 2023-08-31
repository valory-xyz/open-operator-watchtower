#!/bin/bash

# ------------------------------------------------------------------------------
#
#   Copyright 2023 Valory AG
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#
# ------------------------------------------------------------------------------


# This script generates the deployment to be executed on the host machine
# running an agent service.
# 
# Inputs (environment variables):
#   - SERVICE_REPO_URL: Service repository URL.
#   - SERVICE_ID: Public ID of the service found in SERVICE_REPO_URL.
#   - (Optional) SERVICE_REPO_TAG: Tag of the service release to be deployed.
#     If not defined, the script will automatically collect the latest tag.
#   - (Optional) GH_TOKEN: Github personal access token, required to access
#     private repositories.
#   - (Optional) DEPLOYMENT_TYPE: Either "docker" or "kubernetes".
#   - (Optional) VARS_CONTEXT: JSON context with Github variables.
#   - (Optional) SECRETS_CONTEXT: JSON context with Github secrets.
#
# Outputs:
#   - If DEPLOYMENT_TYPE=="docker", outputs the file "deploy_service.sh"
#     to be transferred and executed in the remote machine. The file includes the
#     instructions to fetch and run the service. This option requires
#     Open Autonomy installed in the remote machine.
#   - If DEPLOYMENT_TYPE=="kubernetes", outputs the folder
#     "fetched_service/abci_build", which containts the build configuration
#     to be applied through "kubectl" in the cluster. This option requires
#     Open Autonomy installed in the current machine.
#
# Notes:
#   - Service variables are read from the file "./config/service_vars.env" and
#     overriden if the identifier is found in any context.
#   - keys.json context is read from the file "./config/keys.json" and
#     overriden if the identifier KEYS_JSON is found in any context.

set -e

parse_env_file() {
    # Overrides an .env file containing variables.
    #
    # For each variable VAR in the .env file, it outputs to environment
    # variable "SERVICE_VARIABLES_PARSED"
    # "export VAR=val", where "val" is either the value found in the
    # .env file, or overrien if found on the JSON object passed as
    # second argument.

    local env_file="$1"
    local json="$2"

    echo "   - Parsing .env file \"$env_file\""

    # Sanitize inputs
    if [[ ! -f "$env_file" ]]; then
        echo "     - Warning: .env file \"$env_file\" not found: deployment might be invalid."
        SERVICE_VARIABLES_PARSED=$'\n'"# Service variables"$'\n'"# - WARNING: File \"$env_file\" not found when generating deployment script."$'\n'"#   Deployment might be invalid."$'\n'
        return
    fi

    if [[ -z "${json// }" ]]; then
        json="{}"
    fi

    # Read variables
    local vars="$(grep -vE "^(#.*|\s*)$" "$env_file" | awk -F '=' '{ print "export", $0 }')"

    # Parse the JSON object and loop through its keys
    for var_name in $(echo "$json" | jq -r 'keys[]'); do
        local var_value=$(echo "$json" | jq -r ".$var_name")

        # Override variables in $vars if existing in JSON
        if [[ -n "${var_value// }" ]] && grep -q "export $var_name=" <<< "export $vars="; then
            echo "     - Overriding variable $var_name"
            vars=$(echo "$vars" | sed "s#export $var_name=.*#export $var_name=$var_value#")
        fi
    done

    SERVICE_VARIABLES_PARSED=$'\n'"# Service variables"$'\n'"$vars"$'\n'
}


validate_keys_json() {
    # Validates the first argument $1 to match expected Ethereum key and address JSON format

    echo "   - Validating KEYS_JSON"

    local keys_json="$1"

    if [ -z "${keys_json// }" ]; then
      echo "Error: \"KEYS_JSON\" not defined. Please review repository secrets and the file \"$SERVICE_KEYS_JSON_FILE\". Exiting script."
      exit 1
    fi

    # Validate KEYS_JSON format
    if ! echo "$keys_json" | jq -e '. | type == "array" and length > 0 and all(.[]; type == "object" and (.address | type == "string") and (.private_key | type == "string"))' > /dev/null; then
      echo "Error: KEYS_JSON does not match the expected pattern. Exiting script."
      exit 1
    fi

    # Validate each object in KEYS_JSON
    local errors=0
    for object in $(echo "$keys_json" | jq -c '.[]'); do
      # Validate Ethereum address and private key
      local private_key=$(echo "$object" | jq -r '.private_key')
      local address=$(echo "$object" | jq -r '.address')
 
      if ! [[ $address =~ ^0x[0-9a-fA-F]{40}$ ]]; then
        echo "     - Invalid Ethereum address format: $address"
        errors=$((errors + 1))
      elif ! [[ $private_key =~ ^0x[0-9a-fA-F]{64}$ ]]; then
        echo "     - Invalid Ethereum private key format for address $address"
        errors=$((errors + 1))
      fi
    done

    if [ $errors -gt 0 ]; then
      echo "Error: KEYS_JSON does not match the expected pattern. Exiting script."
      exit 1
    fi

    echo "     - KEYS_JSON format is valid"
}


trim() {
    # Removes leading and trailing whitespaces, tabs and newlines from a variable
	  s="${1}"
	  s="$(printf "${s}" | sed -z 's/^[[:space:]]*//')"
	  s="$(printf "${s}" | sed -z 's/[[:space:]]*$//')"
	  echo "${s}"
	  return 0    
}


# =========
# Constants
# =========
SERVICE_VARIABLES_FILE="./config/service_vars.env"
SERVICE_KEYS_JSON_FILE="./config/keys.json"

DEPLOY_SERVICE_SCRIPT_FILE="deploy_service.sh"
DOCKER_DEPLOY_SERVICE_SCRIPT_TEMPLATE='#!/bin/bash

# Deployment script (Docker Compose)
# Service: $SERVICE_ID
# Tag: $SERVICE_REPO_TAG

echo \"Current user: \$(whoami)\"
export PATH=\"\$PATH:/home/ubuntu/.local/bin\"
echo \"Environment variables:\"
env
autonomy --version
autonomy init --remote --author open_operator --reset
autonomy fetch $SERVICE_HASH --service
latest_dir=\$(ls -td -- */ | head -n 1)
mv \$latest_dir fetched_service
cd fetched_service
autonomy build-image
cat > keys.json << EOF
$KEYS_JSON
EOF
$SERVICE_VARIABLES_PARSED
autonomy deploy build
cd abci_build && screen -dmS service_screen_session bash -c \"autonomy deploy run\"
echo \"Service deployment finished. Use \\\"screen -r service_screen_session\\\" to attach to the session running the agent.\"
'

KUBERNETES_DEPLOY_SERVICE_SCRIPT_TEMPLATE='#!/bin/bash

# Deployment script (Kubernetes)
# Service: $SERVICE_ID
# Tag: $SERVICE_REPO_TAG

echo \"Current user: \$(whoami)\"
echo \"Environment variables:\"
env
autonomy --version
autonomy init --remote --author open_operator --reset
autonomy fetch $SERVICE_HASH --service --alias service
latest_dir=\$(ls -td -- */ | head -n 1)
mv \$latest_dir fetched_service
cd fetched_service
cat > keys.json << EOF
$KEYS_JSON
EOF
$SERVICE_VARIABLES_PARSED
autonomy deploy build --kubernetes --image-author valory
cd abci_build
kubectl apply --recursive -f .
echo \"Service deployment to Kubernetes cluster finished.\"
'



# ==================
# Script starts here
# ==================
echo "---------------------"
echo "Generating deployment"
echo "---------------------"
echo
echo "Environment variables:"
echo " - SERVICE_REPO_URL=$SERVICE_REPO_URL"
echo " - SERVICE_REPO_TAG=$SERVICE_REPO_TAG"
echo " - DEPLOYMENT_TYPE=$DEPLOYMENT_TYPE"
echo " - SERVICE_ID=$SERVICE_ID"
echo " - GH_TOKEN=$GH_TOKEN"
echo 

SERVICE_REPO_URL=$(trim "$SERVICE_REPO_URL")
SERVICE_REPO_TAG=$(trim "$SERVICE_REPO_TAG")
SERVICE_ID=$(trim "$SERVICE_ID")
GH_TOKEN=$(trim "$GH_TOKEN")

if [ -z "${SERVICE_REPO_URL// }" ]; then
  echo "Error: Undefined \"SERVICE_REPO_URL\"."
  exit 1
fi

if [ -z "${SERVICE_ID// }" ]; then
  echo "Error: Undefined \"SERVICE_ID\"."
  exit 1
fi

if [ -z "${DEPLOYMENT_TYPE// }" ]; then
    DEPLOYMENT_TYPE="docker"
elif ! [[ "$DEPLOYMENT_TYPE" = "docker" || "$DEPLOYMENT_TYPE" = "kubernetes" ]]; then
    echo "Error: Invalid DEPLOYMENT_TYPE. Allowed values are 'docker' or 'kubernetes'."
    exit 1
fi

OWNER=$(echo "$SERVICE_REPO_URL" | cut -d'/' -f4)
REPO=$(echo "$SERVICE_REPO_URL" | cut -d'/' -f5)
API_URL="https://api.github.com/repos/$OWNER/$REPO"

echo "Steps:"

# ------------------------------------------------------------------------------
echo " - Testing repository access"

if [[ -z "${GH_TOKEN// }" ]]; then
  HEADERS=(-H "Accept: application/vnd.github+json")
else
  HEADERS=(-H "Accept: application/vnd.github+json" -H "Authorization: token $GH_TOKEN")
fi

response=$(curl -s -o /dev/null -w "%{http_code}" "${HEADERS[@]}" "$API_URL")

if [ "$response" -ne 200 ]; then
  echo "Error: Access to repository \"$SERVICE_REPO_URL\" failed (response $response). Please check the access token (GH_TOKEN) and repository URL (SERVICE_REPO_URL)."
  exit 1
fi

# ------------------------------------------------------------------------------
echo " - Retrieving repository tag"

if [ -z "${SERVICE_REPO_TAG// }" ]; then
  echo "   - Undefined \"SERVICE_REPO_TAG\". Retrieving latest release tag."
  SERVICE_REPO_TAG=$(curl -sL "${HEADERS[@]}" "$API_URL/releases/latest" | jq -r ".tag_name")
fi

echo "   - Repository tag: $SERVICE_REPO_TAG"

response=$(curl -s "${HEADERS[@]}" "$API_URL/tags")

if ! echo "$response" | grep -q "\"name\": \"$SERVICE_REPO_TAG\""; then
  echo "Error: Tag \"$SERVICE_REPO_TAG\" does not exist in repository \"$SERVICE_REPO_URL\"."
  exit 1
fi

# ------------------------------------------------------------------------------
echo " - Retrieving \"packages/packages.json\""
PACKAGES_JSON=$(curl -s "${HEADERS[@]}" "https://raw.githubusercontent.com/$OWNER/$REPO/$SERVICE_REPO_TAG/packages/packages.json")

if ! echo "$PACKAGES_JSON" | jq -e . >/dev/null 2>&1; then
  echo "Error: Ivalid \"packages/packages.json\". Exiting script."
  echo "Verify that the tag \"$SERVICE_REPO_TAG\" exists in repository \"$SERVICE_REPO_URL\"."
  exit 1
fi

# ------------------------------------------------------------------------------
echo " - Retrieving service hash"
SERVICE_ID=${SERVICE_ID#service/}
SERVICE_JSON_KEY="service/${SERVICE_ID/:/\/}"
SERVICE_HASH=$(echo "$PACKAGES_JSON" | jq -r ".dev.\"$SERVICE_JSON_KEY\"")
echo "   - Service hash: $SERVICE_HASH"

if [[ ! $SERVICE_HASH =~ ^ba[a-zA-Z0-9]{57}$ ]]; then
  echo "Error: Service hash does not match the expected pattern. Exiting script."
  echo "Verify that the key \"$SERVICE_JSON_KEY\" exists in \"packges/packages.json\" in the repository \"$SERVICE_REPO_URL\" ($SERVICE_REPO_TAG)."
  exit 1
fi

# ------------------------------------------------------------------------------
echo " - Setting up service configuration"

if [[ -z "${VARS_CONTEXT// }" ]]; then
    echo "   - Empty VARS_CONTEXT"
    VARS_CONTEXT="{}"
fi

if [[ -z "${SECRETS_CONTEXT// }" ]]; then
    echo "   - Empty SECRETS_CONTEXT"    
    SECRETS_CONTEXT="{}"
fi

echo "   - Setting the contents of \"KEYS_JSON\""
KEYS_JSON=""
if [[ $(echo "$SECRETS_CONTEXT" | jq '.KEYS_JSON') != "null" ]]; then
  echo "     - Set \"KEYS_JSON\" from context variable"
  KEYS_JSON=$(echo "$SECRETS_CONTEXT" | jq -r '.KEYS_JSON')
elif [ -f $SERVICE_KEYS_JSON_FILE ]; then
  echo "     - Set \"KEYS_JSON\" to file contents \"$SERVICE_KEYS_JSON_FILE\""
  KEYS_JSON=$(<$SERVICE_KEYS_JSON_FILE)
fi

validate_keys_json "$KEYS_JSON"

echo "   - Joining context variables into a single JSON"
SERVICE_VARIABLES_OVERRIDES=$(echo "$VARS_CONTEXT $SECRETS_CONTEXT" | jq -s add)

# Remove known required secret names to avoid exporting them as environment variables in the service accidentally
echo "   - Removing known secrets"
SERVICE_VARIABLES_OVERRIDES=$(echo "$SERVICE_VARIABLES_OVERRIDES" | jq 'del(.AWS_ACCESS_KEY_ID, .AWS_SECRET_ACCESS_KEY, .GH_TOKEN, .KEYS_JSON, .KUBECONFIG, .OPERATOR_SSH_PRIVATE_KEY, .OPERATOR_SSH_PRIVATE_KEY_PASSPHRASE, .TFSTATE_S3_BUCKET)')

#SERVICE_VARIABLES_PARSED is "returned" in parse_env_file() function
parse_env_file "$SERVICE_VARIABLES_FILE" "$SERVICE_VARIABLES_OVERRIDES"

# ------------------------------------------------------------------------------
if [[ "$DEPLOYMENT_TYPE" = "docker" ]]; then
  # Docker Compose deployment
  echo " - Writing Docker Compose service deployment script"
  echo "   - Writing file \"$DEPLOY_SERVICE_SCRIPT_FILE\""
  echo "$(eval "echo \"$DOCKER_DEPLOY_SERVICE_SCRIPT_TEMPLATE\"")" > $DEPLOY_SERVICE_SCRIPT_FILE
  echo "   - Changing permissions to file \"$DEPLOY_SERVICE_SCRIPT_FILE\""
  chmod 764 $DEPLOY_SERVICE_SCRIPT_FILE
  echo " - Finished generating \"$DEPLOY_SERVICE_SCRIPT_FILE\" script ($(du -b "$DEPLOY_SERVICE_SCRIPT_FILE" | cut -f1) B)"

elif [[ "$DEPLOYMENT_TYPE" = "kubernetes" ]]; then
  # Kubernetes deployment
  echo " - Generating Kubernetes deployment"
  echo "   - Writing file \"$DEPLOY_SERVICE_SCRIPT_FILE\""
  echo "$(eval "echo \"$KUBERNETES_DEPLOY_SERVICE_SCRIPT_TEMPLATE\"")" > $DEPLOY_SERVICE_SCRIPT_FILE
  echo "   - Changing permissions to file \"$DEPLOY_SERVICE_SCRIPT_FILE\""
  chmod 764 $DEPLOY_SERVICE_SCRIPT_FILE
  echo " - Finished generating Kubernetes deployment"
fi

echo 
echo "Finished generating deployment."