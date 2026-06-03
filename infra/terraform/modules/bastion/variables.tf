variable "name" { type = string }
variable "vpc_cidr" {
  type    = string
  default = "10.1.0.0/16"
}
variable "availability_zone" { type = string }
variable "azs" {
  type        = list(string)
  description = "AZs for the private runner subnets in the mgmt VPC"
  default     = ["us-east-2a", "us-east-2b"]
}
variable "instance_type" {
  type    = string
  default = "t3.micro"
}
variable "allowed_ssh_cidr" {
  type        = string
  default     = ""
  description = "If set, opens SSH (22) from this CIDR. Empty = SSM-only access."
}
variable "key_name" {
  type        = string
  default     = ""
  description = "Optional EC2 key pair name for SSH."
}
variable "tags" {
  type    = map(string)
  default = {}
}
