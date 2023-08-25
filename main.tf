terraform {                     #terraform block is used to specify configuration settings for the project
  required_providers {          #providers that terraform will use. Providers are an abstraction of API, responsible for exposing resources
    aws = {                     #configuration of AWS plugin, can change name
      source  = "hashicorp/aws" #source to download the plugin
      version = "~> 4.16"       #specify the version of plugin, it will pick the latest version in series of 4.x
    }
  }
  required_version = ">= 1.2.0" #minimum version of terraform 
  backend "s3" {
    bucket         = "check-assignment-abdrehuceq"
    key            = "statefiles/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "assignment4_state_lock_12345"
  }
}
# terraform {
#   backend "s3" {
#     bucket         = "assignment4tfstate12343212"
#     key            = "statefiles/terraform.tfstate"
#     region         = "us-east-1"
#     encrypt        = true
#     dynamodb_table = "assignment4_state_lock_12345"
#   }
# }

resource "aws_s3_bucket" "b" {
  bucket = "check-assignment-abdrehuceq"
  acl    = "private"
  versioning {
    enabled = true
  }
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}
resource "aws_dynamodb_table" "statelock" {
  name         = "assignment4_state_lock_12345"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LOCKID"
  attribute {
    name = "LOCKID"
    type = "S"
  }

}


provider "aws" {        #configuring the aws provider
  region  = var.region  #terraform apply -var="profile=your_profile_name" (INSTEAD OF USING DEFAULT)
  profile = var.profile #profile for authentication, I haven't specified default profile but the profile associated with access keys is typically set default
}
# create the VPC
resource "aws_vpc" "My_VPC" { #aws_vpc is a keyword
  cidr_block = var.vpcCIDRblock
  # instance_tenancy     = var.instanceTenancy
  # enable_dns_support   = var.dnsSupport
  # enable_dns_hostnames = var.dnsHostNames
  tags = {
    Name = "My VPC"
  }
}
# create the Subnet
resource "aws_subnet" "My_VPC_Subnet_Public" { #
  vpc_id                  = aws_vpc.My_VPC.id
  cidr_block              = var.subnetCIDRblock
  map_public_ip_on_launch = var.mapPublicIP
  availability_zone       = var.availabilityZone
  tags = {
    Name = "My VPC Public Subnet"
  }
}
resource "aws_subnet" "My_VPC_Subnet_Private" {
  vpc_id     = aws_vpc.My_VPC.id
  cidr_block = var.subnetCIDRblock1
  #map_public_ip_on_launch = "${var.mapPublicIP}" 
  availability_zone       = var.availabilityZone
  map_public_ip_on_launch = "false"
  tags = {
    Name = "My VPC Private Subnet"
  }
} # end resource

# Create the Security Group
resource "aws_security_group" "My_VPC_Security_Group_Private" {
  vpc_id      = aws_vpc.My_VPC.id #Specifies the ID of the VPC that this security group belongs to. (AN ATTRIBUTE, CANNOT CHANGE NAME)
  name        = "My VPC Security Group Private"
  description = "My VPC Security Group Private"
  ingress {
    security_groups = ["${aws_security_group.My_VPC_Security_Group_Public.id}"] #traffic from public subnet is allowed
    from_port       = 0                                                         #0 means all ports
    to_port         = 0
    protocol        = "-1" #all protocols are allowed
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"] #"0.0.0.0/0" indicates that traffic can be sent to any destination IP address.
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
  }
  tags = {
    Name = "My VPC Security Group Private"
  }
}
resource "aws_security_group" "My_VPC_Security_Group_Public" {
  vpc_id      = aws_vpc.My_VPC.id
  name        = "My VPC Security Group Public"
  description = "My VPC Security Group Public"
  ingress {
    cidr_blocks = ["${var.ingressCIDRblockPub}"] #only IPs allowed by the variable can access the vpc instances
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
  }
  egress {
    cidr_blocks = ["${var.ingressCIDRblockPub}"]
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
  }
  tags = {
    Name = "My VPC Security Group Public"
  }
}

# Create the Internet Gateway
resource "aws_internet_gateway" "My_VPC_GW" { #safe to assign this way because we didn't give private instances a public IP.
  vpc_id = aws_vpc.My_VPC.id
  tags = {
    Name = "My VPC Internet Gateway"
  }
} # end resource
# Create the Route Table
resource "aws_route_table" "My_VPC_route_table" { #Route table is for traffic within the vpc
  vpc_id = aws_vpc.My_VPC.id
  tags = { #Additionally, you'll need to associate your subnets with this route table. Each subnet should have an associated route table to define how traffic is routed within that subnet. You can use the aws_route_table_association resource to associate your subnets with the route table.
    Name = "My VPC Route Table"
  }
} # end resource
# Create the Internet Access
resource "aws_route" "My_VPC_internet_access" {
  route_table_id         = aws_route_table.My_VPC_route_table.id
  destination_cidr_block = var.destinationCIDRblock #represents the IP addresses allowed to use the internet
  gateway_id             = aws_internet_gateway.My_VPC_GW.id
}
# Associate the Route Table with the Subnet
resource "aws_route_table_association" "My_VPC_association" {
  subnet_id      = aws_subnet.My_VPC_Subnet_Public.id
  route_table_id = aws_route_table.My_VPC_route_table.id
}

#create S3 bucket
# resource "aws_s3_bucket" "b" {
#   bucket = "check-assignment-abdrehuce"
#   acl    = "private" #ACL stands for access control list and here it is specified that only the owner has access to it who made this bucket

#   tags = {
#     Name = "My bucket"
#   }
# }

