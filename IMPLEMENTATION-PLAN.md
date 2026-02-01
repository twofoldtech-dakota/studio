# STUDIO Implementation Plan

Comprehensive plan for implementing all RECOMMENDATIONS.md features following Claude Code best practices.

---

## Current State Analysis

### What's Implemented
| Feature | Status | Location |
|---------|--------|----------|
| Task Manifest Schema | ✅ Complete | `schemas/task-manifest.schema.json` |
| Manifest Script | ✅ Complete | `scripts/manifest.sh` (status, board, timeline) |
| Basic Output Formatting | ✅ Complete | `scripts/output.sh` |
| State Management | ✅ Complete | `scripts/state.sh` |
| Hook System | ✅ Complete | `hooks/hooks.json` |
| Resumable Task Detection | ⚠️ Partial | `scripts/hooks/session-start.sh` (finds but doesn't prompt) |
| Progress Tracking | ⚠️ Partial | `manifest.sh` has progress bar (not integrated) |

### What's NOT Implemented
- Progress Visualization (real-time with ETA)
- Dry-Run Mode (`/build:preview`)
- Better Error Messages (contextual, actionable)
- Session Auto-Resume Prompt
- Confidence Scoring
- Auto-Generated Tests
- Self-Review Hook (LLM-powered)
- Requirements Traceability Matrix
- Parallel Step Execution
- Context Caching
- Incremental Plans
- Rich Terminal UI (spinners, boxes)
- Interactive Step Confirmation (`/build:interactive`)
- Plan Templates
- Analytics Dashboard
- Multi-Task Orchestration
- Learning from Corrections
- Rollback System

---

## Claude Code Capability Mapping

### Hooks (Primary Implementation Method)
| Hook Type | Claude Capability | Use For |
|-----------|-------------------|---------|
| `SessionStart` | Command/Agent | Auto-resume prompt, context caching |
| `PreToolUse` | Prompt/Command | Validation, interactive confirmation |
| `PostToolUse` | Command | Progress tracking, learning detection |
| `SubagentStart` | Agent | Pre-flight checks |
| `SubagentStop` | Agent | Self-review, quality gates |
| `Stop` | Command/Agent | Quality gates, analytics logging |
| `Notification` | Command | Progress visualization |

### Skills (SKILL.md Files)
| Skill | Use For |
|-------|---------|
| `playbooks/templates/SKILL.md` | Plan templates |
| `playbooks/analytics/SKILL.md` | Analytics collection |
| `playbooks/confidence/SKILL.md` | Confidence scoring methodology |

### Sub-Agents (Task Tool)
| Agent Type | Use For |
|------------|---------|
| `Explore` | Parallel codebase analysis |
| `Plan` | Incremental planning |
| `general-purpose` | Parallel step execution |

### Output Styles
| Style | Use For |
|-------|---------|
| `styles/progress.md` | Progress visualization formatting |
| `styles/interactive.md` | Interactive mode prompts |

---

## Phase 1: Quick Wins (High Impact, Low Effort)

### 1.1 Progress Visualization

**Claude Capability:** PostToolUse hook + output.sh enhancements

**Files to Modify:**
- `scripts/output.sh` - Add progress bar function
- `scripts/hooks/track-progress.sh` - Emit progress events
- `hooks/hooks.json` - Add progress notification hook

**Implementation:**

```bash
# scripts/output.sh - Add new functions

cmd_progress_bar() {
    local current="$1"
    local total="$2"
    local label="${3:-Progress}"
    local width=40

    local pct=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))

    local bar="${GREEN}"
    for ((i=0; i<filled; i++)); do bar+="█"; done
    bar+="${DIM}"
    for ((i=0; i<empty; i++)); do bar+="░"; done
    bar+="${NC}"

    printf "\r${BOLD}%s${NC}: [%s] %d%% (%d/%d)" "$label" "$bar" "$pct" "$current" "$total"
}

cmd_step_header() {
    local step_num="$1"
    local total="$2"
    local step_name="$3"
    local status="${4:-running}"

    local status_icon=""
    case "$status" in
        running) status_icon="⟳" ;;
        success) status_icon="${GREEN}✓${NC}" ;;
        failed)  status_icon="${RED}✗${NC}" ;;
        retry)   status_icon="${YELLOW}↻${NC}" ;;
    esac

    echo ""
    echo -e "${BOLD}╭─ STEP ${step_num}/${total}: ${step_name}${NC}"
    echo -e "│ Status: ${status_icon} ${status}"
}

cmd_build_status_box() {
    local task_id="$1"
    local phase="$2"
    local step="$3"
    local total="$4"
    local current_action="$5"

    local pct=$((step * 100 / total))

    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║${NC}  BUILDING: ${CYAN}${task_id}${NC}"
    echo -e "${BOLD}╠══════════════════════════════════════════════════════════════╣${NC}"
    cmd_progress_bar "$step" "$total" "Progress"
    echo ""
    echo -e "${BOLD}║${NC}  Phase:    ${phase} (step ${step}/${total})"
    echo -e "${BOLD}║${NC}  Current:  ${current_action}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
}
```

**hooks/hooks.json addition:**
```json
{
  "PostToolUse": [
    {
      "matcher": "Edit|Write",
      "hooks": [
        {
          "type": "command",
          "command": "${CLAUDE_PLUGIN_ROOT}/scripts/hooks/track-progress.sh"
        },
        {
          "type": "command",
          "command": "${CLAUDE_PLUGIN_ROOT}/scripts/hooks/emit-progress.sh"
        }
      ]
    }
  ]
}
```

**New file: scripts/hooks/emit-progress.sh**
```bash
#!/bin/bash
# Emit progress notification to terminal

MANIFEST=$(find_active_manifest)
if [[ -f "$MANIFEST" ]]; then
    STEP=$(jq -r '.progress.current_step // 0' "$MANIFEST")
    TOTAL=$(jq -r '.progress.total_steps // 1' "$MANIFEST")
    ACTION=$(jq -r '.progress.current_action // "Working..."' "$MANIFEST")

    "${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" progress_bar "$STEP" "$TOTAL" "Build"
fi
```

---

### 1.2 Dry-Run Mode

**Claude Capability:** Skill with `disable-model-invocation: false` + preview-only execution

**Files to Create/Modify:**
- `playbooks/preview/SKILL.md` - Preview methodology
- `commands/build.md` - Already has `/build:preview` trigger
- `agents/planner.yaml` - Add preview mode flag

**Implementation:**

**New file: playbooks/preview/SKILL.md**
```yaml
---
name: preview
description: Generate build preview without execution
disable-model-invocation: false
context: fork
---

# Preview Mode

Generate a detailed preview of what a build would do WITHOUT making any changes.

## Output Format

```
PREVIEW MODE - No changes will be made

╔══════════════════════════════════════════════════════════════╗
║  BUILD PREVIEW: [goal]                                       ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  Would gather requirements for:                              ║
║    • [requirement 1]                                         ║
║    • [requirement 2]                                         ║
║                                                              ║
║  Would create files:                                         ║
║    • [file path 1]                                           ║
║    • [file path 2]                                           ║
║                                                              ║
║  Would modify files:                                         ║
║    • [file path 1]                                           ║
║                                                              ║
║  Would run quality checks:                                   ║
║    • npm test                                                ║
║    • npx tsc --noEmit                                        ║
║                                                              ║
║  Estimated steps: X                                          ║
║  Confidence: XX%                                             ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝

Run `/build [goal]` to execute this plan.
```

## Methodology

1. **Analyze Goal** - Parse the goal and identify task type
2. **Gather Hypothetical Requirements** - What WOULD we ask?
3. **Generate Plan Skeleton** - Steps without micro-actions
4. **Estimate Impact** - Files that would be affected
5. **Show Preview** - Display formatted preview

## Important

- DO NOT create any files
- DO NOT modify any files
- DO NOT execute any commands
- ONLY analyze and display what WOULD happen
```

**Modify agents/planner.yaml** - Add preview phase:
```yaml
phases:
  - id: preview_check
    name: Preview Check
    description: Check if this is a preview request
    condition: "$ARGUMENTS contains 'preview'"
    action: "Load preview skill, generate preview, return without executing"
```

---

### 1.3 Better Error Messages

**Claude Capability:** PostToolUseFailure hook with agent-type analysis

**Files to Create:**
- `scripts/hooks/classify-error.sh` - Error classification
- `data/error-patterns.json` - Known error patterns and solutions

**Implementation:**

**New file: data/error-patterns.json**
```json
{
  "patterns": [
    {
      "match": "Cannot find module '(.+)'",
      "type": "missing_dependency",
      "why": "The step tried to import '$1' but it's not installed.",
      "fix": [
        "Run: npm install $1",
        "If it's a types package: npm install -D @types/$1"
      ],
      "auto_fix": "npm install $1"
    },
    {
      "match": "Property '(.+)' does not exist on type '(.+)'",
      "type": "type_error",
      "why": "TypeScript doesn't recognize property '$1' on type '$2'.",
      "fix": [
        "Check if the property name is spelled correctly",
        "Verify the type definition includes this property",
        "Add the property to the type or use type assertion"
      ]
    },
    {
      "match": "ENOENT: no such file or directory.*'(.+)'",
      "type": "missing_file",
      "why": "The file or directory '$1' doesn't exist.",
      "fix": [
        "Create the missing directory: mkdir -p $(dirname $1)",
        "Verify the path is correct"
      ],
      "auto_fix": "mkdir -p $(dirname $1)"
    },
    {
      "match": "SyntaxError: Unexpected token",
      "type": "syntax_error",
      "why": "There's a syntax error in the code.",
      "fix": [
        "Check for missing brackets, commas, or semicolons",
        "Verify string quotes are properly closed"
      ]
    }
  ]
}
```

**New file: scripts/hooks/classify-error.sh**
```bash
#!/bin/bash
# Classify errors and provide actionable messages

set -e

INPUT=$(cat)
ERROR_MSG=$(echo "$INPUT" | jq -r '.error // .stderr // ""')

if [[ -z "$ERROR_MSG" ]]; then
    exit 0
fi

PATTERNS_FILE="${CLAUDE_PLUGIN_ROOT}/data/error-patterns.json"

# Match error against patterns
MATCHED=$(jq -r --arg err "$ERROR_MSG" '
  .patterns[] |
  select($err | test(.match)) |
  {type, why, fix, auto_fix}
' "$PATTERNS_FILE" | head -1)

if [[ -n "$MATCHED" ]]; then
    TYPE=$(echo "$MATCHED" | jq -r '.type')
    WHY=$(echo "$MATCHED" | jq -r '.why')
    FIX=$(echo "$MATCHED" | jq -r '.fix | join("\n  ")')
    AUTO_FIX=$(echo "$MATCHED" | jq -r '.auto_fix // empty')

    "${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" error_box "$TYPE" "$WHY" "$FIX" "$AUTO_FIX"
fi
```

**Add to scripts/output.sh:**
```bash
cmd_error_box() {
    local error_type="$1"
    local why="$2"
    local fix="$3"
    local auto_fix="${4:-}"

    echo ""
    echo -e "${BOLD}${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${RED}║${NC}  ❌ ERROR: ${error_type}"
    echo -e "${BOLD}${RED}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BOLD}${RED}║${NC}"
    echo -e "${BOLD}${RED}║${NC}  ${BOLD}Why this happened:${NC}"
    echo -e "${BOLD}${RED}║${NC}  ${why}"
    echo -e "${BOLD}${RED}║${NC}"
    echo -e "${BOLD}${RED}║${NC}  ${BOLD}How to fix:${NC}"
    echo -e "${BOLD}${RED}║${NC}  ${fix}"

    if [[ -n "$auto_fix" ]]; then
        echo -e "${BOLD}${RED}║${NC}"
        echo -e "${BOLD}${RED}║${NC}  ${BOLD}Auto-fix available:${NC}"
        echo -e "${BOLD}${RED}║${NC}  [y] Run: ${auto_fix}"
        echo -e "${BOLD}${RED}║${NC}  [n] Fix manually"
    fi

    echo -e "${BOLD}${RED}║${NC}"
    echo -e "${BOLD}${RED}╚══════════════════════════════════════════════════════════════╝${NC}"
}
```

**Modify hooks/hooks.json** - Enhance PostToolUseFailure:
```json
{
  "PostToolUseFailure": [
    {
      "matcher": "",
      "hooks": [
        {
          "type": "command",
          "command": "${CLAUDE_PLUGIN_ROOT}/scripts/hooks/classify-error.sh"
        },
        {
          "type": "agent",
          "prompt": "A tool call failed. Error was classified. Check if auto-fix is available. If yes and safe, offer to apply. Otherwise, provide guidance based on the classified error.",
          "timeout": 30
        }
      ]
    }
  ]
}
```

---

### 1.4 Session Persistence (Auto-Resume)

**Claude Capability:** SessionStart hook with interactive prompt

**Files to Modify:**
- `scripts/hooks/session-start.sh` - Add resume prompt

**Implementation:**

**Modify scripts/hooks/session-start.sh:**
```bash
#!/usr/bin/env bash
# STUDIO Session Start Hook - With Auto-Resume

set -euo pipefail

STUDIO_DIR="${STUDIO_DIR:-studio}"
TASKS_DIR="${STUDIO_DIR}/tasks"
PROJECTS_DIR="${STUDIO_DIR}/projects"

# Find incomplete tasks with details
find_incomplete_tasks() {
    local tasks=()

    for manifest in "${PROJECTS_DIR}"/*/tasks/*/manifest.json; do
        if [[ -f "$manifest" ]]; then
            local status goal task_id updated step total
            status=$(jq -r '.status' "$manifest" 2>/dev/null)

            case "$status" in
                COMPLETE|FAILED|ABORTED) continue ;;
            esac

            task_id=$(jq -r '.id' "$manifest")
            goal=$(jq -r '.goal' "$manifest" | cut -c1-40)
            step=$(jq -r '.progress.current_step // 0' "$manifest")
            total=$(jq -r '.progress.total_steps // "?"' "$manifest")
            updated=$(jq -r '.updated_at' "$manifest")

            # Calculate time since last activity
            local now=$(date +%s)
            local then=$(date -d "$updated" +%s 2>/dev/null || echo $now)
            local diff=$(( (now - then) / 60 ))
            local time_ago="${diff} minutes ago"
            [[ $diff -gt 60 ]] && time_ago="$(( diff / 60 )) hours ago"
            [[ $diff -gt 1440 ]] && time_ago="$(( diff / 1440 )) days ago"

            tasks+=("{\"id\":\"$task_id\",\"goal\":\"$goal\",\"status\":\"$status\",\"step\":\"$step\",\"total\":\"$total\",\"last_activity\":\"$time_ago\"}")
        fi
    done

    if [[ ${#tasks[@]} -gt 0 ]]; then
        printf '[%s]' "$(IFS=,; echo "${tasks[*]}")"
    else
        printf '[]'
    fi
}

main() {
    local incomplete
    incomplete=$(find_incomplete_tasks)

    local count=$(echo "$incomplete" | jq 'length')

    if [[ "$count" -gt 0 ]]; then
        # Format the prompt for Claude
        local task_info=$(echo "$incomplete" | jq -r '.[0] | "ID: \(.id)\nGoal: \(.goal)\nStatus: \(.status) at step \(.step)/\(.total)\nLast activity: \(.last_activity)"')

        cat <<EOF
{"additionalContext": "UNFINISHED TASK DETECTED

╔══════════════════════════════════════════════════════════════╗
║  INCOMPLETE BUILD FOUND                                      ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
${task_info}
║                                                              ║
║  Options:                                                    ║
║  [r] Resume this build: /build resume                        ║
║  [a] Abort this build: /build abort                          ║
║  [n] Start a new build: /build <goal>                        ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝

Ask the user what they want to do with the incomplete build."}
EOF
    else
        cat <<EOF
{"additionalContext": "STUDIO session initialized. No incomplete tasks found."}
EOF
    fi

    exit 0
}

main
```

---

## Phase 2: Quality Improvements

### 2.1 Confidence Scoring

**Claude Capability:** New skill + planner integration

**Files to Create:**
- `playbooks/confidence/SKILL.md` - Confidence scoring methodology
- `schemas/confidence.schema.json` - Confidence schema

**Implementation:**

**New file: playbooks/confidence/SKILL.md**
```yaml
---
name: confidence
description: Score plan quality before execution
disable-model-invocation: false
---

# Confidence Scoring

Calculate a confidence score for a plan before execution.

## Scoring Factors (100 points total)

### Requirements Completeness (25 points)
- All personas consulted: +10
- User confirmed requirements: +10
- Edge cases identified: +5

### Step Quality (25 points)
- All steps atomic (single action): +10
- All steps have validation_command: +10
- Clear dependencies defined: +5

### Context Coverage (25 points)
- Memory rules embedded: +10
- Patterns discovered: +10
- Constraints acknowledged: +5

### Risk Assessment (25 points)
- Failure modes identified: +10
- Retry behavior defined: +10
- Rollback possible: +5

## Output Format

```
╔══════════════════════════════════════════════════════════════╗
║  PLAN CONFIDENCE: XX%                                        ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  Requirements:    [████████░░] 80%                           ║
║    ✓ All personas consulted                                  ║
║    ✓ User confirmed                                          ║
║    ⚠ 2 edge cases not addressed                              ║
║                                                              ║
║  Step Quality:    [██████████] 100%                          ║
║    ✓ All steps atomic                                        ║
║    ✓ All have validation commands                            ║
║    ✓ Dependencies clear                                      ║
║                                                              ║
║  Context:         [████████░░] 80%                           ║
║    ✓ 5 Memory rules embedded                                 ║
║    ✓ 3 patterns discovered                                   ║
║    ⚠ No constraints documented                               ║
║                                                              ║
║  Risk:            [██████░░░░] 60%                           ║
║    ✓ Retry behavior defined                                  ║
║    ⚠ No failure mode analysis                                ║
║    ⚠ Rollback not configured                                 ║
║                                                              ║
║  Recommendation: PROCEED WITH CAUTION                        ║
║  Address warnings before build for best results.             ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```

## Thresholds
- **90%+**: Proceed with confidence
- **70-89%**: Proceed with caution
- **50-69%**: Review warnings first
- **<50%**: Improve plan before proceeding
```

**Modify agents/planner.yaml** - Add confidence scoring phase:
```yaml
phases:
  # ... existing phases ...
  - id: confidence_scoring
    name: Confidence Scoring
    description: Calculate and display plan confidence score
    action: |
      Load confidence skill.
      Analyze plan against scoring factors.
      Display confidence score.
      If score < 70%, ask user to confirm before proceeding.
```

---

### 2.2 Auto-Generated Tests

**Claude Capability:** Builder phase addition

**Files to Modify:**
- `agents/planner.yaml` - Add test generation to steps

**Implementation:**

Add to planner.yaml instructions:
```yaml
## Test Generation

For each requirement, generate a test skeleton:

```typescript
// Auto-generated from [REQ-ID]: [requirement description]
describe('[Feature Name]', () => {
  it('should [expected behavior from requirement]', async () => {
    // REQ-[ID]: Happy path
    // TODO: Implement test
  });

  it('should handle [edge case from requirement]', async () => {
    // REQ-[ID]: Edge case
    // TODO: Implement test
  });
});
```

Add test file creation as a step in the plan with:
- `step_type: "test_skeleton"`
- `linked_requirements: ["REQ-001", "REQ-002"]`
- Validation: file exists with correct structure
```

---

### 2.3 Self-Review Hook

**Claude Capability:** SubagentStop hook with agent-type review

**Files to Modify:**
- `hooks/hooks.json` - Add self-review agent

**Implementation:**

**Modify hooks/hooks.json:**
```json
{
  "SubagentStop": [
    {
      "matcher": "builder",
      "hooks": [
        {
          "type": "agent",
          "prompt": "Perform a self-review of the build. Compare generated code against:\n\n1. Original requirements from plan.json\n2. Memory rules in embedded_context\n3. Security best practices\n\nFor each file created/modified, verify:\n- Matches specification\n- Follows embedded patterns\n- No obvious security issues\n\nReturn a review summary:\n```json\n{\n  \"reviewed_files\": [\"file1.ts\", \"file2.ts\"],\n  \"requirements_met\": [\"REQ-001\", \"REQ-002\"],\n  \"requirements_missing\": [],\n  \"suggestions\": [\"Consider adding rate limiting\"],\n  \"security_concerns\": [],\n  \"verdict\": \"APPROVED|NEEDS_REVIEW|REJECTED\"\n}\n```",
          "timeout": 120
        }
      ]
    }
  ]
}
```

---

### 2.4 Requirements Traceability Matrix

**Claude Capability:** New command + manifest.sh enhancement

**Files to Create:**
- `commands/trace.md` - Traceability command

**New file: commands/trace.md**
```yaml
---
name: trace
description: Display requirements traceability matrix
triggers:
  - "/trace"
  - "/build:trace"
---

# Requirements Traceability

Display the full traceability from requirements → steps → artifacts → tests.

## Command

```bash
/trace [task_id]
```

## Output Format

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║  REQUIREMENTS TRACEABILITY                                                     ║
╠═══════════╦═══════════════════════════════╦═══════════════╦════════════════════╣
║ REQ ID    ║ Description                   ║ Steps         ║ Verification       ║
╠═══════════╬═══════════════════════════════╬═══════════════╬════════════════════╣
║ REQ-001   ║ User registration             ║ STEP-1,2      ║ auth.test.ts:12    ║
║ REQ-002   ║ Password validation           ║ STEP-1        ║ auth.test.ts:24    ║
║ REQ-003   ║ Email uniqueness              ║ STEP-3        ║ auth.test.ts:36    ║
╚═══════════╩═══════════════════════════════╩═══════════════╩════════════════════╝

Coverage: 3/3 requirements implemented and verified (100%)
```

## Implementation

Read from manifest.json:
- `requirements.functional[]`
- `requirements.*.linked_steps[]`
- `artifacts.created[].linked_requirements[]`
```

**Add to scripts/manifest.sh:**
```bash
cmd_trace() {
    local task_dir
    task_dir=$(find_active_task "${1:-}")
    local manifest="${task_dir}/manifest.json"
    local plan="${task_dir}/plan.json"

    echo ""
    echo -e "${BOLD}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║${NC}  REQUIREMENTS TRACEABILITY"
    echo -e "${BOLD}╠═══════════╦═══════════════════════════════╦═══════════════╦════════════════════╣${NC}"
    echo -e "${BOLD}║${NC} REQ ID    ${BOLD}║${NC} Description                   ${BOLD}║${NC} Steps         ${BOLD}║${NC} Verification"
    echo -e "${BOLD}╠═══════════╬═══════════════════════════════╬═══════════════╬════════════════════╣${NC}"

    # Parse requirements and show traceability
    jq -r '.requirements.functional[] | "\(.id)|\(.description)|\(.linked_steps // [] | join(","))|\(.verification // "pending")"' "$manifest" 2>/dev/null | \
    while IFS='|' read -r id desc steps verify; do
        printf "${BOLD}║${NC} %-9s ${BOLD}║${NC} %-29s ${BOLD}║${NC} %-13s ${BOLD}║${NC} %-18s ${BOLD}║${NC}\n" \
            "$id" "${desc:0:29}" "${steps:0:13}" "${verify:0:18}"
    done

    echo -e "${BOLD}╚═══════════╩═══════════════════════════════╩═══════════════╩════════════════════╝${NC}"

    # Calculate coverage
    local total=$(jq '.requirements.functional | length' "$manifest")
    local verified=$(jq '[.requirements.functional[] | select(.verification != null and .verification != "pending")] | length' "$manifest")
    local pct=$((verified * 100 / (total > 0 ? total : 1)))

    echo ""
    echo -e "Coverage: ${verified}/${total} requirements verified (${pct}%)"
}
```

---

## Phase 3: Performance Optimizations

### 3.1 Parallel Step Execution

**Claude Capability:** Task tool with multiple agents

**Files to Modify:**
- `agents/builder.yaml` - Add parallel execution mode
- `schemas/execution-ready-plan.schema.json` - Add dependency graph

**Implementation:**

Add to plan schema:
```json
{
  "steps": {
    "items": {
      "properties": {
        "depends_on": {
          "type": "array",
          "items": { "type": "string" },
          "description": "Step IDs this step depends on"
        },
        "parallelizable": {
          "type": "boolean",
          "default": false
        }
      }
    }
  },
  "execution_batches": {
    "type": "array",
    "items": {
      "type": "object",
      "properties": {
        "batch_id": { "type": "integer" },
        "steps": { "type": "array", "items": { "type": "string" } },
        "parallel": { "type": "boolean" }
      }
    }
  }
}
```

Add to builder.yaml:
```yaml
## Parallel Execution

When plan contains `execution_batches`:

1. Analyze dependency graph
2. Group independent steps into batches
3. For parallel batches, use Task tool to spawn multiple agents:

```
Batch 1: [step_1] - sequential
Batch 2: [step_2, step_3] - PARALLEL (no dependencies between them)
Batch 3: [step_4] - sequential (depends on batch 2)
```

Use Task tool with multiple invocations in single message:

```javascript
// Execute step_2 and step_3 in parallel
Task({ prompt: "Execute step_2...", subagent_type: "general-purpose" })
Task({ prompt: "Execute step_3...", subagent_type: "general-purpose" })
```

Wait for all parallel steps to complete before proceeding to next batch.
```

---

### 3.2 Context Caching

**Claude Capability:** SessionStart hook + file-based cache

**Files to Create:**
- `scripts/hooks/cache-context.sh` - Cache loader
- `.cache/` directory for cached context

**Implementation:**

**New file: scripts/hooks/cache-context.sh**
```bash
#!/bin/bash
# Cache frequently-used context at session start

CACHE_DIR="${STUDIO_DIR:-.}/.cache"
CACHE_FILE="${CACHE_DIR}/context-cache.json"
CACHE_TTL=3600  # 1 hour

mkdir -p "$CACHE_DIR"

# Check if cache is valid
if [[ -f "$CACHE_FILE" ]]; then
    age=$(($(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)))
    if [[ $age -lt $CACHE_TTL ]]; then
        cat "$CACHE_FILE"
        exit 0
    fi
fi

# Build fresh cache
cache='{}'

# Cache memory rules
for rule_file in "${STUDIO_DIR}/memory"/*.md; do
    if [[ -f "$rule_file" ]]; then
        name=$(basename "$rule_file" .md)
        content=$(cat "$rule_file" | jq -Rs .)
        cache=$(echo "$cache" | jq ".memory_rules.\"$name\" = $content")
    fi
done

# Cache tier1 team
for team_file in "${STUDIO_DIR}/team/tier1"/*.md; do
    if [[ -f "$team_file" ]]; then
        name=$(basename "$team_file" .md)
        content=$(cat "$team_file" | jq -Rs .)
        cache=$(echo "$cache" | jq ".team.tier1.\"$name\" = $content")
    fi
done

# Cache playbook skills
for skill_file in "${STUDIO_DIR}/playbooks"/*/SKILL.md; do
    if [[ -f "$skill_file" ]]; then
        name=$(dirname "$skill_file" | xargs basename)
        content=$(cat "$skill_file" | jq -Rs .)
        cache=$(echo "$cache" | jq ".playbooks.\"$name\" = $content")
    fi
done

echo "$cache" | jq '.' > "$CACHE_FILE"
echo "$cache"
```

---

### 3.3 Incremental Plans

**Claude Capability:** Plan diffing + partial regeneration

**Files to Create:**
- `playbooks/incremental/SKILL.md` - Incremental planning methodology

**New file: playbooks/incremental/SKILL.md**
```yaml
---
name: incremental
description: Update only affected steps when requirements change
---

# Incremental Planning

When requirements change, only regenerate affected steps.

## Process

1. **Identify Changed Requirements**
   ```
   REQ-003 changed: "Email validation" → "Email validation with domain whitelist"
   ```

2. **Find Linked Steps**
   ```
   REQ-003 linked to: step_1 (validation schema), step_5 (tests)
   ```

3. **Regenerate Only Affected Steps**
   ```
   Regenerating 2/5 steps...
   - step_1: Create validation schema ← REGENERATE
   - step_2: Create auth service ← UNCHANGED
   - step_3: Create controller ← UNCHANGED
   - step_4: Create routes ← UNCHANGED
   - step_5: Write tests ← REGENERATE
   ```

4. **Preserve Unchanged Steps**
   Keep existing micro_actions, validation_commands for unchanged steps.

## Implementation

```javascript
function incrementalUpdate(oldPlan, changedReqs) {
  const affectedSteps = changedReqs.flatMap(req =>
    oldPlan.steps.filter(s => s.linked_requirements.includes(req.id))
  );

  // Keep unchanged steps
  const unchangedSteps = oldPlan.steps.filter(s =>
    !affectedSteps.includes(s)
  );

  // Regenerate only affected steps
  const regeneratedSteps = regenerateSteps(affectedSteps, changedReqs);

  return {
    ...oldPlan,
    steps: [...unchangedSteps, ...regeneratedSteps].sort(byOrder)
  };
}
```
```

---

## Phase 4: DX Polish

### 4.1 Rich Terminal UI

**Claude Capability:** Enhanced output.sh with Unicode box drawing

**Files to Modify:**
- `scripts/output.sh` - Add spinner, tables, advanced boxes

**Add to scripts/output.sh:**
```bash
# Spinner characters
SPINNERS=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
SPINNER_IDX=0

cmd_spinner() {
    local message="$1"
    SPINNER_IDX=$(( (SPINNER_IDX + 1) % ${#SPINNERS[@]} ))
    printf "\r${CYAN}${SPINNERS[$SPINNER_IDX]}${NC} %s" "$message"
}

cmd_table() {
    local headers="$1"
    shift
    local rows=("$@")

    # Calculate column widths
    IFS='|' read -ra cols <<< "$headers"
    local widths=()
    for col in "${cols[@]}"; do
        widths+=("${#col}")
    done

    # Print header
    printf "${BOLD}"
    for i in "${!cols[@]}"; do
        printf "| %-${widths[$i]}s " "${cols[$i]}"
    done
    printf "|${NC}\n"

    # Print separator
    for w in "${widths[@]}"; do
        printf "+%s" "$(printf '─%.0s' $(seq 1 $((w + 2))))"
    done
    printf "+\n"

    # Print rows
    for row in "${rows[@]}"; do
        IFS='|' read -ra cells <<< "$row"
        for i in "${!cells[@]}"; do
            printf "| %-${widths[$i]}s " "${cells[$i]}"
        done
        printf "|\n"
    done
}

cmd_panel() {
    local title="$1"
    local content="$2"
    local color="${3:-$CYAN}"

    local width=60
    local title_pad=$(( (width - ${#title} - 2) / 2 ))

    echo -e "${color}╭$(printf '─%.0s' $(seq 1 $width))╮${NC}"
    echo -e "${color}│${NC}$(printf ' %.0s' $(seq 1 $title_pad))${BOLD}${title}${NC}$(printf ' %.0s' $(seq 1 $((width - title_pad - ${#title}))))${color}│${NC}"
    echo -e "${color}├$(printf '─%.0s' $(seq 1 $width))┤${NC}"

    while IFS= read -r line; do
        local pad=$((width - ${#line}))
        echo -e "${color}│${NC} ${line}$(printf ' %.0s' $(seq 1 $((pad - 1))))${color}│${NC}"
    done <<< "$content"

    echo -e "${color}╰$(printf '─%.0s' $(seq 1 $width))╯${NC}"
}
```

---

### 4.2 Interactive Step Confirmation

**Claude Capability:** PreToolUse hook with user prompts

**Files to Modify:**
- `hooks/hooks.json` - Add interactive mode hook
- `commands/build.md` - Document interactive mode

**Add to hooks/hooks.json:**
```json
{
  "PreToolUse": [
    {
      "matcher": "Edit|Write",
      "condition": "env.STUDIO_INTERACTIVE == 'true'",
      "hooks": [
        {
          "type": "prompt",
          "prompt": "INTERACTIVE MODE: About to execute $TOOL_NAME on $FILE_PATH.\n\nPreview:\n$TOOL_INPUT\n\nOptions:\n[y] Execute\n[e] Edit first\n[s] Skip\n[a] Abort build\n\nWait for user confirmation before proceeding. If user chooses 'e', ask what to change. If 'a', halt the build immediately."
        }
      ]
    }
  ]
}
```

---

### 4.3 Plan Templates

**Claude Capability:** New skill with template library

**Files to Create:**
- `playbooks/templates/SKILL.md` - Template system
- `templates/` directory with template files

**New file: playbooks/templates/SKILL.md**
```yaml
---
name: templates
description: Pre-built plan templates for common patterns
---

# Plan Templates

Use templates to accelerate planning for common patterns.

## Available Templates

### api-endpoint
REST endpoint with full CRUD operations.
```
Steps: schema → service → controller → routes → tests
Files: src/schemas/, src/services/, src/controllers/, src/routes/, tests/
```

### react-component
React component with tests and stories.
```
Steps: component → styles → tests → story
Files: src/components/, tests/, stories/
```

### database-migration
Schema change with rollback support.
```
Steps: migration_up → migration_down → seed → test
Files: migrations/, seeds/
```

### auth-flow
Authentication feature (login, register, reset).
```
Steps: schema → service → middleware → routes → tests
Files: src/auth/
```

### integration
Third-party API integration.
```
Steps: client → types → service → error_handling → tests
Files: src/integrations/
```

## Usage

When user requests `/build:template <template-name> <goal>`:

1. Load template from `templates/<name>.json`
2. Pre-fill step structure
3. Only gather domain-specific requirements
4. Complete plan with template as base

## Template Format

```json
{
  "name": "api-endpoint",
  "description": "REST endpoint with CRUD",
  "steps": [
    {
      "id": "step_schema",
      "name": "Create validation schema",
      "template": true,
      "requires_input": ["entity_name", "fields"]
    }
  ],
  "questions": [
    "What entity is this endpoint for?",
    "What fields should it have?",
    "What operations are needed (CRUD)?"
  ]
}
```
```

**Create template directory and example:**

**New file: templates/api-endpoint.json**
```json
{
  "name": "api-endpoint",
  "description": "REST API endpoint with full CRUD operations",
  "version": "1.0.0",
  "steps": [
    {
      "id": "step_1",
      "name": "Create validation schema",
      "step_type": "schema",
      "outputs": ["src/schemas/{{entity}}.ts"],
      "requires_input": ["entity_name", "fields"]
    },
    {
      "id": "step_2",
      "name": "Create service layer",
      "step_type": "service",
      "outputs": ["src/services/{{entity}}.service.ts"],
      "depends_on": ["step_1"]
    },
    {
      "id": "step_3",
      "name": "Create controller",
      "step_type": "controller",
      "outputs": ["src/controllers/{{entity}}.controller.ts"],
      "depends_on": ["step_2"]
    },
    {
      "id": "step_4",
      "name": "Create routes",
      "step_type": "routes",
      "outputs": ["src/routes/{{entity}}.routes.ts"],
      "depends_on": ["step_3"]
    },
    {
      "id": "step_5",
      "name": "Create tests",
      "step_type": "test",
      "outputs": ["tests/{{entity}}.test.ts"],
      "depends_on": ["step_4"]
    }
  ],
  "questions": [
    {
      "id": "entity_name",
      "question": "What entity is this endpoint for?",
      "example": "User, Product, Order"
    },
    {
      "id": "fields",
      "question": "What fields should the entity have?",
      "example": "name: string, email: string, active: boolean"
    },
    {
      "id": "operations",
      "question": "Which CRUD operations are needed?",
      "options": ["create", "read", "update", "delete", "list"],
      "default": ["create", "read", "update", "delete", "list"]
    }
  ],
  "quality_checks": [
    {"name": "TypeScript compiles", "command": "npx tsc --noEmit"},
    {"name": "Tests pass", "command": "npm test -- --grep {{entity}}"},
    {"name": "No lint errors", "command": "npm run lint"}
  ]
}
```

---

### 4.4 Analytics Dashboard

**Claude Capability:** Stop hook for logging + new command

**Files to Create:**
- `scripts/analytics.sh` - Analytics collection and display
- `data/analytics.json` - Analytics data store
- `commands/analytics.md` - Analytics command

**New file: scripts/analytics.sh**
```bash
#!/bin/bash
# STUDIO Analytics

ANALYTICS_FILE="${STUDIO_DIR:-studio}/data/analytics.json"

# Initialize if not exists
init_analytics() {
    if [[ ! -f "$ANALYTICS_FILE" ]]; then
        mkdir -p "$(dirname "$ANALYTICS_FILE")"
        echo '{"builds":[],"summary":{"total":0,"complete":0,"failed":0,"aborted":0}}' > "$ANALYTICS_FILE"
    fi
}

# Log a build completion
log_build() {
    init_analytics

    local task_id="$1"
    local status="$2"
    local duration="$3"
    local steps="$4"
    local retries="$5"
    local verdict="$6"

    local now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local tmp=$(mktemp)
    jq --arg id "$task_id" \
       --arg status "$status" \
       --arg duration "$duration" \
       --arg steps "$steps" \
       --arg retries "$retries" \
       --arg verdict "$verdict" \
       --arg time "$now" \
       '.builds += [{
         "id": $id,
         "status": $status,
         "duration_ms": ($duration | tonumber),
         "steps": ($steps | tonumber),
         "retries": ($retries | tonumber),
         "verdict": $verdict,
         "completed_at": $time
       }] |
       .summary.total += 1 |
       if $status == "COMPLETE" then .summary.complete += 1
       elif $status == "FAILED" then .summary.failed += 1
       elif $status == "ABORTED" then .summary.aborted += 1
       else . end' "$ANALYTICS_FILE" > "$tmp" && mv "$tmp" "$ANALYTICS_FILE"
}

# Display dashboard
show_dashboard() {
    init_analytics

    local days="${1:-30}"
    local cutoff=$(date -d "$days days ago" +%s 2>/dev/null || date -v-${days}d +%s)

    # Filter to recent builds
    local stats=$(jq --arg cutoff "$cutoff" '
      .builds | map(select((.completed_at | fromdateiso8601) > ($cutoff | tonumber))) |
      {
        total: length,
        complete: map(select(.status == "COMPLETE")) | length,
        failed: map(select(.status == "FAILED")) | length,
        aborted: map(select(.status == "ABORTED")) | length,
        avg_duration: (if length > 0 then (map(.duration_ms) | add / length / 1000) else 0 end),
        avg_steps: (if length > 0 then (map(.steps) | add / length) else 0 end),
        avg_retries: (if length > 0 then (map(.retries) | add / length) else 0 end),
        verdicts: (group_by(.verdict) | map({key: .[0].verdict, value: length}) | from_entries)
      }
    ' "$ANALYTICS_FILE")

    local total=$(echo "$stats" | jq '.total')
    local complete=$(echo "$stats" | jq '.complete')
    local failed=$(echo "$stats" | jq '.failed')
    local success_rate=$((complete * 100 / (total > 0 ? total : 1)))
    local avg_duration=$(echo "$stats" | jq '.avg_duration | floor')
    local avg_steps=$(echo "$stats" | jq '.avg_steps * 10 | floor / 10')
    local avg_retries=$(echo "$stats" | jq '.avg_retries * 10 | floor / 10')

    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║${NC}  STUDIO ANALYTICS (Last ${days} days)"
    echo -e "${BOLD}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BOLD}║${NC}"
    echo -e "${BOLD}║${NC}  Builds:     ${total} total   ${GREEN}${complete} complete${NC}   ${RED}${failed} failed${NC}"
    echo -e "${BOLD}║${NC}  Success:    ${success_rate}%"
    echo -e "${BOLD}║${NC}"
    echo -e "${BOLD}║${NC}  Avg Duration:   ${avg_duration} seconds"
    echo -e "${BOLD}║${NC}  Avg Steps:      ${avg_steps}"
    echo -e "${BOLD}║${NC}  Avg Retries:    ${avg_retries} per build"
    echo -e "${BOLD}║${NC}"

    # Verdict breakdown
    local strong=$(echo "$stats" | jq '.verdicts.STRONG // 0')
    local sound=$(echo "$stats" | jq '.verdicts.SOUND // 0')
    local unstable=$(echo "$stats" | jq '.verdicts.UNSTABLE // 0')

    echo -e "${BOLD}║${NC}  Quality Verdicts:"
    echo -e "${BOLD}║${NC}  ${GREEN}STRONG${NC}: ${strong}  ${GREEN}SOUND${NC}: ${sound}  ${YELLOW}UNSTABLE${NC}: ${unstable}"
    echo -e "${BOLD}║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
}

# Main
case "${1:-dashboard}" in
    log)     log_build "$2" "$3" "$4" "$5" "$6" "$7" ;;
    dashboard|show) show_dashboard "${2:-30}" ;;
    *)       echo "Usage: analytics.sh {log|dashboard} [args]" ;;
esac
```

---

## Phase 5: Advanced Features

### 5.1 Multi-Task Orchestration

**Claude Capability:** Project-level manifest + task dependencies

**Files to Create:**
- `schemas/project.schema.json` - Project schema
- `commands/project.md` - Project commands
- `scripts/project.sh` - Project management

**New file: commands/project.md**
```yaml
---
name: project
description: Orchestrate multiple related tasks as a project
triggers:
  - "/project"
  - "/project:init"
  - "/project:task"
  - "/project:status"
---

# Project Orchestration

Manage multiple related tasks with dependencies.

## Commands

### `/project:init <name>`
Create a new project.

### `/project:task <goal>`
Add a task to the current project.

### `/project:status`
Show project status with task dependencies.

## Project Structure

```
studio/projects/[project_id]/
├── project.json      # Project manifest
└── tasks/
    ├── task_1/
    ├── task_2/
    └── task_3/
```

## Project Manifest

```json
{
  "id": "project_20260201",
  "name": "E-commerce Platform",
  "tasks": [
    {"id": "task_1", "goal": "User auth", "depends_on": []},
    {"id": "task_2", "goal": "Product catalog", "depends_on": []},
    {"id": "task_3", "goal": "Shopping cart", "depends_on": ["task_1", "task_2"]},
    {"id": "task_4", "goal": "Checkout", "depends_on": ["task_3"]}
  ],
  "shared_context": {
    "tech_stack": "Next.js, Prisma, PostgreSQL",
    "patterns": {}
  }
}
```

## Dependency Resolution

Execute tasks respecting dependencies:
1. task_1, task_2 can run in parallel
2. task_3 waits for both
3. task_4 waits for task_3
```

---

### 5.2 Learning from Corrections

**Claude Capability:** PostToolUse hook detecting user edits

**Files to Create:**
- `scripts/hooks/detect-corrections.sh` - Detect user changes
- `memory/corrections.md` - Learned corrections

**New file: scripts/hooks/detect-corrections.sh**
```bash
#!/bin/bash
# Detect when user modifies generated code

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [[ -z "$FILE_PATH" ]]; then
    exit 0
fi

# Check if this file was recently generated by STUDIO
MANIFEST=$(find_active_manifest)
if [[ ! -f "$MANIFEST" ]]; then
    exit 0
fi

GENERATED=$(jq -r --arg path "$FILE_PATH" '.artifacts[] | select(.path == $path) | .path' "$MANIFEST" 2>/dev/null)

if [[ -z "$GENERATED" ]]; then
    exit 0
fi

# Get git diff for this file
DIFF=$(git diff HEAD -- "$FILE_PATH" 2>/dev/null)

if [[ -n "$DIFF" ]]; then
    # User modified generated code - log for learning
    CORRECTIONS_FILE="${STUDIO_DIR:-studio}/memory/corrections.md"

    echo "" >> "$CORRECTIONS_FILE"
    echo "## Correction detected: $(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> "$CORRECTIONS_FILE"
    echo "File: $FILE_PATH" >> "$CORRECTIONS_FILE"
    echo '```diff' >> "$CORRECTIONS_FILE"
    echo "$DIFF" >> "$CORRECTIONS_FILE"
    echo '```' >> "$CORRECTIONS_FILE"

    # Output for Claude to analyze
    cat <<EOF
{"additionalContext": "User correction detected on generated file: $FILE_PATH

The user modified code that STUDIO generated. Analyze the diff to see if this represents a pattern we should learn:

$DIFF

If this looks like a consistent preference (e.g., always use select() in Prisma, always add error handling), suggest adding it as a Memory rule."}
EOF
fi
```

---

### 5.3 Rollback System

**Claude Capability:** Git-based snapshots + command

**Files to Create:**
- `scripts/rollback.sh` - Rollback management
- `commands/rollback.md` - Rollback command

**New file: scripts/rollback.sh**
```bash
#!/bin/bash
# STUDIO Rollback System

STUDIO_TAG_PREFIX="studio-task-"

# Create snapshot before task
create_snapshot() {
    local task_id="$1"

    # Stash any uncommitted changes
    git stash push -m "studio-pre-${task_id}" 2>/dev/null || true

    # Create tag at current HEAD
    git tag "${STUDIO_TAG_PREFIX}${task_id}" HEAD 2>/dev/null || true

    echo "Snapshot created: ${STUDIO_TAG_PREFIX}${task_id}"
}

# List available rollback points
list_snapshots() {
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║${NC}  ROLLBACK OPTIONS"
    echo -e "${BOLD}╠══════════════════════════════════════════════════════════════╣${NC}"

    git tag -l "${STUDIO_TAG_PREFIX}*" --sort=-creatordate | head -10 | while read -r tag; do
        local task_id="${tag#$STUDIO_TAG_PREFIX}"
        local date=$(git log -1 --format=%ci "$tag" 2>/dev/null | cut -d' ' -f1)
        local changes=$(git diff --stat "${tag}..HEAD" 2>/dev/null | tail -1)

        echo -e "${BOLD}║${NC}"
        echo -e "${BOLD}║${NC}  ${CYAN}${task_id}${NC} (${date})"
        echo -e "${BOLD}║${NC}  Changes: ${changes}"
    done

    echo -e "${BOLD}║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
}

# Rollback to snapshot
rollback_to() {
    local task_id="$1"
    local tag="${STUDIO_TAG_PREFIX}${task_id}"

    if ! git rev-parse "$tag" >/dev/null 2>&1; then
        echo "Snapshot not found: $task_id"
        exit 1
    fi

    # Show what will be reverted
    echo "Files that will be reverted:"
    git diff --name-only "${tag}..HEAD"

    echo ""
    read -p "Proceed with rollback? [y/N] " confirm

    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        git checkout "$tag" -- .
        echo "Rolled back to ${task_id}"
    else
        echo "Rollback cancelled"
    fi
}

# Main
case "${1:-list}" in
    create)   create_snapshot "$2" ;;
    list)     list_snapshots ;;
    to)       rollback_to "$2" ;;
    *)        echo "Usage: rollback.sh {create|list|to} [task_id]" ;;
esac
```

---

## File Summary

### New Files to Create

| File | Purpose |
|------|---------|
| `playbooks/preview/SKILL.md` | Dry-run preview methodology |
| `playbooks/confidence/SKILL.md` | Confidence scoring methodology |
| `playbooks/templates/SKILL.md` | Template system |
| `playbooks/incremental/SKILL.md` | Incremental planning |
| `data/error-patterns.json` | Error classification patterns |
| `scripts/hooks/classify-error.sh` | Error classifier |
| `scripts/hooks/emit-progress.sh` | Progress emitter |
| `scripts/hooks/cache-context.sh` | Context caching |
| `scripts/hooks/detect-corrections.sh` | Learning detector |
| `scripts/analytics.sh` | Analytics system |
| `scripts/rollback.sh` | Rollback system |
| `scripts/project.sh` | Project orchestration |
| `commands/trace.md` | Traceability command |
| `commands/analytics.md` | Analytics command |
| `commands/project.md` | Project commands |
| `commands/rollback.md` | Rollback command |
| `templates/api-endpoint.json` | API template |
| `templates/react-component.json` | React template |

### Files to Modify

| File | Changes |
|------|---------|
| `scripts/output.sh` | Add progress_bar, spinner, error_box, panel, table |
| `scripts/manifest.sh` | Add trace command |
| `scripts/hooks/session-start.sh` | Add auto-resume prompt |
| `hooks/hooks.json` | Add new hooks for all features |
| `agents/planner.yaml` | Add confidence, preview, templates phases |
| `agents/builder.yaml` | Add parallel execution mode |
| `schemas/execution-ready-plan.schema.json` | Add dependency graph |

---

## Implementation Order

### Sprint 1: Foundation
1. Progress visualization (output.sh + hooks)
2. Better error messages (error-patterns.json + classify-error.sh)
3. Session persistence (session-start.sh enhancement)

### Sprint 2: Quality
4. Confidence scoring (playbooks/confidence + planner integration)
5. Self-review hook (hooks.json enhancement)
6. Requirements traceability (manifest.sh + commands/trace.md)

### Sprint 3: DX
7. Dry-run mode (playbooks/preview + command)
8. Interactive confirmation (hooks.json)
9. Rich terminal UI (output.sh enhancements)

### Sprint 4: Performance
10. Plan templates (playbooks/templates + templates/)
11. Context caching (cache-context.sh)
12. Parallel execution (builder.yaml)

### Sprint 5: Advanced
13. Analytics dashboard (analytics.sh + command)
14. Learning from corrections (detect-corrections.sh)
15. Rollback system (rollback.sh + command)
16. Multi-task orchestration (project.sh + command)

---

## Verification Checklist

After implementation, verify each feature:

- [ ] Progress bar shows during build
- [ ] `/build:preview` shows plan without executing
- [ ] Errors show contextual fix suggestions
- [ ] Session start prompts for incomplete tasks
- [ ] Confidence score displayed after planning
- [ ] Self-review runs before completion
- [ ] `/trace` shows requirements matrix
- [ ] `/build:interactive` confirms each step
- [ ] Templates accelerate planning
- [ ] Context caches at session start
- [ ] Independent steps run in parallel
- [ ] Analytics shows build history
- [ ] Corrections trigger learning prompts
- [ ] `/rollback` reverts to snapshots
- [ ] `/project` orchestrates multi-task

---

*This plan follows Claude Code best practices: hooks for lifecycle events, skills for reusable methodologies, sub-agents for parallel work, and output styles for formatting.*
