```yaml
build-and-push:
  stage: build-push
  image:
    name: gcr.io/kaniko-project/executor:v1.9.0-debug
    entrypoint: [""]
  variables:
    ECR_REGISTRY: 123456789012.dkr.ecr.us-east-1.amazonaws.com
    ECR_REPOSITORY_URL: 123456789012.dkr.ecr.us-east-1.amazonaws.com/my-app
  before_script:
    - apk add --no-cache aws-cli
    - mkdir -p /kaniko/.docker
    # Method 1: Direct docker config creation
    - |
      echo '{"auths":{"'$ECR_REGISTRY'":{"auth":"'$(echo -n "AWS:$(aws ecr get-login-password --region $AWS_REGION)" | base64 -w 0)'"}}}' > /kaniko/.docker/config.json
  script:
    - /kaniko/executor 
      --context $CI_PROJECT_DIR
      --dockerfile $CI_PROJECT_DIR/Dockerfile
      --destination $ECR_REPOSITORY_URL:$CI_COMMIT_SHA
      --destination $ECR_REPOSITORY_URL:latest

```
