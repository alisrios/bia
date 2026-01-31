#!/bin/bash

# Lista versões disponíveis no ECR de forma amigável

REGION="us-east-1"
ECR_REPO="bia"

echo "=== VERSÕES DISPONÍVEIS NO ECR ==="
echo

# Listar imagens ordenadas por data
aws ecr describe-images \
    --repository-name $ECR_REPO \
    --region $REGION \
    --query 'sort_by(imageDetails,&imagePushedAt)[*].[imageTags[0],imagePushedAt,imageSizeInBytes]' \
    --output table

echo
echo "Para fazer rollback:"
echo "  ./rollback-simple.sh <commit-hash>"
echo
echo "Para ver detalhes de uma versão específica:"
echo "  aws ecr describe-images --repository-name $ECR_REPO --region $REGION --image-ids imageTag=<commit-hash>"
