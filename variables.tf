variable "project_name" {
  description = "this name will be used to name resources"
}

variable "aws_ec2_instance_type" {
  description = "profile name configured in ~/.aws/credentials file"
  default = "t2.medium"
}

variable "aws_ec2_subnet_tag_name" {
  description = "aws private subnet tag name"
  default = "private-us-west-2c"
}

variable "aws_elb_subnet_tag_name" {
  description = "aws public subnet tag name"
  default = "public-us-west-2c"
}

variable "gitlab_boot_disk_size" {
  description = "gitlab boot disk size in GB"
  default = 20
}

variable "gitlab_data_disk_size" {
  description = "gitlab data disk size in GB"
  default = 50
}

variable "gitlab_boot_disk_type" {
  description = "gitlab boot disk type in GB"
  default = "standard"
}

variable "gitlab_data_disk_type" {
  description = "gitlab data disk type in GB"
  default = "standard"
}

variable "gitlab_domain_name" {
  description = "Example: gitlab.example.io"
}

variable "aws_ec2_keypair" {
  description = "aws ec2 keypair"
}
