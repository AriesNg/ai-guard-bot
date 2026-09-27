# Review Criteria

Use this checklist before marking any phase as complete.

## Discovery Review
- [ ] Problem stated clearly, not solution-prescribed
- [ ] Personas represent real user segments
- [ ] User stories are INVEST (Independent, Negotiable, Valuable, Estimable, Small, Testable)
- [ ] P0 stories are truly must-have (not just nice-to-have)
- [ ] NFRs are quantified (e.g., "P95 < 200ms", not "fast")
- [ ] Risks have mitigations, not just acknowledgment
- [ ] Out-of-scope items explicitly listed (reduces scope creep)

## UX Design Review
- [ ] Happy path and error/empty/edge states defined
- [ ] Mobile + tablet + desktop considered
- [ ] Keyboard navigation works
- [ ] Design system choices justified (why this library? why this grid?)
- [ ] Loading states defined (skeleton/spinner/progressive)

## System Design Review
- [ ] Architecture diagram matches requirements
- [ ] Data model normalised to 3NF (or justified denormalisation)
- [ ] API endpoints RESTful (or justification for RPC/GraphQL)
- [ ] authn/authz applied to every endpoint
- [ ] Rate limiting strategy defined
- [ ] N+1 query prevention in data access layer
- [ ] CORS policy defined

## ADR Review
- [ ] Every non-trivial decision has an ADR
- [ ] Context includes why alternatives were rejected
- [ ] Consequences are specific and actionable

## Infrastructure Review
- [ ] Secrets never in code, env vars, or config files
- [ ] Health check endpoint defined
- [ ] Backup/restore process documented and tested
- [ ] Monitoring covers: errors, latency, traffic, saturation (USE method)
- [ ] Rollback plan exists
