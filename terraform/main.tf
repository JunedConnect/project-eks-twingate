module "eks" {
  source = "./modules/eks"

  private_subnet_1_id = module.vpc.private_subnet_1_id
  private_subnet_2_id = module.vpc.private_subnet_2_id

  name                                        = var.name
  authentication_mode                         = var.authentication_mode
  bootstrap_cluster_creator_admin_permissions = var.bootstrap_cluster_creator_admin_permissions
  cluster_version                             = var.cluster_version
  endpoint_private_access                     = var.endpoint_private_access
  endpoint_public_access                      = var.endpoint_public_access
  upgrade_support_type                        = var.upgrade_support_type

  node_group_name    = var.node_group_name
  desired_size       = var.desired_size
  max_size           = var.max_size
  min_size           = var.min_size
  instance_disk_size = var.instance_disk_size
  instance_types     = var.instance_types
  capacity_type      = var.capacity_type

  eks_cluster_role_name    = var.eks_cluster_role_name
  eks_node_group_role_name = var.eks_node_group_role_name

}

module "twingate" {
  source = "./modules/twingate"

  vpc_id            = module.vpc.vpc_id
  private_subnet_1_id = module.vpc.private_subnet_1_id
  eks_cluster_endpoint = module.eks.eks_cluster_endpoint
  twingate_url      = var.twingate_url
  twingate_ami_name   = var.twingate_ami_name
  twingate_access_group_id = var.twingate_access_group_id
}

module "vpc" {
  source = "./modules/vpc"

  name                           = var.name
  vpc_cidr_block                 = var.vpc_cidr_block
  publicsubnet1_cidr_block       = var.publicsubnet1_cidr_block
  publicsubnet2_cidr_block       = var.publicsubnet2_cidr_block
  privatesubnet1_cidr_block      = var.privatesubnet1_cidr_block
  privatesubnet2_cidr_block      = var.privatesubnet2_cidr_block
  enable_dns_support             = var.enable_dns_support
  enable_dns_hostnames           = var.enable_dns_hostnames
  subnet_map_public_ip_on_launch = var.subnet_map_public_ip_on_launch
  availability_zone_1            = var.availability_zone_1
  availability_zone_2            = var.availability_zone_2
  route_cidr_block               = var.route_cidr_block

}