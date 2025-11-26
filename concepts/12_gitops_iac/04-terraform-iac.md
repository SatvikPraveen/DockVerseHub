# Terraform: Infrastructure as Code

**Duration:** 1.5 hours | **Level:** Advanced

---

## 🎯 What is Terraform?

Terraform is an open-source Infrastructure as Code (IaC) tool that enables you to define and provision cloud resources using declarative configuration files.

**Key Features:**
- Declarative resource definition
- Multi-cloud support (AWS, Azure, GCP, etc.)
- State management
- Modularity and reusability
- Plan before apply
- Infrastructure versioning

---

## 🏗️ Core Concepts

### Providers

Tell Terraform which cloud platform to use.

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}
```

### Resources

Define infrastructure components.

```hcl
# Create EC2 instance
resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  
  tags = {
    Name = "web-server"
  }
}

# Create security group
resource "aws_security_group" "allow_web" {
  name        = "allow_web"
  description = "Allow web traffic"
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

### Variables

Make configurations reusable.

```hcl
variable "instance_type" {
  type    = string
  default = "t2.micro"
}

variable "environment" {
  type = string
}

resource "aws_instance" "web" {
  instance_type = var.instance_type
  
  tags = {
    Environment = var.environment
  }
}
```

### Outputs

Return values from configuration.

```hcl
output "instance_id" {
  value = aws_instance.web.id
}

output "public_ip" {
  value       = aws_instance.web.public_ip
  description = "Public IP of the instance"
}
```

---

## 📁 Project Structure

### Simple Project

```
terraform/
├─ main.tf
├─ variables.tf
├─ outputs.tf
└─ terraform.tfvars
```

### Multi-Environment Project

```
terraform/
├─ modules/
│  ├─ vpc/
│  │  ├─ main.tf
│  │  ├─ variables.tf
│  │  └─ outputs.tf
│  ├─ compute/
│  └─ database/
├─ environments/
│  ├─ dev/
│  │  ├─ main.tf
│  │  ├─ variables.tf
│  │  └─ terraform.tfvars
│  ├─ staging/
│  └─ prod/
└─ global/
   └─ terraform.tf
```

---

## 🚀 Kubernetes with Terraform

### EKS Cluster

```hcl
# Create EKS cluster
resource "aws_eks_cluster" "main" {
  name            = "my-cluster"
  role_arn        = aws_iam_role.cluster_role.arn
  version         = "1.27"
  
  vpc_config {
    subnet_ids = aws_subnet.main.*.id
  }
}

# Create node group
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "main"
  node_role_arn   = aws_iam_role.node_role.arn
  subnet_ids      = aws_subnet.main.*.id
  
  scaling_config {
    desired_size = 3
    max_size     = 5
    min_size     = 1
  }
}

output "cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}
```

### Kubernetes Resources with Terraform

```hcl
# Deploy application to Kubernetes
provider "kubernetes" {
  host                   = aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.main.token
}

resource "kubernetes_deployment" "app" {
  metadata {
    name = "my-app"
  }
  
  spec {
    replicas = 3
    
    selector {
      match_labels = {
        app = "my-app"
      }
    }
    
    template {
      metadata {
        labels = {
          app = "my-app"
        }
      }
      
      spec {
        container {
          image = "my-app:v1.0"
          name  = "app"
          
          port {
            container_port = 8080
          }
        }
      }
    }
  }
}

# Create service
resource "kubernetes_service" "app" {
  metadata {
    name = "my-app"
  }
  
  spec {
    selector = {
      app = "my-app"
    }
    
    port {
      port        = 80
      target_port = 8080
    }
    
    type = "LoadBalancer"
  }
}
```

---

## 📋 Workflow

### Basic Workflow

```bash
# 1. Write configuration
cat > main.tf << 'EOF'
resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
}
EOF

# 2. Initialize
terraform init

# 3. Plan (preview changes)
terraform plan

# 4. Apply (create resources)
terraform apply

# 5. Verify
terraform show

# 6. Destroy (cleanup)
terraform destroy
```

### Planning

```bash
# View plan without applying
terraform plan -out=plan.tfplan

# Review and manually apply
terraform apply plan.tfplan

# Save plan for later
terraform plan -out=/tmp/my.plan
terraform apply /tmp/my.plan
```

---

## 🔐 State Management

### Local State

```bash
# Default - stores in terraform.tfstate
terraform apply

# WARNING: Don't commit to Git!
echo "terraform.tfstate" >> .gitignore
```

### Remote State (S3)

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

### State Commands

```bash
# View current state
terraform show

# List resources
terraform state list

# Show resource details
terraform state show aws_instance.web

# Remove resource from state (without deleting)
terraform state rm aws_instance.web

# Replace resource
terraform state replace-provider \
  hashicorp/aws \
  registry.terraform.io/hashicorp/aws
```

---

## 🧩 Modules

### Create Module

```
modules/
└─ vpc/
   ├─ main.tf
   ├─ variables.tf
   └─ outputs.tf
```

**modules/vpc/main.tf:**
```hcl
resource "aws_vpc" "main" {
  cidr_block = var.cidr_block
  
  tags = {
    Name = var.name
  }
}

resource "aws_subnet" "main" {
  count             = length(var.subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnets[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
}
```

**modules/vpc/variables.tf:**
```hcl
variable "name" {
  type = string
}

variable "cidr_block" {
  type = string
}

variable "subnets" {
  type = list(string)
}
```

**modules/vpc/outputs.tf:**
```hcl
output "vpc_id" {
  value = aws_vpc.main.id
}

output "subnet_ids" {
  value = aws_subnet.main[*].id
}
```

### Use Module

```hcl
module "vpc" {
  source = "./modules/vpc"
  
  name       = "production"
  cidr_block = "10.0.0.0/16"
  subnets    = ["10.0.1.0/24", "10.0.2.0/24"]
}

output "vpc_id" {
  value = module.vpc.vpc_id
}
```

---

## 🎓 Example: Complete Kubernetes on AWS

```hcl
# variables.tf
variable "cluster_name" {
  type    = string
  default = "my-cluster"
}

variable "node_count" {
  type    = number
  default = 3
}

# main.tf
provider "aws" {
  region = "us-east-1"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
}

# Subnets
resource "aws_subnet" "main" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
}

# EKS Cluster
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  
  vpc_config {
    subnet_ids = aws_subnet.main[*].id
  }
}

# Node Group
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "main"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = aws_subnet.main[*].id
  
  scaling_config {
    desired_size = var.node_count
    max_size     = var.node_count + 2
    min_size     = 1
  }
}

# outputs.tf
output "cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}

output "cluster_name" {
  value = aws_eks_cluster.main.name
}
```

---

## 🔄 Environment Promotion

### Dev Environment

**environments/dev/terraform.tfvars:**
```hcl
cluster_name = "dev-cluster"
node_count   = 1
instance_type = "t2.small"
```

### Production Environment

**environments/prod/terraform.tfvars:**
```hcl
cluster_name = "prod-cluster"
node_count   = 5
instance_type = "t3.large"
```

### Deploy

```bash
# Deploy to dev
cd environments/dev
terraform init
terraform apply -var-file=terraform.tfvars

# Deploy to prod
cd environments/prod
terraform init
terraform apply -var-file=terraform.tfvars
```

---

## 🛠️ Advanced Features

### Workspaces

```bash
# Create workspace
terraform workspace new prod

# Switch workspace
terraform workspace select prod

# List workspaces
terraform workspace list

# Each workspace has separate state
terraform apply
```

### Data Sources

```hcl
# Get existing AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Use in resource
resource "aws_instance" "web" {
  ami = data.aws_ami.ubuntu.id
}
```

### Conditionals

```hcl
variable "enable_monitoring" {
  type    = bool
  default = false
}

resource "aws_cloudwatch_metric_alarm" "cpu" {
  count               = var.enable_monitoring ? 1 : 0
  alarm_name          = "high-cpu"
  comparison_operator = "GreaterThanThreshold"
  threshold           = "80"
}
```

---

## 📚 Best Practices

1. **Use modules for reusability**
   ```hcl
   module "vpc" {
     source = "./modules/vpc"
   }
   ```

2. **Version your modules**
   ```hcl
   module "vpc" {
     source = "git::https://github.com/org/vpc.git//modules/vpc?ref=v1.0.0"
   }
   ```

3. **Never hardcode sensitive values**
   ```hcl
   variable "db_password" {
     type      = string
     sensitive = true
   }
   ```

4. **Use remote state**
   ```hcl
   terraform {
     backend "s3" {
       bucket = "terraform-state"
     }
   }
   ```

5. **Plan before apply**
   ```bash
   terraform plan -out=plan.tfplan
   terraform apply plan.tfplan
   ```

---

## 🔗 Terraform + Kubernetes + GitOps

```
Git Repository
  ├─ terraform/  (Infrastructure as Code)
  │  └─ eks-cluster.tf
  └─ kubernetes/  (GitOps with Flux/ArgoCD)
     └─ deployments/

CI/CD Pipeline:
  1. terraform plan (validate)
  2. terraform apply (create cluster)
  3. ArgoCD/Flux syncs apps to cluster
  4. Complete infrastructure + applications deployed
```

---

## 📋 Key Takeaways

1. ✅ Terraform enables Infrastructure as Code
2. ✅ Declarative resource definition
3. ✅ Multi-cloud support
4. ✅ State management
5. ✅ Modules for reusability
6. ✅ Plan before apply

---

## 🔗 Next Steps

1. Install Terraform
2. Deploy simple infrastructure
3. Try Kubernetes with Terraform
4. Explore modules
5. Integrate with GitOps

