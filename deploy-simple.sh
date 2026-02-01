#!/bin/bash

# Deploy Simples BIA - Versionamento por Commit Hash
# Não sobrepõe o deploy-ecs.sh existente

set -e

# Configurações
REGION="us-east-1"
ECR_REPO="bia"
CLUSTER="cluster-bia-alb"
SERVICE="service-bia-alb"
TASK_FAMILY="task-def-bia-alb"

# Cores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Obter commit hash
COMMIT_HASH=$(git rev-parse --short=7 HEAD 2>/dev/null || error "Não é um repositório Git")
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$ECR_REPO"

log "=== DEPLOY BIA - VERSÃO: $COMMIT_HASH ==="
log "ECR: $ECR_URI:$COMMIT_HASH"
log "Cluster: $CLUSTER"
log "Service: $SERVICE"

# 1. Login ECR
log "1. Login ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

# 2. Build
log "2. Build da imagem..."
docker build -t $ECR_URI:$COMMIT_HASH -t $ECR_URI:latest .

# 3. Push
log "3. Push para ECR..."
docker push $ECR_URI:$COMMIT_HASH
docker push $ECR_URI:latest

# 4. Nova Task Definition
log "4. Criando Task Definition..."
TEMP_FILE=$(mktemp)
aws ecs describe-task-definition --task-definition $TASK_FAMILY --region $REGION --query 'taskDefinition' > $TEMP_FILE

jq --arg image "$ECR_URI:$COMMIT_HASH" '
  .containerDefinitions[0].image = $image |
  del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .placementConstraints, .compatibilities, .registeredAt, .registeredBy)
' $TEMP_FILE > ${TEMP_FILE}.new

NEW_REVISION=$(aws ecs register-task-definition --region $REGION --cli-input-json file://${TEMP_FILE}.new --query 'taskDefinition.revision' --output text)
rm -f $TEMP_FILE ${TEMP_FILE}.new

# 5. Update Service
log "5. Atualizando serviço..."
aws ecs update-service --region $REGION --cluster $CLUSTER --service $SERVICE --task-definition $TASK_FAMILY:$NEW_REVISION > /dev/null

success "Deploy concluído!"
success "Versão: $COMMIT_HASH"
success "Task Definition: $TASK_FAMILY:$NEW_REVISION"

log "Aguardando estabilização..."
aws ecs wait services-stable --region $REGION --cluster $CLUSTER --services $SERVICE
success "Serviço estável!"
