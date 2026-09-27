# Infrastructure Template

## Deployment Architecture
<!-- Diagram: CDN → Load Balancer → App Servers → DB → Cache → Queue -->

## Environment Strategy
| Environment | Purpose | URL | Deploy Trigger |
|-------------|---------|-----|---------------|
| dev | | | |
| staging | | | |
| production | | | |

## CI/CD Pipeline
<!-- Stages: lint → test → build → docker → deploy-to-{env} -->
<!-- Include: branch strategy, approval gates, rollback plan -->

## Docker Strategy
- Base image:
- Multi-stage build:
- Health check endpoint:
- Resource limits:

## Database
- Migration strategy:
- Backup/restore:
- Connection pooling:
- Read replicas:

## Monitoring & Observability
- Logging (structured, centralised):
- Metrics (business + technical):
- Tracing:
- Alerting (pager / slack):
- Dashboard (key graphs):

## Secrets Management
<!-- Where are secrets stored? How are they rotated? -->

## Cost Estimation
<!-- Estimated monthly cost per environment -->

---
**Status**: Draft
**Last updated**:
**Approved by**:
