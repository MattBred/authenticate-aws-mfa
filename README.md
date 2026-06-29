# Authenticate AWS MFA

Small Bash helper for refreshing AWS CLI credentials with an MFA-backed STS
session token.

The script reads long-term AWS credentials from a `default-long-term` profile,
prompts for an MFA code, calls AWS STS, and writes the temporary session
credentials back to the `default` profile in `~/.aws/credentials`.

## Requirements

- Bash
- AWS CLI configured with long-term credentials
- `jq` 1.5 or newer
- An IAM MFA device attached to the AWS user

## AWS Credentials Setup

Create a `default-long-term` profile in `~/.aws/credentials` that contains the
long-term access key ID and secret access key:

```ini
[default-long-term]
aws_access_key_id=YOUR_ACCESS_KEY_ID
aws_secret_access_key=YOUR_SECRET_ACCESS_KEY
```

The script writes temporary MFA session credentials to the `[default]` profile.
Any existing `[default]` block in `~/.aws/credentials` is removed before the new
temporary credentials are appended.

## Usage

Run the script:

```sh
./authenticate-aws-mfa.sh
```

When prompted, enter the current MFA code for your AWS user.

By default, the script uses the local system username from `whoami` as the AWS
IAM username. If your IAM username is different, pass it with `--name`:

```sh
./authenticate-aws-mfa.sh --name your-aws-iam-username
```

After authentication succeeds, AWS CLI commands that use the default profile can
use the temporary MFA session credentials:

```sh
aws sts get-caller-identity
```

## Notes

- The generated session credentials expire according to AWS STS behavior for
  `get-session-token`.
- Re-run the script whenever the temporary credentials expire.
- Keep the `default-long-term` profile separate so the script does not overwrite
  your long-term credentials.
