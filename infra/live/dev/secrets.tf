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
    DATABASE_URL               = var.database_url
    REDIS_URL                  = var.redis_url
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

  lifecycle {
    ignore_changes = [secret_string]
  }
}
