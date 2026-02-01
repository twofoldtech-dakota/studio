---
name: brand
description: Establish and manage brand identity, voice, and messaging through guided discovery
arguments:
  - name: subcommand
    description: "Action to perform: init, update, audit, export"
    required: false
  - name: target
    description: "Target area: identity, voice, audience, messaging, or 'all'"
    required: false
triggers:
  - "/brand"
  - "/brand:init"
  - "/brand:update"
  - "/brand:audit"
  - "/brand:export"
---

# STUDIO Brand Command

You are initiating a **STUDIO Brand** workflow - a guided discovery process that establishes your brand's source of truth through structured interviews.

## Terminal Output

**IMPORTANT**: Use the output.sh script for all formatted terminal output.

```bash
# Display headers
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" header brand

# Display phase transitions
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" phase discovery

# Display agent messages
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" agent strategist "Starting identity discovery..."

# Display status messages
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" status success "Identity captured"
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" status info "Moving to voice discovery..."
```

## Command Variants

### `/brand` or `/brand:init`
Start fresh brand discovery. Conducts full five-phase interview:
1. Identity Discovery
2. Audience Discovery
3. Voice Discovery
4. Positioning Discovery
5. Messaging Discovery

### `/brand:update [target]`
Update specific brand area. Targets:
- `identity` - Mission, vision, values, positioning
- `voice` - Tone, vocabulary, writing principles
- `audience` - Add or update audience profiles
- `messaging` - Value props, differentiators, objections
- `all` - Full refresh

### `/brand:audit`
Review existing brand files for:
- Completeness (all required fields present)
- Consistency (no contradictions)
- Currency (proof points still accurate)
- Coverage (all audiences defined)

### `/brand:export [format]`
Export brand guide in various formats:
- `md` - Markdown brand guide
- `pdf` - PDF brand book (requires additional tools)
- `json` - Machine-readable format

## Discovery Phases

### Phase 1: IDENTITY (The Brand Strategist)

**Goal:** Establish who you are at your core

**Questions:**
```
CORE PURPOSE
├── What problem does your company solve that others don't?
├── If your company disappeared, what gap would exist?
└── What's the one thing you want people to remember?

MISSION & VISION
├── What is your mission? (What you do daily)
├── What is your vision? (Where you're heading)
└── What would success look like in 5 years?

VALUES
├── What are your non-negotiable principles?
├── What would you refuse to do, even for money?
└── What behaviors do you reward internally?

ORIGIN
├── Why was this company founded?
├── What frustration or opportunity sparked it?
└── How does the founder's background shape the company?
```

**Output:** `brand/identity.yaml`

### Phase 2: AUDIENCE (The Brand Strategist)

**Goal:** Define who you serve and who you don't

**Questions:**
```
PRIMARY AUDIENCE
├── Who is your ideal customer? (Title, company size, industry)
├── What keeps them up at night professionally?
├── What have they tried before that failed?
└── Where do they go for information?

BUYER JOURNEY
├── How do prospects typically find you?
├── What triggers them to look for a solution?
├── Who else is involved in buying decisions?
└── What objections do you hear most often?

ANTI-AUDIENCE
├── Who is NOT a good fit?
├── What projects do you turn down?
└── What red flags indicate a bad-fit prospect?
```

**Output:** `brand/audiences/[audience-name].yaml`

### Phase 3: VOICE (The Brand Strategist)

**Goal:** Define how you sound

**Questions:**
```
PERSONALITY
├── If your brand were a person, describe their personality
├── Pick 3-5 adjectives that capture how you want to sound
└── What adjectives would be wrong for your brand?

TONE SPECTRUM
Where do you fall? (1-5 scale)
├── Formal ←→ Casual
├── Serious ←→ Playful
├── Technical ←→ Accessible
├── Reserved ←→ Bold
└── Traditional ←→ Innovative

VOCABULARY
├── What words or phrases do you always use?
├── What jargon is appropriate for your audience?
├── What words should you never use?
└── Share examples of writing that sounds like you
```

**Output:** `brand/voice.yaml`

### Phase 4: POSITIONING (The Brand Strategist)

**Goal:** Define your place in the market

**Questions:**
```
MARKET POSITION
├── How do you describe what you do in one sentence?
├── What category do you compete in?
└── Are you creating a new category?

COMPETITIVE LANDSCAPE
├── Who are your main competitors?
├── What do competitors do well?
├── What do you do that competitors can't?
└── Why do customers choose you?

PROOF POINTS
├── What results can you prove? (Metrics, case studies)
├── What credentials matter?
├── Who are your most impressive customers?
└── What awards or recognition have you received?
```

**Output:** Updates `brand/identity.yaml` positioning section

### Phase 5: MESSAGING (The Brand Strategist)

**Goal:** Define what you say

**Questions:**
```
VALUE PROPOSITIONS
├── What are the top 3 benefits you deliver?
├── How do you quantify the value you provide?
└── What transformation do customers experience?

OBJECTION HANDLING
├── What's the #1 objection you face?
├── How do you respond to "too expensive"?
├── How do you respond to "we'll build it ourselves"?
└── How do you respond to "we're not ready"?

CALL TO ACTION
├── What's the primary action you want people to take?
├── What's a low-commitment entry point?
└── How do you frame the next step?
```

**Output:** `brand/messaging/value-propositions.yaml`, `brand/messaging/objections.yaml`

## Execution Protocol

```
/brand:init
     │
     ▼
┌─────────────────────────────────────────────┐
│  PHASE 1: IDENTITY DISCOVERY                │
│                                             │
│  Brand Strategist asks:                     │
│  • Core purpose questions                   │
│  • Mission & vision questions               │
│  • Values questions                         │
│  • Origin story questions                   │
│                                             │
│  Output: brand/identity.yaml                │
└─────────────────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────────────┐
│  PHASE 2: AUDIENCE DISCOVERY                │
│                                             │
│  For each audience:                         │
│  • Demographics questions                   │
│  • Pain points questions                    │
│  • Behavior questions                       │
│  • Anti-audience questions                  │
│                                             │
│  Output: brand/audiences/[name].yaml        │
└─────────────────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────────────┐
│  PHASE 3: VOICE DISCOVERY                   │
│                                             │
│  Brand Strategist asks:                     │
│  • Personality questions                    │
│  • Tone spectrum questions                  │
│  • Vocabulary questions                     │
│  • Example content review                   │
│                                             │
│  Output: brand/voice.yaml                   │
└─────────────────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────────────┐
│  PHASE 4: POSITIONING DISCOVERY             │
│                                             │
│  Brand Strategist asks:                     │
│  • Market position questions                │
│  • Competitor analysis questions            │
│  • Differentiation questions                │
│  • Proof points questions                   │
│                                             │
│  Output: Updates brand/identity.yaml        │
└─────────────────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────────────┐
│  PHASE 5: MESSAGING DISCOVERY               │
│                                             │
│  Brand Strategist asks:                     │
│  • Value proposition questions              │
│  • Objection handling questions             │
│  • CTA questions                            │
│                                             │
│  Output: brand/messaging/*.yaml             │
└─────────────────────────────────────────────┘
     │
     ▼
    ✓ BRAND DISCOVERY COMPLETE
```

## File Structure

```
studio/
└── brand/                           # Brand source of truth
    ├── identity.yaml                # Mission, vision, values, positioning
    ├── voice.yaml                   # Tone, vocabulary, principles
    ├── audiences/                   # Audience profiles
    │   ├── cto-enterprise.yaml
    │   ├── technical-founder.yaml
    │   └── developer-lead.yaml
    ├── messaging/                   # Core messaging
    │   ├── value-propositions.yaml
    │   ├── differentiators.yaml
    │   └── objections.yaml
    └── templates/                   # Content templates
        ├── blog-post.mdx
        └── case-study.mdx
```

## Brand States

| State | Description |
|-------|-------------|
| `UNDEFINED` | No brand files exist |
| `PARTIAL` | Some files exist, discovery incomplete |
| `COMPLETE` | All required files present |
| `STALE` | Files exist but haven't been reviewed in 6+ months |

## Integration Points

Brand files are loaded by:

| Component | What it Uses |
|-----------|--------------|
| **Content Writer** | voice.yaml, messaging/*.yaml |
| **Planner** | identity.yaml for context |
| **Builder** | voice.yaml for any UI copy |
| **Blog Command** | All brand files |
| **Quality Gate** | Validates brand consistency |

## Example Session

```
User: /brand:init

Strategist: Starting STUDIO Brand Discovery...
            ✓ Playbook loaded: brand-discovery
            ✓ Team loaded: Brand Strategist

═══════════════════════════════════════════════════
  PHASE 1: IDENTITY DISCOVERY
═══════════════════════════════════════════════════

Strategist: Let's establish who you are at your core.

            CORE PURPOSE
            ─────────────
            What problem does your company solve that
            others don't?

User: We build custom software for enterprises when
      agencies keep failing them and off-the-shelf
      doesn't fit.

Strategist: Got it. You fill the gap between "agency work"
            and "build it yourself."

            What's the ONE thing you want people to
            remember about Twofold?

User: We build what others can't.

Strategist: Strong. That's your positioning anchor.

            MISSION & VISION
            ────────────────
            What is your mission—what you do daily?

User: We partner with CTOs to architect and build custom
      software that their teams can maintain long-term.

[...continues through all phases...]

Strategist: ═══════════════════════════════════════════════════
            BRAND DISCOVERY COMPLETE
            ═══════════════════════════════════════════════════

            Files created:
            ✓ brand/identity.yaml
            ✓ brand/voice.yaml
            ✓ brand/audiences/cto-enterprise.yaml
            ✓ brand/messaging/value-propositions.yaml
            ✓ brand/messaging/objections.yaml

            Your brand source of truth is ready.

            Next steps:
            • /blog "topic" - Create brand-aligned content
            • /brand:audit - Review for consistency
            • /brand:export md - Generate brand guide
```

## Best Practices

1. **Complete all phases** - Partial brand is worse than no brand
2. **Use real examples** - Abstract principles need concrete anchors
3. **Involve stakeholders** - Brand should reflect collective understanding
4. **Review quarterly** - Proof points and messaging evolve
5. **Test with content** - Write something and see if it "sounds right"

---

*"A brand without documentation is just vibes. These files make it actionable." - Brand Strategist*
