#!/bin/bash

# Script para corrigir permissões do CodePipeline para CodeConnections
# Execute este script com permissões administrativas

echo "Corrigindo permissões do CodePipeline para usar CodeConnections..."

# Criar política inline para a role do CodePipeline
aws iam put-role-policy \
    --role-name "AWSCodePipelineServiceRole-us-east-1-bia-github" \
    --policy-name "CodeConnectionsAccess" \
    --policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "codeconnections:UseConnection"
                ],
                "Resource": "arn:aws:codeconnections:us-east-1:148761658767:connection/0e9d83e8-f942-48d3-8535-e8b0cab9f3e5"
            }
        ]
    }' \
    --region us-east-1

if [ $? -eq 0 ]; then
    echo "✅ Permissões adicionadas com sucesso!"
    echo "A role do CodePipeline agora pode usar a conexão do GitHub."
else
    echo "❌ Erro ao adicionar permissões. Verifique se você tem permissões administrativas."
fi

echo ""
echo "Verificando se a política foi aplicada..."
aws iam get-role-policy \
    --role-name "AWSCodePipelineServiceRole-us-east-1-bia-github" \
    --policy-name "CodeConnectionsAccess" \
    --region us-east-1

echo ""
echo "Agora você pode executar o pipeline novamente."
