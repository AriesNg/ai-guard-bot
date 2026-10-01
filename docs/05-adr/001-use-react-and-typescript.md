# ADR-001: Use React + TypeScript with Next.js App Router

**Status**: **Superseded by [ADR-010](010-supersede-adr-001-no-web-server-ui.md)** (2026-10-02)

> This ADR was inherited from the project scaffold and predates
> `.ai/context/project-brief.md`. Its stated context — SSR, static generation, SEO, Vercel
> deployment, a BFF — does not describe this product, and as written it conflicts with
> [ADR-003](003-local-daemon-over-unix-socket.md)'s rule that no TCP listener exists in the
> product in any configuration. **It binds nothing.** It is retained as a record of what the
> project once assumed. See [ADR-010](010-supersede-adr-001-no-web-server-ui.md) for the
> replacement and for what survives of it.

## Context
We need a frontend framework that supports SSR, static generation, and API routes with minimal configuration. The team has React experience.

## Decision
Use Next.js 14+ with App Router, TypeScript, and React Server Components by default.

## Rationale
- Next.js provides SSR, SSG, ISR, and API routes out of the box — no separate backend server needed for BFF
- App Router enables React Server Components, reducing client-side JS
- TypeScript provides type safety across the stack
- Vercel ecosystem simplifies deployment if needed
- Large ecosystem, excellent docs, active community

## Consequences
- Must understand RSC vs client component boundaries
- App Router is relatively new — some patterns still evolving
- Locked into Next.js conventions for routing and data fetching

## Rejected Alternatives
- **Create React App**: Abandoned by Meta, no SSR, poor DX for production apps
- **Remix**: Good but smaller ecosystem, team less familiar
- **Plain Vite + React**: No SSR/SEO built in; would need additional setup for production

---
**Date**: 2026-05-10
