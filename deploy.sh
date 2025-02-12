./build.sh
aws ecs update-service --cluster cluster-bia-tf --service service-bia-tf --force-new-deployment