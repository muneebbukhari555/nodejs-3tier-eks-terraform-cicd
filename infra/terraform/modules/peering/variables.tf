variable "name" {
  type        = string
  description = "Name of the peering connection, used as a prefix for all resources created by this module"
}
variable "mgmt_vpc_id" {
  type        = string
  description = "ID of the management VPC"
}
variable "mgmt_vpc_cidr" {
  type        = string
  description = "CIDR block of the management VPC"
}
variable "mgmt_route_table_ids" {
  type        = list(string)
  description = "All mgmt route tables (public + private) needing a route to workload"
}
variable "workload_vpc_id" {
  type        = string
  description = "ID of the workload VPC"
}
variable "workload_vpc_cidr" {
  type        = string
  description = "CIDR block of the workload VPC"
}
variable "workload_route_table_ids" {
  type        = map(string)
  description = "All workload route tables that need a return route to mgmt"
}
variable "tags" {
  type    = map(string)
  default = {}
}
