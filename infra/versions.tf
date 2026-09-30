terraform {
  required_version = "~> 1.12"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.4"
    }
  }

  # State bucket on Infomaniak Object Storage, created once by hand (see README).
  # Access keys come from AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY.
  backend "s3" {
    bucket = "its-giving-cartoon-tfstate"
    key    = "infra/terraform.tfstate"
    # Infomaniak's S3 API only accepts this region name in request signatures.
    region = "us-east-1"
    endpoints = {
      s3 = "https://s3.pub1.infomaniak.cloud"
    }
    use_path_style = true
    use_lockfile   = true

    # Infomaniak is not AWS: skip the AWS-specific checks.
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }
}

# Configured through OS_* environment variables (openrc locally, secrets in CI).
provider "openstack" {}
