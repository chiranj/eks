```yaml

stages:
  - build-push

variables:
  # Use Kaniko debug image for better troubleshooting
  KANIKO_IMAGE: gcr.io/kaniko-project/executor:v1.9.0-debug

build-and-push:
  stage: build-push
  image:
    name: $KANIKO_IMAGE
    entrypoint: [""]
  before_script:
    # Install AWS CLI for ECR authentication
    - apk add --no-cache aws-cli
    # Create kaniko docker config directory
    - mkdir -p /kaniko/.docker
    # Login to ECR and create docker config
    - aws ecr get-login-password --region $AWS_REGION | crane auth login --username AWS --password-stdin $ECR_REPOSITORY_URL
    # Alternative: Create config manually
    - |
      cat > /kaniko/.docker/config.json << EOF
      {
        "auths": {
          "$ECR_REPOSITORY_URL": {
            "auth": "$(echo -n "AWS:$(aws ecr get-login-password --region $AWS_REGION)" | base64 -w 0)"
          }
        }
      }
      EOF
  script:
    - /kaniko/executor 
      --context $CI_PROJECT_DIR
      --dockerfile $CI_PROJECT_DIR/Dockerfile
      --destination $ECR_REPOSITORY_URL:$CI_COMMIT_SHA
      --destination $ECR_REPOSITORY_URL:latest
      --cache=true
      --cache-ttl=24h
  only:
    - main
    - develop

```
