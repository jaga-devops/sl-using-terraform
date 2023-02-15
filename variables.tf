variable "access_key" {
     description = "Access key to AWS console"

}
variable "secret_key" {
     description = "Secret key to AWS console"

}

variable "region" {
  default     = "us-east-2"
  type        = string
  description = "Region of the VPC"
}

variable "aws_key_pair" {
  default = "/home/ubuntu/bastio"
}

variable "cidr_block" {
  default     = "10.0.0.0/16"
  type        = string
  description = "CIDR block for the VPC"
}

variable "public_subnet1_cidr_block" {
  default     = "10.0.0.0/24"
  type        = string
  description = "List of public subnet CIDR blocks"
}

variable "private_subnet1_cidr_block" {
  default     = "10.0.1.0/24"
  type        = string
  description = "List of private subnet CIDR blocks"
}
