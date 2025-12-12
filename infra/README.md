# Multi-Region Dev/Prod VPCs with Peering

This repo defines a reusable VPC module and two environments (dev, prod).  
Each environment creates:
- Primary VPC in us-east-1
- Secondary VPC in us-west-2
- Cross-region VPC peering between those two VPCs only

There is **no peering between dev and prod**.

## Layout

- modules/vpc: reusable VPC (subnets, IGW, NAT, routes, S3 endpoint)
- envs/dev: dev VPCs + east–west peering
- envs/prod: prod VPCs + east–west peering

## Usage

Dev
cd infra/envs/dev 
terraform init 
terraform validate 
terraform plan 
terraform apply

Prod
cd infra/envs/prod 
terraform init 
terraform validate 
terraform plan 
terraform apply

Edit each environment’s `terraform.tfvars` and `providers.tf` for CIDRs, names, tags, and regions.


