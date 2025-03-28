# tf-aws-infra

## AWS Networking Infrastructure with Terraform and GitHub Actions CI

This project provisions AWS networking infrastructure using Terraform and enforces CI/CD best practices through GitHub Actions.

## Table of Contents

- [Overview](#overview)

## Overview

Creates a highly available AWS network infrastructure with:
-  1 VPC
-  3 Public Subnets (across 3 AZs)
-  3 Private Subnets (across 3 AZs)
-  Internet Gateway
-  Route Tables with proper associations
-  Security Group for Web Application
-  EC2 Instance in Public Subnet
-  S3 bucket with Custom Policy and Role for EC2 to access S3
-  RDS with Security group and custom parameter

Enforces CI checks via GitHub Actions:
- Terraform formatting validation
- Terraform configuration validation
- Branch protection rules