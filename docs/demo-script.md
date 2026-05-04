# CampusHub Datadog Security Demo Script

1. Open a pull request containing `backend/src/server.js` and `infra/main.tf`.
2. Show static findings: SQL injection, command injection, weak secret, path traversal, insecure cookie, public S3, open SSH.
3. Show SCA findings from intentionally old packages in `backend/package.json`.
4. Start the app in staging with Datadog tracing and AppSec enabled.
5. Run DAST against `http://localhost:3000` or the staging URL.
6. Send attack traffic from `README.md`.
7. Show IAST findings tied to real requests/traces.
8. Enable/block with RASP and replay SQLi/command-injection traffic.
9. Show API inventory: `/api/students/search`, `/api/feedback`, `/api/admin/ping`, `/api/research-grants`, `/api/login`, `/api/preferences`.
10. Close with service-level risk prioritization: vulnerable code + exposed API + runtime attack evidence.
