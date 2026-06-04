# ---------------------------------------------------------------------------
# VPC peering between the management VPC (bastion) and the workload VPC (EKS).
# Same account + region, so the connection is auto-accepted. Routes are added
# on both sides so the bastion can reach workload subnets and back.
# ---------------------------------------------------------------------------

resource "aws_vpc_peering_connection" "this" {
  vpc_id      = var.mgmt_vpc_id      # requester
  peer_vpc_id = var.workload_vpc_id  # accepter
  auto_accept = true
  tags        = merge(var.tags, { Name = "${var.name}-mgmt-to-workload" })
}

# Route from each mgmt route table (public + private) -> workload VPC.
resource "aws_route" "mgmt_to_workload" {
  for_each                  = toset(var.mgmt_route_table_ids)
  route_table_id            = each.value
  destination_cidr_block    = var.workload_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
}

# Routes from each workload route table -> mgmt VPC (so replies route back).
resource "aws_route" "workload_to_mgmt" {
  for_each                  = toset(var.workload_route_table_ids)
  route_table_id            = each.value
  destination_cidr_block    = var.mgmt_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
}
