# Three-Tier Application on AWS with Terraform

This project provisions a complete three-tier architecture (Web, App, DB) on AWS using Terraform, demonstrating IaC principles, network segmentation, security practices, and modular scalability.

## 🧱 Architecture Overview

- **Web Tier**: Public EC2 instances behind an Application Load Balancer
- **App Tier**: Private EC2 instances handling backend logic
- **Database Tier**: Amazon RDS (MySQL) in a private subnet

## 📦 Stack Details

| Component     | Service              |
|---------------|----------------------|
| IaC Tool      | Terraform             |
| Cloud Provider| AWS                   |
| DB Engine     | MySQL on Amazon RDS   |
| Networking    | VPC, Subnets, SGs     |

## 🚀 Deploy

```bash
terraform init
terraform plan
terraform apply

```
## Challenges
1. Unable to scale the app tier instances due to inability for the ALB to mark them "healthy"
2. 

## 🛠️ To Be Improved
- [ ] Modularize Terraform structure (variables, outputs, reusability)
- [ ] RDS Multi-AZ Failover Configuration
- [ ] Enhanced DB credentials handling via AWS Secrets Manager
- [ ] 

##  Photos

![Screenshot_25-7-2025_19178_eu-west-1 console aws amazon com](https://github.com/user-attachments/assets/50cd3f4e-b198-450d-b776-3153e0b013ca)

![Screenshot_29-7-2025_132859_eu-west-1 console aws amazon com](https://github.com/user-attachments/assets/26a8125c-9112-4f7b-b2d9-99bb53c05b43)


![Screenshot_29-7-2025_132935_eu-west-1 console aws amazon com](https://github.com/user-attachments/assets/830c9a5b-cde2-4a4a-9333-a2b361cfa199)
