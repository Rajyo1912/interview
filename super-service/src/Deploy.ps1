$repositoryName = "SuperService"
$imageTag = "2042/6"
$ecsClusterName = "SuperService/dev"
$ecsServiceName = "dev-cluster"
#$dockerfilePath = "./"
$taskDefinitionFile = "task-def.json"
$region = "us-west-2"

Write-Output "Building Docker image..."
docker build -t ${repositoryName}:$imageTag .

$accountId = (aws sts get-caller-identity --query Account --output text)

# ecr login

$ecrLoginCommand = $(aws ecr get-login-password --region $region | docker login --username AWS --password-stdin $accountId.dkr.ecr.$region.amazonaws.com)
Invoke-Expression $ecrLoginCommand

#image tagging
docker tag ${ecrRepositoryName}:$imageTag $accountId.dkr.ecr.$region.amazonaws.com/${ecrRepositoryName}:$imageTag

#Pushing image to hub
docker push $accountId.dkr.ecr.$region.amazonaws.com/{$ecrRepositoryName}:$imageTag

#update cluster
$taskDefinition = Get-Content $taskDefinitionFile -Raw | ConvertFrom-Json
$taskDefinition.containerDefinitions[0].image = "$accountId.dkr.ecr.$region.amazonaws.com/${ecrRepositoryName}:$imageTag"
$updatedTaskDefinitionFile = "$($taskDefinition.family)-updated.json"
$taskDefinition | ConvertTo-Json -Depth 10 | Set-Content $updatedTaskDefinitionFile

$newTaskDefinitionArn = (aws ecs register-task-definition --cli-input-json (Get-Content $updatedTaskDefinitionFile -Raw) --region $region --query 'taskDefinition.taskDefinitionArn' --output text)

aws ecs update-service --cluster $ecsClusterName --service $ecsServiceName --task-definition $newTaskDefinitionArn --region $region

Write-Host "Docker image built and pushed to ECR, and ECS service updated successfully."
