# STUDIO Terminal Color Reference

This document defines the terminal colors used throughout STUDIO for consistent, phase-aware terminal output.

**IMPORTANT**: Do NOT use raw ANSI codes in your output. Always use the `output.sh` script which handles colors automatically.

## Using output.sh

The centralized output script handles all terminal formatting:

```bash
# Headers
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" header cast
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" header smith
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" header forgemaster
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" header temperer

# Phase transitions
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" phase blueprinting
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" phase forging
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" phase tempering

# Agent messages
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" agent smith "Analyzing goal..."
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" agent forgemaster "Executing step 1..."
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" agent temperer "Verifying outputs..."
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" agent scribe "Loaded rules..."

# Status messages
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" status success "Step complete"
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" status error "Step failed"
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" status warning "Issue detected"
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" status info "Processing..."
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" status pending "Waiting..."
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" status checkpoint "Checkpoint reached"

# Verdicts
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" verdict STRONG
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" verdict SOUND
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" verdict BRITTLE
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" verdict CRACKED

# Banners
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" banner complete
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" banner failed

# Separators
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" separator blue
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" separator yellow
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" separator cyan
```

## Phase Colors

| Phase | Agent | Color |
|-------|-------|-------|
| **Blueprinting** | The Smith | Blue |
| **Forging** | The Forgemaster | Yellow/Gold |
| **Tempering** | The Temperer | Cyan |
| **Scribe** | The Scribe | Magenta |

## Status Colors

| Status | Color | Usage |
|--------|-------|-------|
| **Success** | Green | Step complete, checks passing |
| **Error** | Red | Step failed, critical issues |
| **Warning** | Yellow | Warnings, replans needed |
| **Info** | Blue | Current action |
| **Pending** | Gray | Waiting or not started |
| **Checkpoint** | Magenta | Checkpoint reached |

## Verdict Colors

| Verdict | Color |
|---------|-------|
| **STRONG** | Green (bold) |
| **SOUND** | Green (bold) |
| **BRITTLE** | Yellow (bold) |
| **CRACKED** | Red (bold) |

## Implementation Notes

1. **Use output.sh**: Never use raw ANSI codes - use the output.sh script
2. **Automatic detection**: output.sh automatically disables colors when not in a TTY
3. **NO_COLOR support**: Respects the NO_COLOR environment variable
4. **Always resets**: output.sh handles color reset automatically

## Technical Reference

For developers maintaining `scripts/output.sh`, here are the ANSI codes used:

| Code | Style/Color |
|------|-------------|
| 0 | Reset |
| 1 | Bold |
| 2 | Dim |
| 30-37 | Standard colors (black, red, green, yellow, blue, magenta, cyan, white) |
| 90-97 | Bright colors |

See `scripts/output.sh` for the complete implementation.
