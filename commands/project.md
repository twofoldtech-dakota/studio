---
name: project
description: Orchestrate multiple related tasks as a project
triggers:
  - "/project"
  - "/project:init"
  - "/project:task"
  - "/project:status"
  - "/project:graph"
  - "/project:run"
  - "/project:list"
---

# Project Orchestration

Manage multiple related tasks with dependencies.

## Overview

Projects allow you to:
- Group related tasks together
- Define dependencies between tasks
- Execute tasks in correct order
- Share context across tasks

## Commands

### `/project:init <name>`
Create a new project.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/project.sh" init "E-commerce Platform"
```

### `/project:task <goal> [depends_on]`
Add a task to the current project.

```bash
# Task with no dependencies
"${CLAUDE_PLUGIN_ROOT}/scripts/project.sh" task "User authentication"

# Task with dependencies (comma-separated)
"${CLAUDE_PLUGIN_ROOT}/scripts/project.sh" task "Shopping cart" "task_001,task_002"
```

### `/project:status`
Show current project status with all tasks.

### `/project:graph`
Display dependency graph in ASCII format.

### `/project:run`
Calculate and display execution order.

### `/project:list`
List all projects.

## Project Structure

```
studio/projects/
└── proj_20260201_ecommerce/
    ├── project.json      # Project manifest
    └── tasks/
        ├── task_20260201120000/
        │   ├── plan.json
        │   └── manifest.json
        ├── task_20260201120100/
        └── task_20260201120200/
```

## Project Manifest

```json
{
  "id": "proj_20260201_ecommerce",
  "name": "E-commerce Platform",
  "created_at": "2026-02-01T10:00:00Z",
  "updated_at": "2026-02-01T12:00:00Z",
  "status": "ACTIVE",
  "tasks": [
    {
      "id": "task_20260201120000",
      "goal": "User authentication",
      "status": "COMPLETE",
      "depends_on": [],
      "created_at": "2026-02-01T12:00:00Z"
    },
    {
      "id": "task_20260201120100",
      "goal": "Product catalog",
      "status": "COMPLETE",
      "depends_on": [],
      "created_at": "2026-02-01T12:01:00Z"
    },
    {
      "id": "task_20260201120200",
      "goal": "Shopping cart",
      "status": "PENDING",
      "depends_on": ["task_20260201120000", "task_20260201120100"],
      "created_at": "2026-02-01T12:02:00Z"
    }
  ],
  "shared_context": {
    "tech_stack": "Next.js, Prisma, PostgreSQL",
    "patterns": {},
    "decisions": []
  },
  "execution_order": []
}
```

## Dependency Resolution

Tasks are executed respecting their dependencies:

```
task_1 (auth)     ─┐
                   ├──> task_3 (cart) ──> task_4 (checkout)
task_2 (catalog) ─┘
```

- Tasks with no dependencies can run in parallel
- Dependent tasks wait for all dependencies to complete
- Circular dependencies are detected and rejected

## Example Session

```
User: /project:init E-commerce Platform

╔══════════════════════════════════════════════════════════════╗
║  PROJECT INITIALIZED                                         ║
╠══════════════════════════════════════════════════════════════╣
║  ID:       proj_20260201_ecommerce                           ║
║  Name:     E-commerce Platform                               ║
╚══════════════════════════════════════════════════════════════╝

User: /project:task User authentication
Task added: task_20260201120000

User: /project:task Product catalog
Task added: task_20260201120100

User: /project:task Shopping cart task_20260201120000,task_20260201120100
Task added: task_20260201120200 (depends on auth and catalog)

User: /project:graph

╔══════════════════════════════════════════════════════════════╗
║  DEPENDENCY GRAPH                                            ║
╠══════════════════════════════════════════════════════════════╣
║  [task_202602011200] <- ROOT                                 ║
║  [task_202602011201] <- ROOT                                 ║
║  [task_202602011202] <- task_20260201120000, task_20260201120100
╚══════════════════════════════════════════════════════════════╝

User: /project:run

Execution order:
1. task_20260201120000 (auth) - can run immediately
2. task_20260201120100 (catalog) - can run immediately (parallel with 1)
3. task_20260201120200 (cart) - waits for 1 and 2
```

## Shared Context

Projects can store shared context that's available to all tasks:

```json
{
  "shared_context": {
    "tech_stack": "Next.js, Prisma, PostgreSQL",
    "patterns": {
      "api": "REST with tRPC",
      "auth": "NextAuth.js"
    },
    "decisions": [
      "Use Stripe for payments",
      "Store images in S3"
    ]
  }
}
```

This context is automatically injected into each task's planning phase.

## Best Practices

1. **Break down large features** - Each task should be independently buildable
2. **Minimize dependencies** - Parallel execution is faster
3. **Define clear boundaries** - Tasks shouldn't overlap in scope
4. **Share context wisely** - Put reusable decisions in shared_context
5. **Run independent tasks in parallel** - Use Task tool for parallelization
