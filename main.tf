# ---------- DATA ----------
# Gets the list of available azs in the defined region.
data "aws_availability_zones" "available" {
  state = "available"
}

# ---------- DATA ----------
# Gets the list of available azs in the defined region.
data "aws_availability_zones" "available" {
  state = "available"
}
# ---------- LOCALS ----------
locals {
  # azs = data.aws_availability_zones.available.names
  azs = slice(data.aws_availability_zones.available.names, 0, 2) # We pick 2 AZs to avoid creating a lot of subnets

  # CIDRs per AZ (keys = AZ).
  public_cidrs = {
    for i, az in local.azs : az => cidrsubnet("10.0.0.0/16", 8, i)          # 10.0.0.0/24, 10.0.1.0/24
  }
  private_cidrs = {
    for i, az in local.azs : az => cidrsubnet("10.0.0.0/16", 8, 100 + i)    # 10.0.100.0/24, 10.0.101.0/24
  }
}

# ---------- VPC ----------
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = {
    Name    = "${var.cluster_name}_main_vpc"
    Project = var.cluster_name
  }
}

# ---------- SUBNETS ----------
resource "aws_subnet" "public" {
  for_each = local.public_cidrs

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.cluster_name}-public-${each.key}"
    "kubernetes.io/role/elb" = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# ---------- INTERNET GATEWAY ----------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "${var.cluster_name}-igw" }
}

# ---------- ROUTE TABLE ----------

# Route table pública + default route a IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags = { Name = "${var.cluster_name}-rt-public" }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# NAT (únic) per estalviar quota. L’ubiquem a la subnet pública de la 1a AZ.
resource "aws_eip" "nat" {
  domain = "vpc"
  tags = { Name = "${var.cluster_name}-nat-eip" }
}