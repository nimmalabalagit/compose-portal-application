# modules/vpc/main.tf
#
# INTERVIEW TALKING POINT: EKS requires specific subnet tags for the
# AWS Load Balancer Controller to discover subnets automatically:
#   - Public subnets:  kubernetes.io/role/elb = "1"         ← ALB faces internet
#   - Private subnets: kubernetes.io/role/internal-elb = "1" ← internal NLB/ALB
#   - All subnets:     kubernetes.io/cluster/<name> = "shared" or "owned"
# Without these tags, ALB controller cannot provision load balancers.

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ── VPC ─────────────────────────────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true  # Required: EKS nodes need DNS hostname resolution
  enable_dns_support   = true  # Required: Pod DNS resolution via CoreDNS

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

# ── Internet Gateway ─────────────────────────────────────────────────────────
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name_prefix}-igw" }
}

# ── Public Subnets ────────────────────────────────────────────────────────────
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true  # ALB nodes need public IPs

  tags = {
    Name = "${local.name_prefix}-public-${var.availability_zones[count.index]}"
    # ALB Controller discovers public subnets via this tag
    "kubernetes.io/role/elb"                            = "1"
    "kubernetes.io/cluster/${local.name_prefix}-eks"    = "shared"
  }
}

# ── Private Subnets ───────────────────────────────────────────────────────────
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${local.name_prefix}-private-${var.availability_zones[count.index]}"
    # ALB Controller discovers private subnets via this tag (internal ALBs)
    "kubernetes.io/role/internal-elb"                   = "1"
    "kubernetes.io/cluster/${local.name_prefix}-eks"    = "shared"
    # Karpenter subnet discovery - NodePool selects subnets by this tag
    "karpenter.sh/discovery"                            = "${local.name_prefix}-eks"
  }
}

# ── NAT Gateway (one per AZ for HA) ──────────────────────────────────────────
# INTERVIEW TALKING POINT: Single NAT Gateway saves ~$100/month but is an AZ
# single-point-of-failure. For production, one NAT per AZ is mandatory.
# For dev/cost optimization, use a single NAT Gateway.

resource "aws_eip" "nat" {
  count  = length(var.public_subnet_cidrs)
  domain = "vpc"
  tags   = { Name = "${local.name_prefix}-nat-eip-${count.index}" }
}

resource "aws_nat_gateway" "main" {
  count = length(var.public_subnet_cidrs)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = { Name = "${local.name_prefix}-nat-${var.availability_zones[count.index]}" }

  depends_on = [aws_internet_gateway.main]
}

# ── Route Tables ──────────────────────────────────────────────────────────────
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${local.name_prefix}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# One private route table per AZ - routes to that AZ's NAT Gateway
resource "aws_route_table" "private" {
  count  = length(var.private_subnet_cidrs)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = { Name = "${local.name_prefix}-private-rt-${count.index}" }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}