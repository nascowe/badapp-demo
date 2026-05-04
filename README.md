# CampusHub Vulnerable Demo App

Intentionally vulnerable sample application for demonstrating Datadog security capabilities to a university security team.

> Do not deploy this to the public internet. Use only in a private demo/staging environment.

## Demo Coverage Matrix

| Capability | Where to demo it |
|---|---|
| SAST | `backend/src/server.js` insecure SQL, command injection, path traversal, weak JWT secret |
| SCA | `backend/package.json` intentionally old dependencies |
| IAST | Exercise `/api/students/search`, `/api/files`, `/api/admin/ping` with real traffic |
| DAST | Scan running app at `http://localhost:3000` |
| RASP | Enable Datadog App and API Protection on backend, then replay attack traffic |
| API Security | API inventory and sensitive endpoints under `/api/*` |
| IaC Scanning | `infra/main.tf` public bucket, open security group, hardcoded secret-like values |

## Quick Start

```bash
cd backend
npm install
npm start
```

The app listens on `http://localhost:3000`.

Seed data is in SQLite memory DB, so it resets on restart.

## Suggested Demo Attack Traffic

```bash
# SQL injection
curl 'http://localhost:3000/api/students/search?q=%27%20OR%201%3D1--'

# Reflected XSS
curl 'http://localhost:3000/api/feedback?message=%3Cscript%3Ealert(1)%3C/script%3E'

# Path traversal
curl 'http://localhost:3000/api/files?name=../../package.json'

# Command injection
curl 'http://localhost:3000/api/admin/ping?host=127.0.0.1%3Bwhoami'

# Unauthenticated sensitive API
curl 'http://localhost:3000/api/research-grants'
```

## Datadog Runtime Example

Set your environment variables and run with tracing/security enabled:

```bash
export DD_SERVICE=campushub-api
export DD_ENV=demo
export DD_VERSION=1.0.0
export DD_APPSEC_ENABLED=true
export DD_IAST_ENABLED=true
node --require dd-trace/init src/server.js
```
