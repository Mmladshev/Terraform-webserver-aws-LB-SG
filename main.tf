provider "aws" {
  region = "eu-central-1"
}

################


data "aws_availability_zones" "aws_az" {}
data "aws_ami" "latest_ami_amazon" {
  owners      = ["137112412989"]
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-5.10-hvm-*-x86_64-gp2"]
  }
}


#################

resource "aws_security_group" "my_webserver_SG" {

  name = "Dynamic Security Group"

  dynamic "ingress" {
    for_each = ["80", "443"]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Name"  = "Dynamic-SG"
    "Owner" = "MMladshev"
  }
}

resource "aws_launch_configuration" "web_lauch" {
  name_prefix     = "Web-Server-Highly-Available_LC-"
  image_id        = data.aws_ami.latest_ami_amazon.id
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.my_webserver_SG.id]
  user_data       = file("user_data.sh")

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "webserver_sg" {
  name                 = "ASG-${aws_launch_configuration.web_lauch.name_prefix}"
  launch_configuration = aws_launch_configuration.web_lauch.name
  min_size             = 2
  max_size             = 2
  min_elb_capacity     = 2
  vpc_zone_identifier  = [aws_default_subnet.default_subnet1.id, aws_default_subnet.default_subnet2.id]
  health_check_type    = "ELB"
  load_balancers       = [aws_elb.WebServer_ELB.name]

  tag {
    key                 = "Name"
    value               = "WebServer-ASG"
    propagate_at_launch = true
  }

  tag {
    key                 = "Owner"
    value               = "MMladshev"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_elb" "WebServer_ELB" {
  name               = "webserver-ha-elb"
  availability_zones = [data.aws_availability_zones.aws_az.names[0], data.aws_availability_zones.aws_az.names[1]]
  security_groups    = [aws_security_group.my_webserver_SG.id]

  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = 80
    instance_protocol = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 10
  }

  tags = {
    "Name" = "Web-Server-Highly-Available_ELB"
  }
}


resource "aws_default_subnet" "default_subnet1" {
  availability_zone = data.aws_availability_zones.aws_az.names[0]

}

resource "aws_default_subnet" "default_subnet2" {
  availability_zone = data.aws_availability_zones.aws_az.names[1]

}


output "web_loadbalancer_url" {
  value = aws_elb.WebServer_ELB.dns_name
}
