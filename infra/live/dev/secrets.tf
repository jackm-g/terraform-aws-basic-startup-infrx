# AWS Secrets Manager for Django environment variables
resource "aws_secretsmanager_secret" "django_env" {
  name                    = "${var.project}-${var.env}-django-env"
  description             = "Django application environment variables"
  recovery_window_in_days = 7

  tags = {
    Name    = "${var.project}-${var.env}-django-env"
    Project = var.project
    Env     = var.env
  }
}

# Secret version with Django environment variables
resource "aws_secretsmanager_secret_version" "django_env" {
  secret_id = aws_secretsmanager_secret.django_env.id
  secret_string = jsonencode({
    DJANGO_SECRET_KEY          = var.django_secret_key
    DATABASE_URL               = "postgresql://${aws_db_instance.main.username}:${urlencode(random_password.db_password.result)}@${aws_db_instance.main.endpoint}/${aws_db_instance.main.db_name}"
    REDIS_URL                  = var.redis_auth_token_enabled ? "redis://:${urlencode(random_password.redis_auth_token[0].result)}@${coalesce(aws_elasticache_replication_group.main.configuration_endpoint_address, aws_elasticache_replication_group.main.primary_endpoint_address)}:${aws_elasticache_replication_group.main.port}" : "redis://${coalesce(aws_elasticache_replication_group.main.configuration_endpoint_address, aws_elasticache_replication_group.main.primary_endpoint_address)}:${aws_elasticache_replication_group.main.port}"
    WHOOP_CLIENT_SECRET        = var.whoop_client_secret
    DJANGO_ENV                 = var.django_env
    ALLOWED_HOSTS              = var.allowed_hosts
    CORS_ALLOWED_ORIGINS       = var.cors_allowed_origins
    WHOOP_CLIENT_ID            = var.whoop_client_id
    WHOOP_REDIRECT_URI         = var.whoop_redirect_uri
    OPENAI_MODEL               = var.openai_model
    AI_ANALYSIS_INTERVAL_HOURS = var.ai_analysis_interval_hours
    AI_ANALYSIS_PERIOD_DAYS    = var.ai_analysis_period_days
    SECURE_SSL_REDIRECT        = var.secure_ssl_redirect
  })

  # TODO: Uncomment this when we have a way to update the secrets manager secret
  # lifecycle {
  #   ignore_changes = [secret_string]
  # }
}
