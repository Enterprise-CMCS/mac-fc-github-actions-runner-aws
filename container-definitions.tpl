[
  {
    "name": "${environment}-${github_repo_name}",
    "image": "${ecr_repo_url}:${ecr_repo_tag}",
    "cpu": 128,
    "memory": 1024,
    "essential": true,
    "portMappings": [],
    "environment": [
      {"name": "REPO_OWNER", "value": "${github_repo_owner}"},
      {"name": "REPO_NAME", "value": "${github_repo_name}"}
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
        "awslogs-stream-prefix": "${github_repo_name}"
      }
    },
    "mountPoints": [],
    "volumesFrom": [],
    "entryPoint": [
            "./entrypoint.sh"
    ]
  }
]