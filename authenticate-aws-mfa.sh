#!/bin/bash -ue
# Uses AWS CLI to save MFA session tokens to ~/.aws/credentials under the [default] group.
# Requires the long term credentials to be stored under a [default-long-term] group so they don't get overwritten.
# Can call with --name parameter if the AWS username is not the same as $(whoami)
set -e
set -o pipefail

# Make sure aws cli is set up
if [ ! -f ~/.aws/credentials ]; then
  >&2 printf "No ~/.aws/credentials file found, please set up your aws cli first\n"
  exit 1
fi

# [default-long-term] profile needs to be in ~/.aws/credentials with the long term access key id/secret key.
if ! grep -q "\[default-long-term\]" ~/.aws/credentials; then
  >&2 printf "No [default-long-term] profile found in ~/.aws/credentials.\nPlease set that profile up with your long term credentials\n"
  exit 1
fi

# jq Version >= 1.5 is needed.
if ! type 'jq' > /dev/null 2>&1; then
  >&2 printf "Package 'jq' not found, please install it\n"
  exit 1
fi

function get_aws_auth() {
  set -e
  set -o pipefail
  NAME="$(whoami)"
  if [ $# -gt 0 ]; then
    if [ "$1" == "--name" ]; then
      NAME="$2"
    fi
  fi

  MFA="$(aws iam --profile default-long-term list-mfa-devices --user-name "${NAME}")"
  MFA_SERIAL="$(echo "${MFA}" | jq --raw-output .MFADevices[].SerialNumber)"

  while test -z "${MFA_CODE:-}"; do
    >&2 printf "Please type your MFA code and hit enter\n"
    read MFA_CODE
  done

  if aws sts --profile default-long-term get-session-token --serial-number "${MFA_SERIAL}" --token-code "${MFA_CODE}"; then
    >&2 printf "MFA authentication succeeded.\n"
  else
    >&2 printf "MFA authentication failed.\n"
  fi
}

function get_aws_auth_data() {
  echo "$2" | jq --raw-output ".Credentials.${1}"
}

AWS_AUTH="$(get_aws_auth "$@")"

if ! test -z "$AWS_AUTH"; then
  test -z "$(get_aws_auth_data AccessKeyId "${AWS_AUTH}")" || AWS_ACCESS_KEY_ID=$(get_aws_auth_data AccessKeyId "${AWS_AUTH}")
  test -z "$(get_aws_auth_data SecretAccessKey "${AWS_AUTH}")" || AWS_SECRET_ACCESS_KEY=$(get_aws_auth_data SecretAccessKey "${AWS_AUTH}")
  test -z "$(get_aws_auth_data SessionToken "${AWS_AUTH}")" || AWS_SESSION_TOKEN=$(get_aws_auth_data SessionToken "${AWS_AUTH}")
fi

# Remove existing [default] block.
# shellcheck disable=SC2016
sed -n -i '1h;1!H;${g;s/\n\{0,\}\[default\]\n\(AWS_[[:alnum:][:punct:]]\{1,\}\n\?\)\{1,3\}//;p;}' ~/.aws/credentials

# Save new [default] block with mfa tokens.
printf "\n\n[default]\nAWS_ACCESS_KEY_ID=%s\nAWS_SECRET_ACCESS_KEY=%s\nAWS_SESSION_TOKEN=%s" "${AWS_ACCESS_KEY_ID}" "${AWS_SECRET_ACCESS_KEY}" "${AWS_SESSION_TOKEN}" >> ~/.aws/credentials
