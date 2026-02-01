#!/bin/bash

# Análise Prévia do Deploy BIA
# Mostra o que será feito antes de executar

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
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "=== ANÁLISE PRÉVIA DO DEPLOY BIA ==="
echo

# 1. Verificar Git
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    error "Não é um repositório Git"
fi

COMMIT_HASH=$(git rev-parse --short=7 HEAD)
COMMIT_MSG=$(git log -1 --pretty=format:"%s")
BRANCH=$(git branch --show-current)

log "Git Status:"
echo "  Branch: $BRANCH"
echo "  Commit: $COMMIT_HASH"
echo "  Mensagem: $COMMIT_MSG"
echo

# 2. Verificar AWS
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || error "Erro ao acessar AWS")
ECR_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$ECR_REPO"

log "AWS Status:"
echo "  Account: $ACCOUNT_ID"
echo "  Região: $REGION"
echo "  ECR URI: $ECR_URI"
echo

# 3. Verificar ECR
log "Verificando ECR..."
if aws ecr describe-repositories --repository-names $ECR_REPO --region $REGION > /dev/null 2>&1; then
    success "Repositório ECR existe"
    
    # Verificar se a tag já existe
    if aws ecr describe-images --repository-name $ECR_REPO --region $REGION --image-ids imageTag=$COMMIT_HASH > /dev/null 2>&1; then
        warn "Tag $COMMIT_HASH já existe no ECR (será sobrescrita)"
    else
        success "Tag $COMMIT_HASH é nova"
    fi
else
    error "Repositório ECR '$ECR_REPO' não encontrado"
fi
echo

# 4. Verificar ECS
log "Verificando ECS..."

# Cluster
if aws ecs describe-clusters --clusters $CLUSTER --region $REGION --query 'clusters[0].status' --output text 2>/dev/null | grep -q "ACTIVE"; then
    success "Cluster '$CLUSTER' ativo"
else
    error "Cluster '$CLUSTER' não encontrado ou inativo"
fi

# Service
if aws ecs describe-services --cluster $CLUSTER --services $SERVICE --region $REGION --query 'services[0].status' --output text 2>/dev/null | grep -q "ACTIVE"; then
    success "Service '$SERVICE' ativo"
    
    # Task Definition atual
    CURRENT_TASK_DEF=$(aws ecs describe-services --cluster $CLUSTER --services $SERVICE --region $REGION --query 'services[0].taskDefinition' --output text)
    CURRENT_REVISION=$(echo $CURRENT_TASK_DEF | cut -d':' -f2)
    
    echo "  Task Definition atual: $CURRENT_TASK_DEF"
    
    # Imagem atual
    CURRENT_IMAGE=$(aws ecs describe-task-definition --task-definition $CURRENT_TASK_DEF --region $REGION --query 'taskDefinition.containerDefinitions[0].image' --output text)
    echo "  Imagem atual: $CURRENT_IMAGE"
    
else
    error "Service '$SERVICE' não encontrado ou inativo"
fi

# Task Definition Family
if aws ecs describe-task-definition --task-definition $TASK_FAMILY --region $REGION > /dev/null 2>&1; then
    success "Task Definition Family '$TASK_FAMILY' existe"
else
    error "Task Definition Family '$TASK_FAMILY' não encontrada"
fi
echo

# 5. Verificar Dockerfile
log "Verificando Dockerfile..."
if [ -f "Dockerfile" ]; then
    success "Dockerfile encontrado"
    
    # Mostrar informações básicas
    BASE_IMAGE=$(grep "^FROM" Dockerfile | head -1 | cut -d' ' -f2)
    echo "  Imagem base: $BASE_IMAGE"
    
    EXPOSE_PORT=$(grep "^EXPOSE" Dockerfile | head -1 | cut -d' ' -f2 2>/dev/null || echo "Não especificada")
    echo "  Porta exposta: $EXPOSE_PORT"
else
    error "Dockerfile não encontrado"
fi
echo

# 6. Resumo do que será feito
echo "=== RESUMO DO DEPLOY ==="
echo "✓ Build da imagem: $ECR_URI:$COMMIT_HASH"
echo "✓ Push para ECR"
echo "✓ Nova Task Definition: $TASK_FAMILY:$(($CURRENT_REVISION + 1))"
echo "✓ Update do Service: $SERVICE"
echo "✓ Aguardar estabilização"
echo

# 7. Verificar mudanças não commitadas
if ! git diff-index --quiet HEAD --; then
    warn "Existem mudanças não commitadas!"
    echo "Arquivos modificados:"
    git diff --name-only
    echo
fi

echo "=== COMANDOS DISPONÍVEIS ==="
echo "Para executar o deploy:"
echo "  ./deploy-simple.sh"
echo
echo "Para ver versões no ECR:"
echo "  aws ecr describe-images --repository-name $ECR_REPO --region $REGION --query 'imageDetails[*].imageTags[0]' --output table"
echo
echo "Para rollback:"
echo "  ./rollback-simple.sh <commit-hash>"
