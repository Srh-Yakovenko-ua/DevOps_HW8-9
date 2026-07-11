"""URL configuration for the Dealsbe project."""

import socket

from django.contrib import admin
from django.db import connection
from django.http import HttpResponse, JsonResponse
from django.urls import path

PAGE = """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Dealsbe - AI Tools Directory</title>
  <style>
    :root { color-scheme: light dark; }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      background: #0f1220;
      color: #e8eaf2;
      line-height: 1.5;
    }
    .wrap { max-width: 880px; margin: 0 auto; padding: 56px 20px 80px; }
    .brand { font-size: 30px; font-weight: 700; letter-spacing: -0.5px; }
    .brand span { color: #6c8cff; }
    .tagline { margin-top: 10px; font-size: 18px; color: #aab1c6; }
    .lead { margin-top: 6px; color: #8b93ab; }
    .cats { display: flex; flex-wrap: wrap; gap: 10px; margin: 28px 0 8px; }
    .chip {
      background: #1a1f36; border: 1px solid #2a3050; color: #cdd3e6;
      padding: 8px 14px; border-radius: 999px; font-size: 14px;
    }
    .status {
      margin-top: 36px; background: #141830; border: 1px solid #262c4a;
      border-radius: 12px; padding: 18px 20px;
    }
    .status h2 { margin: 0 0 12px; font-size: 14px; text-transform: uppercase; letter-spacing: 1px; color: #8b93ab; }
    .row { display: flex; justify-content: space-between; padding: 6px 0; font-size: 15px; border-top: 1px solid #20263f; }
    .row:first-of-type { border-top: 0; }
    .k { color: #8b93ab; }
    .v { color: #e8eaf2; font-variant-numeric: tabular-nums; }
    .ok { color: #58d68d; }
    a { color: #6c8cff; text-decoration: none; }
    footer { margin-top: 28px; color: #6b7290; font-size: 13px; }
  </style>
</head>
<body>
  <div class="wrap">
    <div class="brand">deals<span>be</span></div>
    <div class="tagline">AI Tools Directory</div>
    <div class="lead">Quickly find the right AI product for your workflow.</div>

    <div class="cats">
      <span class="chip">Writing &amp; Content</span>
      <span class="chip">Image Generation</span>
      <span class="chip">Video &amp; Audio</span>
      <span class="chip">Coding Assistants</span>
      <span class="chip">Research &amp; Search</span>
      <span class="chip">Productivity</span>
      <span class="chip">Design &amp; UI</span>
      <span class="chip">Marketing &amp; SEO</span>
    </div>

    <div class="status">
      <h2>Deployment status</h2>
      <div class="row"><span class="k">Platform</span><span class="v">Amazon EKS (Kubernetes), deployed with Helm</span></div>
      <div class="row"><span class="k">Served by pod</span><span class="v">__POD__</span></div>
      <div class="row"><span class="k">Database (__VENDOR__)</span><span class="v">__DB__</span></div>
    </div>

    <footer>Admin panel: <a href="/admin/">/admin/</a> &middot; Health check: <a href="/healthz/">/healthz/</a></footer>
  </div>
</body>
</html>"""


def index(request):
    """Dealsbe landing page. Also reports the runtime deployment status."""
    try:
        connection.ensure_connection()
        db_status = "connected" if connection.is_usable() else "unusable"
    except Exception as exc:  # noqa: BLE001 - surface any DB error on the page
        db_status = f"error: {exc}"

    html = (
        PAGE.replace("__POD__", socket.gethostname())
        .replace("__VENDOR__", connection.vendor)
        .replace("__DB__", db_status)
    )
    return HttpResponse(html)


def healthz(request):
    """Liveness/readiness probe endpoint.

    Deliberately does not touch the database so a pod is reported healthy as
    soon as gunicorn is up, independent of any external dependency.
    """
    return JsonResponse({"status": "ok"})


urlpatterns = [
    path("", index, name="index"),
    path("healthz/", healthz, name="healthz"),
    path("admin/", admin.site.urls),
]
