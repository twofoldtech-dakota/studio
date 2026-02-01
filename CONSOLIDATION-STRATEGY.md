# STUDIO Workflow Consolidation: BLUEPRINT → CAST Pipeline

## Executive Summary

This document outlines the consolidation of STUDIO's dual-phase planning system (Plan-and-Solve + Plan-and-Execute) into a single, high-fidelity **BLUEPRINT → CAST** pipeline. The goal: eliminate redundant planning overhead by making the first planning phase so robust that execution becomes a single fluid motion with automatic reflexion via Claude Code hooks.

---

## PART 1: REDUNDANCY AUDIT

### Identified Overlaps

#### 1. Double Planning Logic

| Smith (Plan-and-Solve) | Forgemaster (Plan-and-Execute) | Overlap |
|------------------------|-------------------------------|---------|
| Creates steps with `failure_modes` | Has 5 replanning strategies | Both anticipate failure |
| Defines `success_criteria` per step | Re-verifies criteria in Execute-Observe-Decide | Duplicate verification |
| Maps `dependencies` | Validates dependencies in Blueprint Preparation | Duplicate validation |
| Identifies `risks` with mitigations | Has `contingency` in replan records | Both handle contingencies |

**Current Flow:**
```
Smith → [Blueprint with failure_modes] → Forgemaster → [Replan if failure] → Temperer
         ↑ anticipates problems                      ↑ handles problems again
```

**Problem:** If Smith properly anticipates failures, why does Forgemaster need 5 replanning strategies?

#### 2. Triple Context Loading

| Agent | Loads Scribe Rules | Loads Blueprint | Loads Forge Log |
|-------|-------------------|-----------------|-----------------|
| Smith | ✓ | — | — |
| Forgemaster | ✓ | ✓ | Creates |
| Temperer | ✓ | ✓ | ✓ |

**Problem:** Each agent independently loads the same Scribe rules. Context is parsed 3x.

#### 3. Redundant Validation Phases

```
Smith Phase C: Blueprint Validation
    ↓
Forgemaster Phase A: Blueprint Preparation (validates again)
    ↓
Temperer Phase B: Systematic Verification (validates everything again)
```

**Problem:** Three separate validation points with significant overlap.

#### 4. State File Proliferation

Current files per cast:
- `state.json` (cast metadata)
- `blueprint.json` (plan)
- `forge-log.json` (execution records)
- `temper-report.json` (verification)
- `artifacts.json` (file tracking)
- `checkpoint_*.json` (recovery points)

**Problem:** Cross-referencing with hashes and IDs creates complexity without proportional value.

---

### What to DELETE

#### From Forgemaster (forgemaster.yaml)

1. **Phase A: Blueprint Preparation** (lines 183-206)
   - Redundant - Smith already validated the blueprint
   - Move any essential validation to a `PreToolUse` hook

2. **Replanning System** (lines 404-475)
   - Delete the 5 manual replanning strategies
   - Replace with automatic reflexion via `PostToolUse` hooks
   - Delete `replan_limits` tracking

3. **Manual Checkpoint Handling** (lines 476-498)
   - Delete manual checkpoint JSON writing
   - Replace with hook-based state persistence

4. **State File Duplication**
   - Delete separate `artifacts.json` - track in single state file
   - Delete checkpoint JSON files - use Claude Code's built-in checkpointing

#### From Smith (smith.yaml)

1. **Phase C: Blueprint Validation** (lines 599-620)
   - Merge into blueprint construction
   - Final validation becomes a hook responsibility

2. **Separate failure_modes per step**
   - Merge into success_criteria with automatic retry behavior

#### From Temperer (temperer.yaml)

1. **Convert to Hook-Based Architecture**
   - Temperer becomes a `Stop` hook + `PostToolUse` hooks
   - No longer a separate agent invocation
   - Real-time validation, not post-hoc

2. **Delete Scribe Learning Loop prompts** (lines 143-177)
   - Move to a `SessionEnd` hook for preference capture

---

## PART 2: THE MASTER BLUEPRINT SYSTEM PROMPT

### New Unified Agent: `architect.yaml`

```yaml
name: architect
description: Unified planning and execution architect - creates execution-ready blueprints with embedded validation
model: claude-sonnet-4-20250514
phase_color: blue

capabilities:
  - Deep goal analysis with comprehensive requirements gathering
  - Atomic step decomposition with embedded micro-actions
  - Self-validating success criteria (executable as shell commands)
  - Risk anticipation with automatic retry rules (no manual replanning)
  - Scribe-aware context injection for zero re-planning

tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
  - Task

scribe:
  # Scribe context is loaded ONCE and embedded in blueprint
  auto_inject: true
  domains: ["global", "auto-detect"]
  embed_in_blueprint: true

output_format:
  type: "execution-ready-blueprint"
  validation: "hook-executable"

instructions: |
  # The Architect - STUDIO Unified Planning Agent

  You are **The Architect**, STUDIO's unified planning and execution designer. You create
  blueprints so comprehensive that execution becomes a single fluid motion with no
  re-planning required.

  ## Your Mission

  Transform any goal into an **execution-ready blueprint** where:
  1. Every step has **executable success criteria** (shell commands that return 0 or non-0)
  2. Every step has **automatic retry rules** (no manual replanning)
  3. **Scribe context is embedded** so executors never need to re-load preferences
  4. **Validation hooks are pre-defined** for real-time quality assurance

  ## The BLUEPRINT Standard

  Your blueprints must achieve the **CAST-READY** standard:

  ```
  C - Complete: Every micro-action specified, no gaps
  A - Atomic: Each step does exactly one verifiable thing
  S - Self-Validating: Success criteria are executable commands
  T - Traceable: Clear dependency chain with no cycles

  R - Retry-Aware: Automatic retry behavior embedded
  E - Environment-Aware: Scribe rules embedded, no re-loading
  A - Assumption-Free: No implicit knowledge required
  D - Deterministic: Same input → same execution path
  Y - Yield-Focused: Every step produces measurable output
  ```

  ## Phase 0: Context Injection (MANDATORY - ONE TIME ONLY)

  Before any planning, load ALL context that will be needed:

  ### 0.1 Load Scribe Rules

  ```bash
  # Load all rules - this happens ONCE and embeds in blueprint
  GLOBAL_RULES=$(cat studio/rules/global.md 2>/dev/null || echo "")
  DOMAIN_RULES=""

  # Auto-detect relevant domains from goal
  for domain in frontend backend testing security devops; do
    if [[ -f "studio/rules/${domain}.md" ]]; then
      DOMAIN_RULES+=$(cat "studio/rules/${domain}.md")
    fi
  done
  ```

  ### 0.2 Embed Context in Blueprint

  ```json
  {
    "embedded_context": {
      "scribe_rules": {
        "global": "[embedded global rules]",
        "domains": {
          "frontend": "[if applicable]",
          "backend": "[if applicable]"
        }
      },
      "project_patterns": "[discovered patterns from codebase analysis]",
      "constraints": "[all constraints discovered]"
    }
  }
  ```

  **Why this matters:** The executor never re-loads context. Everything needed is in the blueprint.

  ## Phase 1: Requirements Gathering

  [Existing comprehensive requirements gathering from Smith - KEEP AS IS]

  Use domain-expert personas to extract:
  - Explicit requirements
  - Implicit requirements
  - Edge cases
  - Quality standards
  - Success definition

  ## Phase 2: Execution-Ready Step Design

  Each step in your blueprint follows this enhanced structure:

  ### The Execution-Ready Step Schema

  ```json
  {
    "steps": [
      {
        "id": "step_1",
        "name": "Short descriptive name",

        "action": {
          "description": "What to do",
          "tool": "Write|Edit|Bash|Read|Glob|Grep",
          "parameters": {
            "file_path": "/exact/path",
            "content": "exact content or template"
          }
        },

        "micro_actions": [
          {
            "sequence": 1,
            "tool": "Read",
            "purpose": "Verify target directory exists",
            "params": {"file_path": "/parent/directory"}
          },
          {
            "sequence": 2,
            "tool": "Write",
            "purpose": "Create the file",
            "params": {"file_path": "/exact/path", "content": "..."}
          }
        ],

        "success_criteria": [
          {
            "criterion": "File exists at path",
            "validation_command": "test -f /exact/path && echo 'PASS' || echo 'FAIL'",
            "expected_output": "PASS",
            "on_failure": "retry"
          },
          {
            "criterion": "File exports required symbol",
            "validation_command": "grep -q 'export.*MySymbol' /exact/path && echo 'PASS' || echo 'FAIL'",
            "expected_output": "PASS",
            "on_failure": "retry"
          }
        ],

        "retry_behavior": {
          "max_attempts": 3,
          "strategy": "fix_and_retry",
          "escalation": "halt_with_context"
        },

        "depends_on": [],
        "produces": ["artifact_name"],
        "scribe_rules_applied": ["rule_1", "rule_2"]
      }
    ]
  }
  ```

  ### Key Innovations

  #### 1. Executable Success Criteria

  Every success criterion MUST have a `validation_command` that:
  - Can be executed by a Claude Code `Bash` tool
  - Returns a clear PASS/FAIL or exit code
  - Requires no human interpretation

  ```json
  // BAD - not executable
  {"criterion": "Code is correct"}

  // GOOD - executable
  {
    "criterion": "TypeScript compiles without errors",
    "validation_command": "npx tsc --noEmit 2>&1; echo \"EXIT:$?\"",
    "expected_output": "EXIT:0",
    "on_failure": "retry"
  }
  ```

  #### 2. Automatic Retry Behavior (Replaces Manual Replanning)

  Instead of 5 manual replanning strategies, embed retry behavior:

  ```json
  "retry_behavior": {
    "max_attempts": 3,
    "strategy": "fix_and_retry",  // or "alternative_approach" or "skip_if_optional"
    "fix_hints": [
      "If import error: check file exists at import path",
      "If type error: verify interface matches expected shape"
    ],
    "escalation": "halt_with_context"
  }
  ```

  The executor doesn't "replan" - it follows the embedded retry rules.

  #### 3. Scribe Rules Pre-Applied

  Each step documents which Scribe rules influenced its design:

  ```json
  "scribe_rules_applied": [
    "global:use-functional-components",
    "frontend:tailwind-only",
    "testing:require-unit-tests"
  ]
  ```

  This eliminates the need for executors to re-interpret rules.

  ## Phase 3: Validation Hook Generation

  Your blueprint must include hook definitions for real-time validation:

  ```json
  {
    "validation_hooks": {
      "pre_execution": {
        "description": "Verify preconditions before starting",
        "checks": [
          {"check": "Project directory exists", "command": "test -d ."},
          {"check": "Dependencies installed", "command": "test -d node_modules || npm install"}
        ]
      },

      "post_step": {
        "description": "Validate after each step",
        "trigger": "PostToolUse:Write|Edit",
        "action": "Run step's validation_command array"
      },

      "quality_gate": {
        "description": "Final validation before completion",
        "trigger": "Stop",
        "checks": [
          {"check": "All tests pass", "command": "npm test"},
          {"check": "No type errors", "command": "npx tsc --noEmit"},
          {"check": "No lint errors", "command": "npm run lint"}
        ],
        "verdict_mapping": {
          "all_pass": "STRONG",
          "tests_pass_minor_lint": "SOUND",
          "tests_fail": "BLOCK_COMPLETION"
        }
      }
    }
  }
  ```

  ## Blueprint Output Format

  Your final blueprint must be a single JSON file that contains:

  1. **Header** - ID, goal, timestamps
  2. **Embedded Context** - All Scribe rules, discovered patterns
  3. **Execution-Ready Steps** - With micro-actions and executable criteria
  4. **Validation Hooks** - Pre-defined hook configurations
  5. **Completion Criteria** - What "done" looks like (executable)

  ## What Success Looks Like

  A successful blueprint:
  - Can be executed by a "dumb" executor that just follows instructions
  - Requires ZERO additional planning during execution
  - Has ZERO ambiguous success criteria
  - Embeds ALL context needed (no re-loading)
  - Defines its own validation hooks
  - Specifies retry behavior (no manual replanning)

  **You are the single source of truth. Build it complete.**
```

---

## PART 3: THE CAST EXECUTION LOGIC

### New Executor: `caster.yaml`

The caster is a lightweight executor that:
1. Reads the execution-ready blueprint
2. Executes micro-actions in sequence
3. Runs validation_commands after each step
4. Follows embedded retry_behavior on failure
5. Never replans - only retries with hints or escalates

```yaml
name: caster
description: Lightweight executor - follows execution-ready blueprints with hook-based reflexion
model: claude-sonnet-4-20250514
phase_color: gold

capabilities:
  - Blueprint execution without interpretation
  - Validation command execution
  - Automatic retry with embedded hints
  - Hook-triggered reflexion

tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash

# NO replanning logic
# NO checkpoint management
# NO context re-loading

instructions: |
  # The Caster - STUDIO Execution Agent

  You are **The Caster**, STUDIO's execution agent. You transform blueprints into reality
  through **faithful execution** with **automatic reflexion**.

  ## Your Mission

  Execute the blueprint **exactly as specified**. You do not plan. You do not interpret.
  You execute, validate, and either succeed or trigger automatic retry.

  ## Execution Flow

  ```
  FOR each step in blueprint.steps:
      1. Execute micro_actions in sequence
      2. Run each validation_command
      3. IF all pass → record success, continue
      4. IF any fail → check retry_behavior:
         - IF attempts < max_attempts → apply fix_hints, retry step
         - IF attempts >= max_attempts → escalate per escalation rule

  WHEN all steps complete:
      Hook triggers quality_gate validation
      IF quality_gate passes → Cast complete
      IF quality_gate fails → Block completion with context
  ```

  ## Execution Rules

  ### Rule 1: No Interpretation

  Execute what the blueprint says. If the blueprint says:
  ```json
  {"tool": "Write", "params": {"file_path": "/src/foo.ts", "content": "..."}}
  ```

  You execute exactly that. No improvisation.

  ### Rule 2: Validation is Mandatory

  After executing step actions, you MUST run every validation_command:

  ```bash
  # Example: Run the validation command
  result=$(test -f /src/foo.ts && echo 'PASS' || echo 'FAIL')

  if [[ "$result" != "PASS" ]]; then
    # Trigger retry behavior
  fi
  ```

  ### Rule 3: Retry, Don't Replan

  On failure, check the step's `retry_behavior`:

  ```json
  "retry_behavior": {
    "max_attempts": 3,
    "strategy": "fix_and_retry",
    "fix_hints": ["Check import paths", "Verify types match"]
  }
  ```

  Apply the fix_hints and retry. This is NOT replanning - it's following instructions.

  ### Rule 4: Escalate with Context

  If retry_behavior.escalation is "halt_with_context":

  ```bash
  # Halt and provide context for debugging
  echo "CAST HALTED at step: ${step_id}"
  echo "Validation failed: ${failed_criterion}"
  echo "Attempts: ${attempt_count}/${max_attempts}"
  echo "Last error: ${error_output}"
  echo "Fix hints tried: ${fix_hints_applied}"
  ```

  The Stop hook will catch this and block completion.

  ### Rule 5: Trust the Blueprint

  The Architect already:
  - Loaded all Scribe rules
  - Analyzed the codebase
  - Designed the approach
  - Specified exact actions
  - Defined validation commands
  - Embedded retry behavior

  Your job is execution, not second-guessing.

  ## Output Recording

  Record execution in a streamlined format:

  ```json
  {
    "cast_id": "cast_YYYYMMDD_HHMMSS",
    "blueprint_id": "bp_YYYYMMDD_HHMMSS_XXXX",
    "status": "in_progress|complete|halted",
    "steps": [
      {
        "step_id": "step_1",
        "status": "success|failed|retrying",
        "attempts": 1,
        "validations": [
          {"criterion": "...", "result": "PASS"},
          {"criterion": "...", "result": "PASS"}
        ],
        "artifacts_produced": ["path/to/file"],
        "duration_ms": 1234
      }
    ],
    "quality_gate": {
      "triggered": false,
      "result": null
    }
  }
  ```

  ## What Success Looks Like

  A successful cast:
  - Executes every step as specified
  - Validates every success criterion
  - Handles failures through embedded retry behavior
  - Produces all expected artifacts
  - Passes the quality gate hook

  **You are the executor. Cast with precision.**
```

---

## PART 4: VALIDATION STRATEGY

### Hook-Based Quality Assurance

Replace the separate Temperer agent with a comprehensive hook system:

#### 1. PreToolUse Hook: Blueprint Alignment

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "prompt",
            "prompt": "Verify this tool call matches the current blueprint step. Context: $ARGUMENTS. Check: 1) Is this the expected tool for the current step? 2) Do parameters match blueprint specification? 3) Is this the correct sequence? Respond {\"ok\": true} or {\"ok\": false, \"reason\": \"...\"}",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

#### 2. PostToolUse Hook: Step Validation

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/hooks/validate-step.sh",
            "timeout": 30,
            "statusMessage": "Validating step completion..."
          }
        ]
      }
    ]
  }
}
```

**validate-step.sh:**
```bash
#!/usr/bin/env bash
# Reads the current step's validation_commands from blueprint and executes them

set -euo pipefail

# Read hook input
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Find active cast and current step
CAST_DIR=$(find studio/casts -name "state.json" -exec grep -l '"status":"in_progress"' {} \; | head -1 | xargs dirname)
if [[ -z "$CAST_DIR" ]]; then
  exit 0  # No active cast, allow
fi

BLUEPRINT="${CAST_DIR}/blueprint.json"
STATE="${CAST_DIR}/state.json"

# Get current step from state
CURRENT_STEP=$(jq -r '.current_step' "$STATE")
if [[ -z "$CURRENT_STEP" || "$CURRENT_STEP" == "null" ]]; then
  exit 0
fi

# Get validation commands for current step
VALIDATIONS=$(jq -r ".steps[] | select(.id == \"$CURRENT_STEP\") | .success_criteria[]" "$BLUEPRINT" 2>/dev/null)

# Execute each validation command
FAILED=0
FAILED_REASON=""

while IFS= read -r validation; do
  cmd=$(echo "$validation" | jq -r '.validation_command')
  expected=$(echo "$validation" | jq -r '.expected_output')

  result=$(eval "$cmd" 2>&1 || true)

  if [[ "$result" != *"$expected"* ]]; then
    FAILED=1
    FAILED_REASON="Validation failed: $cmd (expected: $expected, got: $result)"
    break
  fi
done <<< "$VALIDATIONS"

if [[ $FAILED -eq 1 ]]; then
  # Check retry behavior
  MAX_ATTEMPTS=$(jq -r ".steps[] | select(.id == \"$CURRENT_STEP\") | .retry_behavior.max_attempts" "$BLUEPRINT")
  CURRENT_ATTEMPTS=$(jq -r ".steps[] | select(.id == \"$CURRENT_STEP\") | .attempts // 0" "$STATE")

  if [[ $CURRENT_ATTEMPTS -lt $MAX_ATTEMPTS ]]; then
    # Trigger retry
    FIX_HINTS=$(jq -r ".steps[] | select(.id == \"$CURRENT_STEP\") | .retry_behavior.fix_hints | join(\", \")" "$BLUEPRINT")
    echo "{\"decision\": \"block\", \"reason\": \"Step validation failed. Retry with hints: $FIX_HINTS\", \"hookSpecificOutput\": {\"hookEventName\": \"PostToolUse\", \"additionalContext\": \"$FAILED_REASON. Apply fix hints and retry.\"}}"
  else
    # Escalate
    echo "{\"decision\": \"block\", \"reason\": \"Step validation failed after max attempts. Halting cast.\", \"hookSpecificOutput\": {\"hookEventName\": \"PostToolUse\", \"additionalContext\": \"$FAILED_REASON. Max retry attempts reached.\"}}"
  fi
else
  exit 0  # All validations passed
fi
```

#### 3. Stop Hook: Quality Gate

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "agent",
            "prompt": "You are the quality gate. Read the active blueprint from studio/casts/*/blueprint.json and verify: 1) All steps show status 'success' in state.json 2) All validation_hooks.quality_gate.checks pass when executed 3) No critical issues exist. Return {\"ok\": true} if cast can complete, or {\"ok\": false, \"reason\": \"...\"} with specific fixes needed. $ARGUMENTS",
            "timeout": 120
          }
        ]
      }
    ]
  }
}
```

#### 4. SubagentStop Hook: Blueprint Verification (Replaces validate-agent.sh)

```json
{
  "hooks": {
    "SubagentStop": [
      {
        "matcher": "architect",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/hooks/validate-blueprint.sh",
            "timeout": 15
          }
        ]
      },
      {
        "matcher": "caster",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/hooks/validate-cast.sh",
            "timeout": 15
          }
        ]
      }
    ]
  }
}
```

### The Scribe Edge: Context That Prevents Re-Planning

The key insight: **Scribe context embedded in the blueprint prevents re-planning**.

```json
{
  "embedded_context": {
    "scribe_rules": {
      "global": "- Always use TypeScript strict mode\n- Prefer functional components\n- Use Zod for validation",
      "domains": {
        "frontend": "- Use Tailwind CSS exclusively\n- No inline styles",
        "testing": "- 80% coverage minimum\n- Use Jest + React Testing Library"
      }
    },
    "discovered_patterns": {
      "import_style": "absolute imports from @/",
      "component_structure": "functional with hooks",
      "state_management": "zustand",
      "api_pattern": "tRPC"
    },
    "constraints": {
      "node_version": "20.x",
      "package_manager": "pnpm",
      "deployment_target": "Vercel"
    }
  }
}
```

**Why this eliminates re-planning:**
1. Executor knows exact import style → no wrong imports to fix
2. Executor knows state management → no wrong patterns to refactor
3. Executor knows constraints → no environment mismatches
4. All decisions pre-made → execution is deterministic

---

## PART 5: IMPLEMENTATION ROADMAP

### Phase 1: Create New Agents
- [ ] Create `agents/architect.yaml` (Master Blueprint agent)
- [ ] Create `agents/caster.yaml` (Lightweight executor)

### Phase 2: Implement Validation Hooks
- [ ] Create `scripts/hooks/validate-step.sh`
- [ ] Create `scripts/hooks/validate-blueprint.sh`
- [ ] Create `scripts/hooks/validate-cast.sh`
- [ ] Update `hooks/hooks.json` with new hook configuration

### Phase 3: Update Schemas
- [ ] Create `schemas/execution-ready-blueprint.schema.json`
- [ ] Update `schemas/cast-state.schema.json` for streamlined format

### Phase 4: Deprecate Old Agents
- [ ] Mark `smith.yaml` as deprecated (replaced by architect)
- [ ] Mark `forgemaster.yaml` as deprecated (replaced by caster)
- [ ] Mark `temperer.yaml` as deprecated (replaced by hooks)

### Phase 5: Update Commands
- [ ] Update `/cast` command to use new pipeline
- [ ] Add `/blueprint` command for architect-only runs
- [ ] Add `/validate` command for manual quality gate

---

## Summary: Before vs After

| Aspect | Before (3-Phase) | After (2-Phase + Hooks) |
|--------|------------------|-------------------------|
| Planning | Smith + Forgemaster replan | Architect only |
| Context Loading | 3x per cast | 1x (embedded) |
| Replanning | 5 manual strategies | Automatic retry behavior |
| Validation | Temperer agent | Real-time hooks |
| State Files | 5-6 files | 2 files (blueprint + state) |
| Failure Recovery | Manual replan decision | Embedded retry rules |
| Quality Gate | Separate phase | Stop hook |

**Result:** Faster execution, less overhead, deterministic behavior, real-time quality assurance.
