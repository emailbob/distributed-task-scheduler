#!/usr/bin/env bash

echo "-------------------------------------------------------"
echo " Checking for Dependencies"
echo "-------------------------------------------------------"
if command -v aws >/dev/null 2>&1 ; then
  echo "AWS Installed"
  echo "$(aws --version)"
  echo
else
  echo "AWS CLI tools not installed"
fi

if command -v terraform >/dev/null 2>&1 ; then
  echo "$(terraform --version) Installed"
  echo
else
  echo "Terraform not installed"
fi

echo "-------------------------------------------------------"
echo " Checking for Valid AWS Credentials"
echo "-------------------------------------------------------"
aws sts get-caller-identity
echo

echo "-------------------------------------------------------"
echo " Creating SSH key"
echo "-------------------------------------------------------"
ssh-keygen -b 4096 -t rsa -f ~/.ssh/mp-ssh-key -q -N ""
echo

echo "-------------------------------------------------------"
echo " Running Terraform to bring up a VPC"
echo "-------------------------------------------------------"
cd terraform/vpc
terraform init
terraform apply -auto-approve
echo

echo "-------------------------------------------------------"
echo " Running Terraform to bring up consul"
echo "-------------------------------------------------------"
cd ../../terraform/consul
terraform init
terraform apply -auto-approve

echo "-------------------------------------------------------"
echo " Running Terraform to bring up test nodes"
echo "-------------------------------------------------------"
cd ../../terraform/nodes
terraform init
terraform apply -auto-approve