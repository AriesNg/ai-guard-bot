# ADR-001: Use React + TypeScript with Next.js App Router

**Status**: Accepted

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
