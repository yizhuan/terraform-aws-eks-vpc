# main.tf

# VPC subnet
resource "aws_vpc" "my_vpc" {
  cidr_block = var.vpc_cidr
}

#################################################
# DB
#################################################

# DB subnet
resource "aws_subnet" "private_subnet_0_db" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = var.private_subnet_db_0_cidr
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "private_subnet_1_db" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = var.private_subnet_db_1_cidr
  availability_zone = "us-east-1b"
}

# DB subnet group
resource "aws_db_subnet_group" "my_db_subnet_group" {
  name       = "my-db-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_0_db.id, aws_subnet.private_subnet_1_db.id]
}

# DB security group
resource "aws_security_group" "my_sg_db" {
  vpc_id = aws_vpc.my_vpc.id

  # Ingress rules for database (example: allow PostgreSQL port)
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ip]
  }
}

# DB
# can be tuned to support HA by adding multiple subnets to db_subnet_group_name
resource "aws_db_instance" "my_db" {
  allocated_storage      = 10
  db_name                = "mydb"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  username               = var.db_username
  password               = var.db_password
  parameter_group_name   = "default.mysql8.0"
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.my_sg_db.id] # Attach the security group
  db_subnet_group_name   = aws_db_subnet_group.my_db_subnet_group.name
}


#################################################
# ECR
#################################################

# ECR
resource "aws_ecr_repository" "my_ecr" {
  name = "my-ecr-repo"
}

resource "aws_ecr_repository_policy" "my_ecr_policy" {
  repository = aws_ecr_repository.my_ecr.name
  policy = jsonencode({
    Version = "2008-10-17",
    Statement = [
      {
        Sid       = "AllowPushPull",
        Effect    = "Allow",
        Principal = "*",
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
      }
    ]
  })
}


#################################################
# EKS subnets
#################################################

resource "aws_subnet" "public_subnet_eks" {
  count                   = 2
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = count.index == 0 ? var.public_subnet_eks_0_cidr : var.public_subnet_eks_1_cidr
  map_public_ip_on_launch = true
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)

  tags = {
    Name = "public_subnet_eks_${count.index}"
  }
}

resource "aws_subnet" "private_subnet_eks" {
  count             = 2
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = count.index == 0 ? var.private_subnet_eks_0_cidr : var.private_subnet_eks_1_cidr
  availability_zone = element(data.aws_availability_zones.available.names, count.index)

  tags = {
    Name = "private_subnet_eks_${count.index}"
  }
}

resource "aws_internet_gateway" "eks_igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "eks_igw"
  }
}

resource "aws_route_table" "eks_public_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks_igw.id
  }

  tags = {
    Name = "eks_public_route_table"
  }
}

resource "aws_route_table_association" "eks_public_route_table_association" {
  count          = length(aws_subnet.public_subnet_eks)
  subnet_id      = element(aws_subnet.public_subnet_eks.*.id, count.index)
  route_table_id = aws_route_table.eks_public_route_table.id
}


#################################################
# EKS cluster
#################################################

resource "aws_eks_cluster" "my_eks_cluster" {
  name     = "my-cluster"
  role_arn = aws_iam_role.eks_cluster.arn

  # Kubernetes master version
  # version = "2.25"

  vpc_config {

    endpoint_private_access = false

    # enable EKS public API server endpoint
    endpoint_public_access = true

    subnet_ids = [
      aws_subnet.public_subnet_eks[0].id,
      aws_subnet.public_subnet_eks[1].id
    ]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]

}

resource "aws_iam_role" "eks_cluster" {
  name = "eks_cluster_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "eks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach the necessary policies to the EKS cluster role
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}


#################################################
# EKS node group
#################################################

resource "aws_eks_node_group" "my_eks_node_group" {
  cluster_name    = aws_eks_cluster.my_eks_cluster.name
  node_group_name = "my-node-group"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids = [
    aws_subnet.private_subnet_eks[0].id,
  aws_subnet.private_subnet_eks[1].id]

  scaling_config {
    # desired number of worker nodes
    desired_size = 2

    # max number of worker nodes
    max_size = 3

    # min number of worker nodes
    min_size = 1
  }

  # ami_type =  AL2_x86_74_GPU  

  # valid values: ON_DEMAND, SPOT
  capacity_type = "SPOT"

  # Disk size in GB for worker nodes
  # disk_size = 100
  # disk_size = 20

  # instance_types = ["t3.small"]
  instance_types = ["t2.micro"]

  # Kubernetes version
  # version = 2.25

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ec2_policy
  ]
}

resource "aws_iam_role" "eks_nodes" {
  name = "eks_node_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

}

# Attach the necessary policies to the EKS node role
resource "aws_iam_role_policy_attachment" "eks_node_policy" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_ec2_policy" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}






