# Remote state stored in S3 with DynamoDB used for state locking.
#
# The bucket name is account specific (it is derived from the AWS account id),
# so it is not hardcoded here. It is supplied at init time with
# -backend-config="bucket=..." which `make bootstrap` and `make init` do
# automatically. This keeps the project universal: any account can deploy it
# without editing the code (see README.md).
terraform {
  backend "s3" {
    key            = "lesson-8-9/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
