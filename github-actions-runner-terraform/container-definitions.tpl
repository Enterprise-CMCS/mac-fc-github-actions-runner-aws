[
  {
    "name": "gh-runner-${gh_name_hash}",
    "image": "${ecr_repo_url}:${ecr_repo_tag}",
    "cpu": ${container_cpu},
    "memory": ${container_memory},
    "essential": true,
    "portMappings": [],
    "environment": [
      {"name": "REPO_OWNER", "value": "${github_repo_owner}"},
      {"name": "REPO_NAME", "value": "${github_repo_name}"},
      {"name": "RUNNER_LABELS", "value": "${runner_labels}"}
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
            "../entrypoint.sh"
    ]
  }
]