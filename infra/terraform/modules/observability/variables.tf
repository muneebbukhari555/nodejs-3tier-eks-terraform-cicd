variable "name" { 
  type = string 
  description = "The name of the observability module, used for naming resources."
}
variable "region" {
   type = string 
   description = "The AWS region where the observability resources will be created."
}
variable "cluster_name" { 
  type = string 
  description = "The name of the EKS cluster."
}
variable "oidc_provider_arn" { 
  type = string 
  description = "The ARN of the OIDC provider."
}
variable "db_instance_id" { 
  type = string 
  description = "The ID of the database instance."
}
variable "tags" {
  type    = map(string)
  default = {}
}
