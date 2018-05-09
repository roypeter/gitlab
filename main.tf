data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

data "template_file" "user_data" {
  template = "${file("${path.module}/templates/user_data.tpl")}"
}

data "aws_subnet" "ec2" {
  filter {
    name   = "tag:Name"
    values = ["*${var.aws_ec2_subnet_tag_name}*"]
  }
}

data "aws_subnet" "elb" {
  filter {
    name   = "tag:Name"
    values = ["*${var.aws_elb_subnet_tag_name}*"]
  }
}

data "aws_route53_zone" "selected" {
  name         = "${element(split(".", var.gitlab_domain_name), 1)}.${element(split(".", var.gitlab_domain_name), 2)}."
}

resource "aws_security_group" "gitlab_ec2" {
  name        = "${var.project_name}-ec2"
  description = "${var.project_name}-ec2"
  vpc_id      = "${data.aws_subnet.ec2.vpc_id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8","192.168.0.0/16"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "gitlab_elb" {
  name        = "${var.project_name}-elb"
  description = "${var.project_name}-elb"
  vpc_id      = "${data.aws_subnet.elb.vpc_id}"

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "gitlab" {
  ami           = "${data.aws_ami.ubuntu.id}"
  instance_type = "${var.aws_ec2_instance_type}"
  subnet_id     = "${data.aws_subnet.ec2.id}"
  user_data     = "${data.template_file.user_data.rendered}"
  vpc_security_group_ids      = ["${aws_security_group.gitlab_ec2.id}"]
  key_name = "${var.aws_ec2_keypair}"

  root_block_device = {
    volume_type = "${var.gitlab_boot_disk_type}"
    volume_size = "${var.gitlab_boot_disk_size}"
    delete_on_termination = false
  }

  ebs_block_device {
    device_name = "/dev/xvdf"
    volume_type = "${var.gitlab_data_disk_type}"
    volume_size = "${var.gitlab_data_disk_size}"
    delete_on_termination = false
  }

  tags {
    Name = "${var.project_name}"
  }
}

resource "aws_acm_certificate" "elb_cert" {
  domain_name = "${var.gitlab_domain_name}"
  validation_method = "DNS"
  tags {
    Name = "${var.project_name}-elb"
  }
}

resource "aws_route53_record" "cer_verify" {
  zone_id = "${data.aws_route53_zone.selected.zone_id}"
  name    = "${aws_acm_certificate.elb_cert.domain_validation_options.0.resource_record_name}"
  type    = "${aws_acm_certificate.elb_cert.domain_validation_options.0.resource_record_type}"
  ttl     = "300"
  records = ["${aws_acm_certificate.elb_cert.domain_validation_options.0.resource_record_value}"]
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn = "${aws_acm_certificate.elb_cert.arn}"
  validation_record_fqdns = ["${aws_route53_record.cer_verify.fqdn}"]
}

resource "aws_elb" "gitlab" {
  name               = "${var.project_name}-elb"

  security_groups = ["${aws_security_group.gitlab_elb.id}"]

  subnets = ["${data.aws_subnet.elb.id}"]

  listener {
    instance_port      = 80
    instance_protocol  = "http"
    lb_port            = 443
    lb_protocol        = "https"
    ssl_certificate_id = "${aws_acm_certificate.elb_cert.id}"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/explore"
    interval            = 30
  }

  instances                   = ["${aws_instance.gitlab.id}"]
  cross_zone_load_balancing   = false
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags {
    Name = "${var.project_name}-elb"
  }
}

resource "aws_route53_record" "gitlab" {
  zone_id = "${data.aws_route53_zone.selected.zone_id}"
  name    = "${var.gitlab_domain_name}"
  type    = "CNAME"
  ttl     = "300"
  records = ["${aws_elb.gitlab.dns_name}"]
}
