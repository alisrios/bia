#!/bin/bash

echo "Forçando atualização do pipeline para reconhecer novas permissões..."

# Obter a configuração atual do pipeline
aws codepipeline get-pipeline --name "bia" --region us-east-1 > /tmp/pipeline-config.json

# Extrair apenas a parte do pipeline (sem metadata)
jq '.pipeline' /tmp/pipeline-config.json > /tmp/pipeline-only.json

# Atualizar o pipeline com a mesma configuração para forçar refresh
aws codepipeline update-pipeline --pipeline file:///tmp/pipeline-only.json --region us-east-1

if [ $? -eq 0 ]; then
    echo "✅ Pipeline atualizado com sucesso!"
    echo "Aguarde alguns segundos e tente executar novamente."
else
    echo "❌ Erro ao atualizar pipeline."
fi

# Limpar arquivos temporários
rm -f /tmp/pipeline-config.json /tmp/pipeline-only.json
