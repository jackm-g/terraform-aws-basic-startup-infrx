#!/bin/bash
set -euxo pipefail

# Update package list and install required packages
apt-get update -y
apt-get install -y docker.io jq curl unzip

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Start and enable Docker service
systemctl enable docker && systemctl start docker

# Add ubuntu user to docker group for easier management
usermod -aG docker ubuntu

# Template variables (replaced by Terraform)
AWS_REGION="${region}"
IMAGE_URI="${image_uri}:${image_tag}"
SECRET_ARN="${secret_arn}"
SECRETS_FORMAT="${secrets_format}"

# Login to ECR
aws ecr get-login-password --region "$AWS_REGION" | \
  docker login --username AWS --password-stdin "$(echo "$IMAGE_URI" | cut -d/ -f1)"

# Fetch environment variables from Secrets Manager
SECRET_JSON=$(aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ARN" \
  --region "$AWS_REGION" \
  --query 'SecretString' \
  --output text)

# Create application directory
mkdir -p /opt/app

# Process secrets based on format
if [ "$SECRETS_FORMAT" = "dotenv" ]; then
  echo "$SECRET_JSON" > /opt/app/.env
else
  echo "$SECRET_JSON" | jq -r 'to_entries|.[]|"\(.key)=\(.value)"' > /opt/app/.env
fi

chmod 600 /opt/app/.env

# Create systemd service for Django container
cat >/etc/systemd/system/django.service <<UNIT
[Unit]
Description=Django container
After=docker.service
Requires=docker.service

[Service]
Restart=always
RestartSec=10
EnvironmentFile=-/opt/app/.env
ExecStartPre=/bin/bash -c 'aws ecr get-login-password --region ${region} | docker login --username AWS --password-stdin \$(echo "${image_uri}" | cut -d/ -f1)'
ExecStartPre=/usr/bin/docker pull ${image_uri}:${image_tag}
ExecStartPre=-/usr/bin/docker stop django
ExecStartPre=-/usr/bin/docker rm django
ExecStart=/usr/bin/docker run --name django -p ${container_port}:8000 --env-file /opt/app/.env ${image_uri}:${image_tag}
ExecStop=/usr/bin/docker stop -t 15 django
ExecStopPost=-/usr/bin/docker rm django

[Install]
WantedBy=multi-user.target
UNIT

# Create systemd service for Celery worker
cat >/etc/systemd/system/celery-worker.service <<UNIT
[Unit]
Description=Celery worker container
After=docker.service django.service
Requires=docker.service
Wants=django.service

[Service]
Restart=always
RestartSec=10
EnvironmentFile=-/opt/app/.env
ExecStartPre=/bin/bash -c 'aws ecr get-login-password --region ${region} | docker login --username AWS --password-stdin \$(echo "${image_uri}" | cut -d/ -f1)'
ExecStartPre=/usr/bin/docker pull ${image_uri}:${image_tag}
ExecStartPre=-/usr/bin/docker stop celery-worker
ExecStartPre=-/usr/bin/docker rm celery-worker
ExecStart=/usr/bin/docker run --name celery-worker --env-file /opt/app/.env ${image_uri}:${image_tag} celery -A config.celery_app worker --loglevel=info
ExecStop=/usr/bin/docker stop -t 15 celery-worker
ExecStopPost=-/usr/bin/docker rm celery-worker

[Install]
WantedBy=multi-user.target
UNIT

# Create systemd service for Celery beat
cat >/etc/systemd/system/celery-beat.service <<UNIT
[Unit]
Description=Celery beat container
After=docker.service django.service
Requires=docker.service
Wants=django.service

[Service]
Restart=always
RestartSec=10
EnvironmentFile=-/opt/app/.env
ExecStartPre=/bin/bash -c 'aws ecr get-login-password --region ${region} | docker login --username AWS --password-stdin \$(echo "${image_uri}" | cut -d/ -f1)'
ExecStartPre=/usr/bin/docker pull ${image_uri}:${image_tag}
ExecStartPre=-/usr/bin/docker stop celery-beat
ExecStartPre=-/usr/bin/docker rm celery-beat
ExecStart=/usr/bin/docker run --name celery-beat --env-file /opt/app/.env ${image_uri}:${image_tag} celery -A config.celery_app beat --loglevel=info
ExecStop=/usr/bin/docker stop -t 15 celery-beat
ExecStopPost=-/usr/bin/docker rm celery-beat

[Install]
WantedBy=multi-user.target
UNIT

# Enable and start all services
systemctl daemon-reload
systemctl enable django celery-worker celery-beat
systemctl start django celery-worker celery-beat

# Wait for Django to be ready and run migrations
echo "Waiting for Django to start..."
sleep 30

echo "Running Django migrations..."
# Wait for the django container to be fully ready
while ! docker exec django python manage.py check --database default > /dev/null 2>&1; do
  echo "Waiting for Django database connection..."
  sleep 10
done

# Run migrations
docker exec django python manage.py migrate

echo "Django migrations completed successfully!"