# Solution Design Template

## Application Structure
```
src/
├── app/          # Pages / routes / feature modules
├── shared/       # Reusable components, hooks, utils
├── config/       # Runtime configuration
└── types/        # Shared type definitions
```

## Component Tree
<!-- Hierarchy: Page → Section → Molecule → Atom -->
<!-- For each component: props interface, state, side effects -->

## State Management Strategy
- Global state (what, why, tool):
- Server state (caching, invalidation):
- Form state:
- URL state:
- Local UI state:

## Routing Design
<!-- Route table: path, component, auth required, loader, error boundary -->

## Error Handling Strategy
- API error normalisation:
- UI error boundaries:
- Fallback UI per error type:
- Logging and alerting:

## Testing Strategy
| Layer | Tool | What to test |
|-------|------|-------------|
| Unit | | Pure functions, hooks, utils |
| Integration | | API routes, DB queries, component interactions |
| E2E | | Critical user journeys |
| Visual | | UI regression, responsive layouts |

## Performance Strategy
- Code splitting:
- Data prefetching:
- Image optimisation:
- Bundle analysis:

---
**Status**: Draft
**Last updated**:
**Approved by**:
