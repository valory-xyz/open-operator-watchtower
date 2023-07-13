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

# Inputs (environment variables):
#   - PRIVATE_KEY: SSH private key.
#   - (Optional) PRIVATE_KEY_PASSPHRASE: SSH private key passphrase.
#
# Note:
#   Currently passphrase-protected SSH private keys are not supported.

set -e


fail_if_passphrase_protected() {
    if ! ssh-keygen -y -P "" -f "$private_key_temp_file" >/dev/null 2>&1; then
    echo "Error: Passphrase-protected SSH private keys not supported."
    rm "$private_key_temp_file"
    exit 1
  fi
}


# ==================
# Script starts here
# ==================
if [ -z "${PRIVATE_KEY// }" ]; then
  echo "Error: Undefined private key."
  exit 1
fi

private_key_temp_file=$(mktemp)
echo "$PRIVATE_KEY" > "$private_key_temp_file"
chmod 600 "$private_key_temp_file"

fail_if_passphrase_protected

if ! public_key=$(ssh-keygen -y -P "$PRIVATE_KEY_PASSPHRASE" -f "$private_key_temp_file" 2>/dev/null); then
  echo "Error: Invalid passphrase for private key."
  rm "$private_key_temp_file"
  exit 1
fi

rm "$private_key_temp_file"

# Amazon EC2 supports ED25519 and 2048-bit SSH-2 RSA keys for Linux instances.
case $public_key in
  ssh-rsa*) key_type="rsa" ;;
  ssh-ed25519*) key_type="ed25519" ;;
  *) echo "Error: Unsupported SSH key type. AWS EC2 only supports ED25519 and 2048-bit SSH-2 RSA keys for Linux instances." ; exit 1 ;;
esac

mkdir -p ~/.ssh
private_key_file="$HOME/.ssh/id_$key_type"
public_key_file="$HOME/.ssh/id_$key_type.pub"

if [[ -f "$private_key_file" ]]; then
  echo "Error: private key file \"$private_key_file\" already exists."
  exit 1
fi

if [[ -f "$public_key_file" ]]; then
  echo "Error: public key file \"$public_key_file\" already exists."
  exit 1
fi

echo "$PRIVATE_KEY" > "$private_key_file"
chmod 600 "$private_key_file"

echo "$public_key" > "$public_key_file"
chmod 644 "$public_key_file"

echo "PRIVATE_KEY_FILE=$private_key_file" >> "$GITHUB_ENV"
echo "PUBLIC_KEY_FILE=$public_key_file" >> "$GITHUB_ENV"
echo "TF_VAR_operator_ssh_pub_key_path=$public_key_file" >> "$GITHUB_ENV"

echo "Private and public keys have been stored in \"$private_key_file\" and \"$public_key_file\" respectively."
echo "Public key file path has been stored in Terraform variable \"TF_VAR_operator_ssh_pub_key_path\"."
