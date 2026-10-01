# Sprint 1 Plan

**Status**: ⚠️ **Scaffold boilerplate — binds nothing.** This file arrived with the project template
and describes a web application with authentication and a landing page. AI Guard Bot has no users to
authenticate, no landing page, and no dashboard; see `.ai/context/project-brief.md`. Phase 7's
prerequisite (Phases 1–6 approved) is not met, so this is **not** rewritten here — it is flagged so
nothing downstream mistakes it for a plan. When the real Sprint 1 is written, ADR-011's "the team
must now" list and [`../05-adr/README.md`](../05-adr/README.md) name its contents.

**Goal** *(boilerplate, not this product's)*: Project scaffold, auth, and landing page

## Stories
- [ ] Initialize Next.js project with TypeScript, ESLint, Prettier
- [ ] Set up project folder structure per solution design
- [ ] Implement authentication (sign-up, sign-in, sign-out)
- [ ] Create landing page (unauthenticated)
- [ ] Create dashboard shell (authenticated)
- [ ] Set up CI pipeline (lint → test → build)
- [ ] Write tests for auth flow

## Technical Details
<!-- AI fills in: packages to install, components to create, API routes needed -->

## Review Checklist
- [ ] Auth flow works end-to-end (signup → login → protected route)
- [ ] Tests pass
- [ ] CI green
- [ ] No secrets in code
- [ ] Responsive layout works
