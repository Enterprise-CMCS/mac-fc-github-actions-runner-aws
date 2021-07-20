[
  {
    "name": "${app_name}-${environment}-${task_name}",
    "image": "${repo_url}:${repo_tag}",
    "cpu": 128,
    "memory": 1024,
    "essential": true,
    "portMappings": [],
    "environment": [
      {"name": "REPO_OWNER", "value": "${repo_owner}"},
      {"name": "REPO_NAME", "value": "${repo_name}"}
    ],
    "secrets": [
      {"name": "PERSONAL_ACCESS_TOKEN", "valueFrom": "${personal_access_token_arn}"}
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "secretOptions": null,
      "options": {
        "awslogs-group": "${awslogs_group}",
        "awslogs-region": "${awslogs_region}",
        "awslogs-stream-prefix": "${app_name}"
      }
    },
    "mountPoints": [],
    "volumesFrom": [],
    "entryPoint": [
            "./entrypoint.sh"
    ]
  }
]