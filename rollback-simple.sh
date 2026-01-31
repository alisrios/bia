#!/bin/bash

# Rollback Simples BIA
# Complementa o deploy-simple.sh

set -e

if [ -z "$1" ]; then
    echo "Uso: ./rollback-simple.sh <commit-hash>"
    echo
    echo "Versões disponíveis:"
    aws ecr describe-images --repository-name bia --region us-east-1 --query 'sort_by(imageDetails,&imagePushedAt)[*].[imageTags[0],imagePushedAt]' --output table
    exit 1
fi

# Configurações
REGION="us-east-1"
ECR_REPO="bia"
CLUSTER="cluster-bia"
SERVICE="service-bia"
TASK_FAMILY="task-def-bia"
TARGET_TAG="$1"

# Cores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$ECR_REPO"

log "=== ROLLBACK BIA - VERSÃO: $TARGET_TAG ==="

# Verificar se a imagem existe
if ! aws ecr describe-images --repository-name $ECR_REPO --region $REGION --image-ids imageTag=$TARGET_TAG > /dev/null 2>&1; then
    echo "Erro: Imagem com tag '$TARGET_TAG' não encontrada"
    exit 1
fi

# Nova Task Definition
log "Criando Task Definition para rollback..."
CURRENT_TASK=$(aws ecs describe-task-definition --task-definition $TASK_FAMILY --region $REGION --query 'taskDefinition')

NEW_TASK=$(echo "$CURRENT_TASK" | jq --arg image "$ECR_URI:$TARGET_TAG" '
  .containerDefinitions[0].image = $image |
  del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .placementConstraints, .compatibilities, .registeredAt, .registeredBy)
')

NEW_REVISION=$(echo "$NEW_TASK" | aws ecs register-task-definition --region $REGION --cli-input-json file:///dev/stdin --query 'taskDefinition.revision' --output text)

# Update Service
log "Atualizando serviço..."
aws ecs update-service --region $REGION --cluster $CLUSTER --service $SERVICE --task-definition $TASK_FAMILY:$NEW_REVISION > /dev/null

success "Rollback concluído!"
success "Versão: $TARGET_TAG"
success "Task Definition: $TASK_FAMILY:$NEW_REVISION"

log "Aguardando estabilização..."
aws ecs wait services-stable --region $REGION --cluster $CLUSTER --services $SERVICE
success "Serviço estável!"
