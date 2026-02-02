# Project Invariants

> **TIER 0 CONTEXT**: This file contains project-wide truths that are **NEVER** summarized or aged.
> These invariants persist across ALL tasks and must be loaded at the start of every task.

---

## Architectural Decisions

### AD-001: [Decision Title]
**Decision**: [What was decided]
**Rationale**: [Why this decision was made]
**Alternatives Considered**:
- Alternative A: [Why rejected]
- Alternative B: [Why rejected]
**Decided**: [Date] by [Who]

<!--
Example:
### AD-001: Use Next.js App Router
**Decision**: All new pages must use the App Router pattern, not Pages Router
**Rationale**: App Router provides better streaming, server components, and is the future direction of Next.js
**Alternatives Considered**:
- Pages Router: Rejected because it's being deprecated in favor of App Router
- Remix: Rejected because team has more Next.js experience
**Decided**: 2026-01-15 by Tech Lead
-->

---

## Constraints

### CON-001: [Constraint Title]
**Constraint**: [What is constrained]
**Source**: [Where this constraint comes from - PRD, compliance, technical limitation]
**Impact**: [How this affects development]

<!--
Example:
### CON-001: WCAG 2.1 AA Compliance Required
**Constraint**: All UI must meet WCAG 2.1 AA accessibility standards
**Source**: Legal requirement for government contract eligibility
**Impact**: All frontend tasks must pass axe-core audits, Lighthouse accessibility >= 90
-->

---

## Patterns

### PAT-001: [Pattern Name]
**Description**: [What the pattern is and when to use it]
**Example**:
```typescript
// Code example showing the pattern
```
**Applies To**: [List of file types, components, or scenarios where this applies]

<!--
Example:
### PAT-001: Zod Schema Validation
**Description**: All API inputs must be validated using Zod schemas with safeParse
**Example**:
```typescript
import { z } from 'zod';

const CreateUserSchema = z.object({
  email: z.string().email(),
  name: z.string().min(1).max(100),
});

export async function createUser(req: Request) {
  const result = CreateUserSchema.safeParse(req.body);
  if (!result.success) {
    return { error: result.error.flatten() };
  }
  // Proceed with validated data
}
```
**Applies To**: All API route handlers, form submissions, external data ingestion
-->

---

## Conventions

### CNV-001: [Convention Title]
**Convention**: [What the convention is]
**Example**: [Brief example]

<!--
Example:
### CNV-001: File Naming
**Convention**: Use kebab-case for files, PascalCase for React components
**Example**: `user-profile.tsx` exports `UserProfile` component

### CNV-002: Error Handling
**Convention**: Use Result<T, E> pattern for operations that can fail
**Example**: `Result<User, ValidationError | NotFoundError>`
-->

---

## Critical Dependencies

| Name | Version | Purpose | API Patterns |
|------|---------|---------|--------------|
| [Package] | [Version] | [Why it's used] | [Key APIs to use] |

<!--
Example:
| next | 14.x | React framework | App Router, Server Components, Server Actions |
| prisma | 5.x | ORM | $transaction, findUnique, create, update |
| zod | 3.x | Validation | z.object, safeParse, z.infer |
| @tanstack/react-query | 5.x | Data fetching | useQuery, useMutation, queryClient |
-->

---

## Environment Configuration

### Required Environment Variables
| Variable | Purpose | Example |
|----------|---------|---------|
| [VAR_NAME] | [What it's for] | [Example value format] |

<!--
Example:
| DATABASE_URL | PostgreSQL connection string | postgresql://user:pass@host:5432/db |
| NEXTAUTH_SECRET | Session encryption | Random 32+ character string |
| NEXT_PUBLIC_API_URL | Client-side API base URL | https://api.example.com |
-->

---

## Quality Thresholds

| Metric | Threshold | Blocking |
|--------|-----------|----------|
| Lighthouse Performance | >= 90 | Yes |
| Lighthouse Accessibility | >= 90 | Yes |
| LCP | <= 2.5s | Yes |
| CLS | <= 0.1 | Yes |
| Test Coverage | >= 80% | No |

---

## Cross-Cutting Concerns

### Authentication
[How auth works in this project - session-based, JWT, OAuth providers, etc.]

### Error Handling
[Standard error handling approach across the project]

### Logging
[Logging strategy and what must be logged]

### Caching
[Caching strategies in use]

---

## Update Protocol

When completing a task, check if any of the following should be added to this file:
1. **Architectural decisions** made during the task
2. **New patterns** discovered or established
3. **Conventions** that should be followed project-wide
4. **New critical dependencies** that have specific usage patterns
5. **New constraints** discovered during implementation

**To add an invariant:**
1. Identify the category (AD, CON, PAT, CNV)
2. Use the next available number (AD-002, CON-002, etc.)
3. Follow the template format exactly
4. Include rationale and examples where applicable

---

*Last Updated: [Auto-populated by context-inject.sh]*
*Tasks Since Last Update: [Auto-populated]*
