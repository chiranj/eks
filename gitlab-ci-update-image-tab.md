```yaml

update:helm-chart:
  stage: update-helm
  image: alpine:latest
  variables:
    HELM_CHART_PROJECT_ID: "${HELM_CHART_PROJECT_ID}"  # Project ID of your Helm chart repo
    GITLAB_API_TOKEN: "${GITLAB_API_TOKEN}"            # GitLab API token with write access
    FRONTEND_VERSION: "${VERSION}"                      # Frontend image tag
    BACKEND_VERSION: "${VERSION}"                       # Backend image tag (can be different)
    FILE_PATH: "values.yaml"                           # Path to values.yaml in the repo
    TARGET_BRANCH: "main"                              # Target branch to update
  script:
    - echo "Updating Helm chart values.yaml with new image tags..."
    - echo "Frontend version: ${FRONTEND_VERSION}"
    - echo "Backend version: ${BACKEND_VERSION}"
    
    # Install required tools
    - apk add --no-cache curl jq yq
    
    # Get the current file content from GitLab API
    - echo "Fetching current values.yaml content..."
    - |
      CURRENT_CONTENT=$(curl --silent --fail \
        --header "PRIVATE-TOKEN: ${GITLAB_API_TOKEN}" \
        "${CI_API_V4_URL}/projects/${HELM_CHART_PROJECT_ID}/repository/files/${FILE_PATH}/raw?ref=${TARGET_BRANCH}")
    
    # Save current content to a file for manipulation
    - echo "$CURRENT_CONTENT" > current_values.yaml
    
    # Update the frontend image tag
    - echo "Updating frontend image tag to ${FRONTEND_VERSION}..."
    - yq e '.containers.frontend.container.image.tag = "'${FRONTEND_VERSION}'"' -i current_values.yaml
    
    # Update the backend image tag
    - echo "Updating backend image tag to ${BACKEND_VERSION}..."
    - yq e '.containers.backend.container.image.tag = "'${BACKEND_VERSION}'"' -i current_values.yaml
    
    # Show the changes (for debugging)
    - echo "=== Changes made ==="
    - diff -u <(echo "$CURRENT_CONTENT") current_values.yaml || true
    
    # Read the updated content
    - UPDATED_CONTENT=$(cat current_values.yaml)
    
    # Base64 encode the content for GitLab API
    - ENCODED_CONTENT=$(echo -n "$UPDATED_CONTENT" | base64 -w 0)
    
    # Commit the changes using GitLab API
    - echo "Committing changes to GitLab repository..."
    - |
      RESPONSE=$(curl --silent --fail \
        --request PUT \
        --header "PRIVATE-TOKEN: ${GITLAB_API_TOKEN}" \
        --header "Content-Type: application/json" \
        --data "{
          \"branch\": \"${TARGET_BRANCH}\",
          \"commit_message\": \"Update image tags - Frontend: ${FRONTEND_VERSION}, Backend: ${BACKEND_VERSION} [skip ci]\",
          \"content\": \"${ENCODED_CONTENT}\",
          \"encoding\": \"base64\"
        }" \
        "${CI_API_V4_URL}/projects/${HELM_CHART_PROJECT_ID}/repository/files/${FILE_PATH}")
    
    # Verify the commit was successful
    - echo "Commit response: $RESPONSE"
    - echo "Successfully updated Helm chart values.yaml"
    - echo "Frontend image tag updated to: ${FRONTEND_VERSION}"
    - echo "Backend image tag updated to: ${BACKEND_VERSION}"
    
  only:
    - main  # Only run on main branch commits

```
