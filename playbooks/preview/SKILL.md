---
name: preview
description: Generate build preview without execution
disable-model-invocation: false
context: fork
---

# Preview Mode (Dry-Run)

Generate a detailed preview of what a build would do WITHOUT making any changes.

## Overview

Preview mode allows users to see exactly what would happen before committing to a build:
- Files that would be created or modified
- Steps that would be executed
- Quality checks that would run
- Estimated confidence score

## When to Use

- First time running a type of build
- Large or risky changes
- Reviewing AI-generated plans before execution
- Training new team members

## Invocation

```
/build:preview <goal>
```

Example:
```
/build:preview Add user authentication with OAuth support
```

## Output Format

```
╔══════════════════════════════════════════════════════════════╗
║  PREVIEW MODE - No changes will be made                      ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  Goal: Add user authentication with OAuth support            ║
║                                                              ║
╠══════════════════════════════════════════════════════════════╣
║  REQUIREMENTS (would gather)                                 ║
║  ├─ OAuth providers to support                               ║
║  ├─ Session management approach                              ║
║  ├─ User data to store                                       ║
║  └─ Redirect URLs after login                                ║
║                                                              ║
╠══════════════════════════════════════════════════════════════╣
║  FILES (would create)                                        ║
║  ├─ src/auth/oauth.config.ts                                 ║
║  ├─ src/auth/providers/google.ts                             ║
║  ├─ src/auth/providers/github.ts                             ║
║  ├─ src/auth/session.ts                                      ║
║  ├─ src/auth/middleware.ts                                   ║
║  └─ tests/auth.test.ts                                       ║
║                                                              ║
╠══════════════════════════════════════════════════════════════╣
║  FILES (would modify)                                        ║
║  ├─ src/routes/index.ts (+15 lines)                          ║
║  └─ package.json (+3 dependencies)                           ║
║                                                              ║
╠══════════════════════════════════════════════════════════════╣
║  STEPS (would execute)                                       ║
║  ├─ 1. Create OAuth configuration                            ║
║  ├─ 2. Implement Google provider                             ║
║  ├─ 3. Implement GitHub provider                             ║
║  ├─ 4. Create session management                             ║
║  ├─ 5. Add auth middleware                                   ║
║  ├─ 6. Update routes                                         ║
║  └─ 7. Write tests                                           ║
║                                                              ║
║  Estimated: 7 steps, ~3-5 minutes                            ║
║                                                              ║
╠══════════════════════════════════════════════════════════════╣
║  QUALITY CHECKS (would run)                                  ║
║  ├─ npm test -- --testPathPattern=auth                       ║
║  ├─ npx tsc --noEmit                                         ║
║  └─ npm run lint                                             ║
║                                                              ║
╠══════════════════════════════════════════════════════════════╣
║  CONFIDENCE ESTIMATE: 85% (MEDIUM)                           ║
║  ├─ Requirements: Clear OAuth pattern                        ║
║  ├─ Steps: Well-defined structure                            ║
║  ├─ Context: Similar patterns in codebase                    ║
║  └─ Risk: External API dependencies                          ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝

Run '/build Add user authentication with OAuth support' to execute.
```

## Methodology

### 1. Analyze Goal
Parse the goal and identify:
- Task type (API, component, feature, etc.)
- Domain (frontend, backend, full-stack)
- Complexity estimate

### 2. Hypothetical Requirements
Based on goal analysis, list questions that WOULD be asked:
```json
{
  "would_ask": [
    "Which OAuth providers should be supported?",
    "How should sessions be managed?",
    "What user data should be stored?"
  ]
}
```

### 3. Generate Plan Skeleton
Create steps WITHOUT micro-actions:
```json
{
  "preview_steps": [
    {"id": "step_1", "name": "Create OAuth configuration", "files": ["src/auth/oauth.config.ts"]},
    {"id": "step_2", "name": "Implement providers", "files": ["src/auth/providers/*.ts"]}
  ]
}
```

### 4. Estimate Impact
Analyze codebase to identify:
- Files that would be created
- Files that would be modified
- Approximate lines changed

### 5. Confidence Estimate
Calculate preliminary confidence based on:
- Pattern recognition in codebase
- Clarity of goal
- Known complexity factors

## Critical Rules

**DO NOT:**
- Create any files
- Modify any files
- Execute any commands that change state
- Run npm install or similar
- Write to disk

**DO:**
- Read files for analysis
- Use Glob/Grep for pattern discovery
- Calculate estimates
- Display preview output

## Integration

Preview mode is triggered by:
1. `/build:preview` command
2. Detection of "preview" in goal string
3. Explicit `--preview` flag

The planner checks for preview mode:
```bash
if [[ "$ARGUMENTS" == *"preview"* ]] || [[ "$MODE" == "preview" ]]; then
    # Load preview playbook
    # Skip actual execution
    # Display preview output only
fi
```

## Benefits

1. **Safety** - See changes before making them
2. **Learning** - Understand STUDIO's approach
3. **Approval** - Get stakeholder sign-off
4. **Estimation** - Time and complexity planning
5. **Documentation** - Record proposed changes
