---
name: templates
description: Pre-built plan templates for common patterns
disable-model-invocation: false
---

# Plan Templates

Use templates to accelerate planning for common development patterns.

## Overview

Templates provide pre-structured plans for recurring development tasks:
- Skip repetitive requirements gathering
- Consistent step structure across similar tasks
- Only ask domain-specific questions
- Faster time-to-build

## Available Templates

### api-endpoint
REST API endpoint with full CRUD operations.
```
Steps: schema → service → controller → routes → tests
Files: src/schemas/, src/services/, src/controllers/, src/routes/, tests/
```

### react-component
React component with tests and Storybook story.
```
Steps: component → styles → hooks → tests → story
Files: src/components/, tests/, stories/
```

### database-migration
Schema change with rollback support.
```
Steps: migration_up → migration_down → seed → test
Files: migrations/, seeds/
```

### auth-flow
Authentication feature (login, register, password reset).
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

### Command Format

```
/build:template <template-name> <goal>
```

Example:
```
/build:template api-endpoint "Product management for e-commerce"
```

### Process

1. **Load Template**
   ```bash
   cat ${CLAUDE_PLUGIN_ROOT}/templates/<name>.json
   ```

2. **Pre-fill Step Structure**
   Template provides step skeleton with:
   - Step IDs and names
   - File path patterns
   - Common validation commands
   - Dependency structure

3. **Ask Only Domain Questions**
   Skip generic requirements, ask template-specific questions:
   - Entity name
   - Field definitions
   - Which operations needed
   - Special requirements

4. **Complete Plan**
   Fill in template placeholders:
   - `{{entity}}` → actual entity name
   - `{{fields}}` → actual field definitions
   - Micro-actions with real file paths

## Template Format

Templates are JSON files with this structure:

```json
{
  "name": "template-name",
  "description": "What this template creates",
  "version": "1.0.0",

  "steps": [
    {
      "id": "step_1",
      "name": "Step name with {{entity}}",
      "step_type": "schema|service|controller|test",
      "outputs": ["src/path/{{entity}}.ts"],
      "depends_on": [],
      "requires_input": ["entity_name", "fields"]
    }
  ],

  "questions": [
    {
      "id": "entity_name",
      "question": "What entity is this for?",
      "example": "User, Product, Order",
      "required": true
    },
    {
      "id": "fields",
      "question": "What fields should it have?",
      "example": "name: string, price: number",
      "required": true
    }
  ],

  "quality_checks": [
    {"name": "TypeScript compiles", "command": "npx tsc --noEmit"},
    {"name": "Tests pass", "command": "npm test -- --grep {{entity}}"}
  ],

  "memory_rules_suggest": [
    "Consider adding: Use Zod for validation schemas",
    "Consider adding: Include OpenAPI documentation"
  ]
}
```

## Template Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `{{entity}}` | Primary entity name | User, Product |
| `{{entity_lower}}` | Lowercase entity | user, product |
| `{{entity_plural}}` | Plural form | users, products |
| `{{fields}}` | Field definitions | name: string |
| `{{operations}}` | CRUD operations | create, read, update |

## Creating Custom Templates

1. Create file: `templates/my-template.json`
2. Define steps with placeholders
3. Add questions for required inputs
4. Define quality checks
5. Use via `/build:template my-template <goal>`

## Integration with Planner

When using a template:

1. Planner loads template
2. Skips generic requirements phase
3. Asks only template-specific questions
4. Generates plan from template + answers
5. Continues with normal challenge phase

The planner should:
```bash
# Check if template requested
if [[ "$GOAL" == *"template:"* ]]; then
    TEMPLATE_NAME="${GOAL#*template:}"
    TEMPLATE_NAME="${TEMPLATE_NAME%% *}"

    "${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" status info "Using template: $TEMPLATE_NAME"

    # Load template
    cat "${CLAUDE_PLUGIN_ROOT}/templates/${TEMPLATE_NAME}.json"
fi
```

## Benefits

1. **Speed** - Skip 80% of requirements gathering
2. **Consistency** - Same structure across team
3. **Quality** - Pre-defined validation commands
4. **Learning** - Capture best practices in templates
