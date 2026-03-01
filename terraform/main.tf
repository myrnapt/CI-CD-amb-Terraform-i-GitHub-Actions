# ============================================================
# main.tf — Infraestructura base para EKS (Terraform + AWS)
# - Crea VPC, subnets públicas/privadas, IGW, NAT, rutas
# - Etiqueta subnets para que Kubernetes/EKS pueda crear ELBs
# - Crea el EKS Cluster + Node Group (workers)
# ============================================================


# ---------- DATA ----------
# Lista de Availability Zones disponibles en la región configurada
data "aws_availability_zones" "available" {
  state = "available"
}

# Busca roles IAM existentes cuyo nombre contenga "LabEksClusterRole"
data "aws_iam_roles" "cluster_roles" {
  name_regex = ".*LabEksClusterRole.*"
}

# Busca roles IAM existentes cuyo nombre contenga "LabEksNodeRole"
data "aws_iam_roles" "node_roles" {
  name_regex = ".*LabEksNodeRole.*"
}

# ---------- LOCALS (cálculos internos) ----------
locals {
  # Selecciona solo 2 AZs para no crear demasiadas subnets (y evitar límites/cuotas).
  # Nota: en producción se suele usar 2–3 AZs según resiliencia/coste.
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  # CIDRs por AZ (clave = AZ).
  # cidrsubnet("10.0.0.0/16", 8, i) => subredes /24 dentro de un /16
  # Public:  10.0.0.0/24, 10.0.1.0/24 ...
  public_cidrs = {
    for i, az in local.azs : az => cidrsubnet("10.0.0.0/16", 8, i)
  }

  # Private: 10.0.100.0/24, 10.0.101.0/24 ...
  # Se desplaza el índice (100+i) para separar el rango y hacerlo más legible.
  private_cidrs = {
    for i, az in local.azs : az => cidrsubnet("10.0.0.0/16", 8, 100 + i)
  }

  # Toma el primer ARN encontrado para el rol del cluster y del nodegroup.
  # IMPORTANTE: si hubiera más de uno, esto "elige el primero" sin garantizar cuál.
  # En entornos reales conviene filtrar mejor o referenciar un rol exacto.

  # eks_cluster_role_arn = tolist(data.aws_iam_roles.cluster_roles.arns)[0]
  # eks_node_role_arn    = tolist(data.aws_iam_roles.node_roles.arns)[0]

  eks_cluster_role_arn = one(data.aws_iam_roles.cluster_roles.arns)
  eks_node_role_arn    = one(data.aws_iam_roles.node_roles.arns)

  # Primera AZ (se usa para ubicar el NAT Gateway en una subnet pública)
  first_az = local.azs[0]
}

# ---------- VPC ----------
resource "aws_vpc" "main" {
  # Rango CIDR de la VPC (viene por variable)
  cidr_block = var.vpc_cidr

  tags = {
    Name    = "${var.cluster_name}_main_vpc"
    Project = var.cluster_name
  }
}


# ---------- SUBNETS PÚBLICAS ----------
resource "aws_subnet" "public" {
  # Crea 1 subnet pública por AZ (las claves vienen de local.public_cidrs)
  for_each = local.public_cidrs

  vpc_id            = aws_vpc.main.id
  availability_zone = each.key
  cidr_block        = each.value

  # En subnets públicas se suelen asignar IP pública a instancias al lanzar.
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.cluster_name}-public-${each.key}"

    # Etiqueta estándar para EKS/Kubernetes:
    # indica que esta subnet se puede usar para ELB "externo" (internet-facing).
    "kubernetes.io/role/elb" = "1"

    # Etiqueta estándar del cluster (permite a EKS descubrir recursos compartidos)
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# ---------- INTERNET GATEWAY ----------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.cluster_name}-igw" }
}



# ---------- ROUTING TABLES ----------
# PUBLIC RT
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.cluster_name}-rt-public" }
}

# ROUTE FROM PUBLIC SUBNET TO INTERNET VIA IGW
resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# RTA PUBLIC ROUTE - PUBLIC SUBNETS
resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}


# ---------- NAT Gateway ----------
# EIP para el NAT
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${var.cluster_name}-nat-eip" }
}

# NAT Gateway:
# - Permite que instancias en subnets privadas salgan a Internet (pull de imágenes, updates, etc.)
# - Se ubica en una subnet pública
# Nota: aquí se crea UNO para ahorrar coste (single point of failure por AZ).
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[local.first_az].id

  # Asegura que el IGW exista antes (dependencia explícita)
  depends_on = [aws_internet_gateway.igw]

  tags = { Name = "${var.cluster_name}-nat" }
}


# -------------------------
# SUBNETS PRIVADAS
# -------------------------
resource "aws_subnet" "private" {
  # Crea 1 subnet privada por AZ
  for_each = local.private_cidrs

  vpc_id            = aws_vpc.main.id
  availability_zone = each.key
  cidr_block        = each.value

  # En subnets privadas NO se asigna IP pública automáticamente
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.cluster_name}-private-${each.key}"

    # Etiqueta estándar para EKS/Kubernetes:
    # indica que esta subnet se puede usar para ELB interno (internal load balancer).
    "kubernetes.io/role/internal-elb" = "1"

    # Etiqueta estándar del cluster
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}


# -------------------------
# ROUTING PRIVADO
# -------------------------

# Tabla de rutas privada
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.cluster_name}-rt-private" }
}

# Ruta por defecto a Internet vía NAT (para subnets privadas)
resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

# Asociar la route table privada a todas las subnets privadas
resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}


# -------------------------
# OUTPUTS (útil para módulos/depuración)
# -------------------------
output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnets" {
  value = [for s in aws_subnet.public : s.id]
}

output "private_subnets" {
  value = [for s in aws_subnet.private : s.id]
}


# ============================================================
# EKS (Kubernetes gestionado)
# ============================================================

# -------------------------
# EKS Cluster (control plane)
# -------------------------
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = local.eks_cluster_role_arn

  vpc_config {
    # Se pasan subnets públicas y privadas.
    # EKS puede usar ambas para el networking, y Kubernetes decidirá dónde crear ELBs
    # en función de annotations/Service type + tags kubernetes.io/role/*.
    subnet_ids = concat(
      [for s in aws_subnet.public : s.id],
      [for s in aws_subnet.private : s.id]
    )

    # Security Group del control plane (acceso al API server, etc.)
    security_group_ids = [aws_security_group.eks_control_plane.id]

    # API endpoint accesible desde Internet (kubectl desde fuera)
    endpoint_public_access = true

    # API endpoint accesible desde dentro de la VPC (nodos privados y/o bastion)
    endpoint_private_access = true
  }
}


# -------------------------
# Node Group (workers)
# -------------------------
resource "aws_eks_node_group" "workers" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "workers"

  # Rol IAM que usan los nodos (permisos para ECR, CloudWatch, CNI, etc.)
  node_role_arn = local.eks_node_role_arn

  # Los nodos se despliegan en subnets privadas (mejor práctica: no exponer nodos a Internet)
  subnet_ids = [for s in aws_subnet.private : s.id]

  # Auto Scaling básico del nodegroup
  scaling_config {
    desired_size = 2
    min_size     = 2
    max_size     = 3
  }

  # Tipo de instancia para nodos (coste/rendimiento)
  instance_types = ["t3.medium"]
}


# ============================================================
# Seguridad — Security Group del control plane EKS
# ============================================================

resource "aws_security_group" "eks_control_plane" {
  name        = "${var.cluster_name}-eks-cp-sg"
  description = "EKS control plane security group"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.cluster_name}-eks-cp-sg"
  }
}

# Permite acceso al API server (443) desde cualquier IP.
# OJO: esto es inseguro en producción. Idealmente se limitaría a:
# - IP pública concreta (tu red) o
# - VPN/bastion, y endpoint_public_access=false.
resource "aws_security_group_rule" "eks_api_from_me" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.eks_control_plane.id
  cidr_blocks       = ["0.0.0.0/0"] # Abierto a todo para evitar problemas durante pruebas
  description       = "Allow kubectl from my IP"
}

# Permite que los nodos (en subnets privadas) lleguen al API server (443).
# Esto es necesario para que los workers se registren y el cluster funcione.
resource "aws_security_group_rule" "eks_api_from_nodes" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.eks_control_plane.id
  cidr_blocks       = [for s in aws_subnet.private : s.cidr_block]
  description       = "Allow worker nodes to reach API"
}

# Salida total desde el control plane SG (egress any/any).
resource "aws_security_group_rule" "eks_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.eks_control_plane.id
  cidr_blocks       = ["0.0.0.0/0"]
}
