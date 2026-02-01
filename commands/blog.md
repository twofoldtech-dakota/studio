---
name: blog
description: Create strategic, brand-aligned blog content through guided workflow
arguments:
  - name: topic
    description: The topic or title for the blog post
    required: false
  - name: subcommand
    description: "Optional subcommand: outline, audit, series, ideas"
    required: false
triggers:
  - "/blog"
  - "/blog:outline"
  - "/blog:audit"
  - "/blog:series"
  - "/blog:ideas"
---

# STUDIO Blog Command

You are initiating a **STUDIO Blog** workflow - a strategic content creation process that produces brand-aligned blog posts through diagnosis, drafting, and verification.

## Terminal Output

**IMPORTANT**: Use the output.sh script for all formatted terminal output.

```bash
# Display headers
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" header content

# Display phase transitions
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" phase content

# Display agent messages
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" agent writer "Loading brand context..."
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" agent writer "Diagnosing content strategy..."

# Display status messages
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" status success "Brand context loaded"
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" status info "Drafting section..."
```

## Prerequisites

Before running `/blog`, ensure brand context exists:

```
brand/
├── identity.yaml      # Required - positioning and mission
├── voice.yaml         # Required - tone and vocabulary
├── audiences/         # Required - at least one audience
│   └── *.yaml
└── messaging/         # Recommended - value props and objections
    └── *.yaml
```

If brand files don't exist, run `/brand:init` first.

## Command Variants

### `/blog "topic"`
Create a full blog post on the specified topic.

**Flow:**
1. Load brand context
2. Strategic diagnosis (audience, goal, angle)
3. Content architecture (outline)
4. Draft with voice application
5. SEO optimization
6. Verification and output

### `/blog:outline "topic"`
Create just the outline without full drafting.

**Output:**
- Strategic diagnosis
- Problem-first structure
- Section summaries
- Recommended CTAs

### `/blog:audit "url or file"`
Audit existing content for brand alignment.

**Checks:**
- Voice consistency
- Vocabulary compliance
- Proof point presence
- CTA appropriateness
- SEO optimization

### `/blog:series "theme"`
Plan a content series around a theme.

**Output:**
- 4-6 interconnected post ideas
- Audience stage coverage
- Internal linking strategy
- Publication sequence

### `/blog:ideas`
Generate blog post ideas based on brand positioning.

**Output:**
- Ideas mapped to audiences
- Ideas mapped to funnel stages
- Competitive differentiation opportunities
- Trending topic intersections

## Workflow Phases

### Phase 1: BRAND LOAD (Content Writer)

Load brand context to ensure consistency:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" agent writer "Loading brand context..."
```

**Files Loaded:**
- `brand/identity.yaml` → Positioning for framing
- `brand/voice.yaml` → Tone and vocabulary rules
- `brand/audiences/[target].yaml` → Pain points for relevance
- `brand/messaging/value-propositions.yaml` → Key messages
- `brand/messaging/objections.yaml` → Concerns to address

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" status success "Brand: [company name]"
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" status success "Voice: [personality summary]"
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" status success "Audiences: [n] profiles loaded"
```

### Phase 2: STRATEGIC DIAGNOSIS (Content Writer)

Analyze the topic and determine strategy:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" agent writer "Diagnosing content strategy..."
```

**Diagnosis Questions:**

1. **Content Type**
   - Thought leadership (positioning)
   - How-to guide (utility)
   - Case study (proof)
   - News/commentary (relevance)

2. **Business Objective**
   - Lead generation
   - Sales enablement
   - SEO/organic traffic
   - Thought leadership

3. **Target Audience**
   - Which audience profile?
   - What funnel stage?
   - Which pain points?

4. **Competitive Angle**
   - What do others say about this?
   - What's our unique perspective?
   - How do we differentiate?

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" status info "Type: Thought Leadership"
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" status info "Goal: Lead Generation"
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" status info "Audience: CTO-Enterprise (Awareness)"
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" status info "Angle: Platform-agnostic expertise"
```

### Phase 3: CONTENT ARCHITECTURE (Content Writer)

Structure content using problem-first framework:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" agent writer "Architecting content structure..."
```

**Standard Structure:**

```
┌─────────────────────────────────────────────────┐
│  1. THE HOOK                                    │
│     Pain point + stakes                         │
│     "Your last three agency projects failed..." │
└─────────────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────┐
│  2. THE BUSINESS CHALLENGE                      │
│     Why this is hard                            │
│     Why standard solutions fail                 │
└─────────────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────┐
│  3. OUR ARCHITECTURAL APPROACH                  │
│     Methodology with systems language           │
│     Specific technologies/patterns              │
└─────────────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────┐
│  4. WHY [COMPANY]?                              │
│     Differentiation                             │
│     Proof points                                │
└─────────────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────┐
│  5. CTA                                         │
│     Matched to audience stage                   │
└─────────────────────────────────────────────────┘
```

### Phase 4: DRAFTING (Content Writer)

Write content with voice rules applied:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" agent writer "Drafting content..."
```

**Voice Application:**

| Rule | Application |
|------|-------------|
| Confident, not arrogant | "We've solved this before" not "We're the best" |
| Technical, not jargon | "Event-driven" not "synergistic paradigm" |
| Direct, not blunt | "This has risks" not "This is a bad idea" |
| Problem-first | Lead with pain, not solution |
| Proof over promises | Back every claim |

**Vocabulary Check:**
- ✓ Use: architect, systems, custom-built
- ✗ Avoid: leverage, synergy, disruption

### Phase 5: OPTIMIZATION (Content Writer)

Optimize for SEO and conversion:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" agent writer "Optimizing content..."
```

**SEO Checklist:**
- [ ] Primary keyword in title, H1, first paragraph
- [ ] Secondary keywords in H2 headings
- [ ] Meta description (150-160 chars)
- [ ] Internal links to related content

**Formatting Checklist:**
- [ ] Hook in first two sentences
- [ ] Paragraphs 2-4 sentences max
- [ ] Subheadings every 200-300 words
- [ ] Bullet points for key lists

**Conversion Checklist:**
- [ ] CTA matches audience stage
- [ ] CTA is specific and clear
- [ ] Secondary engagement option

### Phase 6: VERIFICATION (Content Writer)

Final quality and brand check:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" agent writer "Verifying content quality..."
```

**Brand Alignment:**
- [ ] Sounds like brand personality
- [ ] Uses approved vocabulary only
- [ ] No banned words/phrases
- [ ] Every claim has proof

**Strategic Alignment:**
- [ ] Serves stated business objective
- [ ] Addresses audience pain points
- [ ] Differentiates from competitors

**Quality Standards:**
- [ ] No fluff paragraphs
- [ ] No unsupported claims
- [ ] Clean grammar/spelling

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" status success "✓ Brand alignment: PASS"
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" status success "✓ Strategic alignment: PASS"
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" status success "✓ Quality standards: PASS"
"${CLAUDE_PLUGIN_ROOT}/scripts/output.sh" banner complete
```

## Output Format

Blog posts are output as MDX:

```mdx
---
title: "[Strategic Title Focusing on the Solution]"
excerpt: "How we architect custom solutions for [Topic] when off-the-shelf software isn't enough."
date: "YYYY-MM-DD"
author: "[Author from brand/identity.yaml]"
tags: ["Engineering", "Architecture", "Custom Software"]
audience: "[audience-id]"
stage: "[awareness|consideration|decision]"
seo:
  primary_keyword: "[keyword]"
  secondary_keywords: ["[kw1]", "[kw2]"]
  meta_description: "[150-160 char description]"
---

## The Business Challenge

[Why is this hard? Why does standard software fail here?]

## Our Architectural Approach

[Deep dive into methodology using systems language]
[Mention specific technologies, patterns, frameworks]

## Why [Company]?

[Differentiation + proof points]

---

**[CTA matching audience stage]**
```

## File Output Location

Blog posts are saved to:

```
content/
└── blog/
    └── YYYY-MM-DD-[slug].mdx
```

## Example Session

```
User: /blog "Custom software vs off-the-shelf: How to decide"

Writer: Loading brand context...
        ✓ Identity: Twofold - Elite software consultancy
        ✓ Voice: Confident, technical, direct
        ✓ Audiences: 3 profiles loaded
        ✓ Messaging: Value props and objections loaded

Writer: Strategic Diagnosis
        ─────────────────────
        Type: Thought Leadership
        Goal: Lead Generation (awareness stage content)
        Audience: CTO-Enterprise
        Angle: Platform-agnostic decision framework

        This topic aligns with pain point:
        "Past consultants didn't understand our domain"

        Competitive differentiation:
        Most content pushes toward one answer.
        We'll provide a genuine framework.

Writer: Content Architecture
        ─────────────────────
        1. Hook: The hidden cost of the wrong choice
        2. Challenge: Why this decision is harder than it looks
        3. Framework: Our evaluation methodology
        4. Case examples: When we recommended each path
        5. CTA: "Let's evaluate your situation"

Writer: Drafting...
        ✓ Section 1: Hook (127 words)
        ✓ Section 2: Business Challenge (312 words)
        ✓ Section 3: Architectural Approach (445 words)
        ✓ Section 4: Why Twofold (198 words)
        ✓ CTA section

Writer: Optimization...
        ✓ SEO: Primary keyword in title, H1, intro
        ✓ Formatting: Subheadings, bullets applied
        ✓ Conversion: CTA matched to awareness stage

Writer: Verification...
        ✓ Brand alignment: PASS
        ✓ Strategic alignment: PASS
        ✓ Quality standards: PASS

        ╔═══════════════════════════════════════════╗
        ║          CONTENT COMPLETE                 ║
        ╚═══════════════════════════════════════════╝

        Output: content/blog/2025-01-15-custom-software-vs-off-the-shelf.mdx
        Words: 1,082
        Reading time: ~5 minutes

        Next steps:
        • Review and edit as needed
        • Add images/diagrams
        • Schedule publication
```

## Integration Points

The blog command integrates with:

| Component | Integration |
|-----------|-------------|
| `/brand:init` | Creates brand context blog needs |
| `brand/*.yaml` | Source of truth for voice/messaging |
| `/build` | Technical content can reference docs |
| Quality Gate | Can validate brand consistency |

---

*"Strategic content isn't written. It's architected." - Content Writer*
