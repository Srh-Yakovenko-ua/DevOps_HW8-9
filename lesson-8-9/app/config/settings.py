"""Django settings for the config project.

This is the theme-4 application made cloud ready. Every setting is driven by
environment variables so the exact same image runs locally (docker-compose)
and in Kubernetes, configured entirely through the ConfigMap.

Database selection:
  * USE_SQLITE=1 (default) or no POSTGRES_HOST -> SQLite. The app is then fully
    self contained and runs in the cluster with only the ConfigMap, no database
    pod required. This is what makes the Helm chart work out of the box.
  * USE_SQLITE=0 with a reachable POSTGRES_HOST -> PostgreSQL, exactly like
    theme 4 (point it at an in-cluster Postgres, RDS, or docker-compose).
"""

import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = os.environ.get("SECRET_KEY", "dev-insecure-secret-key-change-me")

DEBUG = os.environ.get("DEBUG", "1") == "1"

# "*" (the default) accepts any Host header, which is convenient behind an AWS
# load balancer whose DNS name is not known ahead of time. Narrow it in prod.
ALLOWED_HOSTS = os.environ.get("ALLOWED_HOSTS", "*").split(",")

# Trust the load balancer / ingress hosts for CSRF on secure origins.
CSRF_TRUSTED_ORIGINS = [
    origin.strip()
    for origin in os.environ.get(
        "CSRF_TRUSTED_ORIGINS", "http://localhost,http://127.0.0.1"
    ).split(",")
    if origin.strip()
]

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "whitenoise.middleware.WhiteNoiseMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "config.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "config.wsgi.application"

# Use SQLite when explicitly requested or when no Postgres host is configured.
USE_SQLITE = os.environ.get("USE_SQLITE", "1") == "1"
POSTGRES_HOST = os.environ.get("POSTGRES_HOST", "")

if USE_SQLITE or not POSTGRES_HOST:
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.sqlite3",
            "NAME": BASE_DIR / "db.sqlite3",
        }
    }
else:
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.postgresql",
            "NAME": os.environ.get("POSTGRES_DB", "appdb"),
            "USER": os.environ.get("POSTGRES_USER", "appuser"),
            "PASSWORD": os.environ.get("POSTGRES_PASSWORD", "apppass"),
            "HOST": POSTGRES_HOST,
            "PORT": os.environ.get("POSTGRES_PORT", "5432"),
        }
    }

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

LANGUAGE_CODE = "en-us"
TIME_ZONE = "UTC"
USE_I18N = True
USE_TZ = True

STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"

STORAGES = {
    "default": {
        "BACKEND": "django.core.files.storage.FileSystemStorage",
    },
    "staticfiles": {
        "BACKEND": "whitenoise.storage.CompressedStaticFilesStorage",
    },
}

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
