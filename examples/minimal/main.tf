provider "aws" {
  region  = "us-west-2"
}

module "gitlab" {
  source = "../../"
  project_name = "gitlab-minimal"
  gitlab_domain_name = "gitlab.example.com"
  aws_ec2_keypair = "my-key-name"
}
