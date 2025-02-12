ECR_REGISTRY="SEU_REGISTRY"
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REGISTRY
docker build -t bia-tf .
docker tag bia-tf:latest $ECR_REGISTRY/bia-tf:latest
docker push $ECR_REGISTRY/bia-tf:latest
