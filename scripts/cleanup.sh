#!/usr/bin/env bash

echo "-------------------------------------------------------"
echo " Running Terraform Destroy"
echo "-------------------------------------------------------"

cd terraform/nodes
terraform destroy -auto-approve

cd ../../terraform/consul
terraform destroy -auto-approve

cd ../../terraform/vpc
terraform destroy -auto-approve