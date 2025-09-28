#!/bin/bash

# Validação de parâmetros
if [ $# -ne 2 ]; then
    echo "Uso: $0 <cluster-name> <service-name>"
    exit 1
fi

CLUSTER_NAME=$1
SERVICE_NAME=$2

# Obter commit hash (7 dígitos)
COMMIT_HASH=$(git rev-parse --short=7 HEAD)
if [ -z "$COMMIT_HASH" ]; then
    echo "Erro: Não foi possível obter o commit hash"
    exit 1
fi

echo "Deploy iniciado - Commit: $COMMIT_HASH"

# Obter account ID e região
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=$(aws configure get region 2>/dev/null || echo "us-east-1")
ECR_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/bia:$COMMIT_HASH"

# Build e push da imagem
echo "Building imagem Docker..."
docker build -t bia:$COMMIT_HASH .

echo "Fazendo login no ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

echo "Tagging e enviando para ECR..."
docker tag bia:$COMMIT_HASH $ECR_URI
docker push $ECR_URI

# Obter task definition atual
TASK_DEF_ARN=$(aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --query 'services[0].taskDefinition' --output text)
TASK_DEF_FAMILY=$(aws ecs describe-task-definition --task-definition $TASK_DEF_ARN --query 'taskDefinition.family' --output text)

# Criar nova task definition
echo "Atualizando task definition..."
aws ecs describe-task-definition --task-definition $TASK_DEF_ARN --query 'taskDefinition' > temp-task-def.json

# Atualizar imagem na task definition
jq --arg image "$ECR_URI" '.containerDefinitions[0].image = $image | del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .placementConstraints, .compatibilities, .registeredAt, .registeredBy)' temp-task-def.json > new-task-def.json

# Registrar nova task definition
NEW_TASK_DEF=$(aws ecs register-task-definition --cli-input-json file://new-task-def.json --query 'taskDefinition.taskDefinitionArn' --output text)

# Atualizar serviço
echo "Atualizando serviço ECS..."
aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --task-definition $NEW_TASK_DEF

# Cleanup
rm temp-task-def.json new-task-def.json

echo "Deploy concluído - Versão: $COMMIT_HASH"
echo "Task Definition: $NEW_TASK_DEF"
