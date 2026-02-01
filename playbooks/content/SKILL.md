---
name: content-creation
description: Content creation methodology leveraging brand context for consistent, strategic content
triggers:
  - "content"
  - "blog"
  - "article"
  - "write"
  - "content strategy"
---

# Content Creation Skill: Brand-Aligned Writing

This skill teaches the **Content Creation** methodology for producing strategic, brand-aligned content. It ensures every piece of content reinforces positioning, speaks in the brand voice, and drives toward business goals.

## The Core Insight

Most content fails not from poor writing, but from poor strategy. Content that doesn't know its audience, doesn't align with brand voice, or doesn't serve a business goal is wasted effort. This methodology ensures every piece is strategic.

```
Traditional Approach:           Brand-Aligned Approach:
─────────────────────           ────────────────────────

Topic → Write → Publish         Topic → Strategy → Brand Check
         ↓                                    ↓
"Does this sound right?"        Audience Profile → Pain Point Fit
         ↓                                    ↓
Inconsistent voice              Voice Rules → Consistent Writing
                                              ↓
                                CTA → Business Goal Achieved
```

## The Content Creation Pipeline

### Phase 1: Strategic Diagnosis

Before writing a single word, understand the strategic context.

**1. Topic Analysis**
```yaml
diagnosis:
  topic: "Custom software vs. off-the-shelf"

  content_type:
    type: "thought_leadership"  # vs product, how-to, news, case_study
    goal: "Position as experts who understand the tradeoffs"

  business_objective:
    primary: "Generate qualified leads"
    secondary: "Support sales conversations"
    kpi: "Contact form submissions from organic search"
```

**2. Audience Fit**
```yaml
  audience:
    primary: "cto-enterprise"
    stage: "awareness"  # awareness, consideration, decision

    # Load from brand/audiences/cto-enterprise.yaml
    pain_points_addressed:
      - "Agencies deliver pretty demos but unmaintainable code"
      - "Past consultants didn't understand our domain"

    trigger_event: "Evaluating build vs buy for new initiative"
```

**3. Competitive Angle**
```yaml
  competitive_context:
    what_others_say: "Go with proven platforms"
    our_position: "Choose the right tool, not the popular one"
    differentiation: "We're platform-agnostic but opinionated"
```

### Phase 2: Content Architecture

Structure the content before drafting.

**1. The Problem-First Framework**

Every piece follows this structure:

```
1. THE PROBLEM (Hook)
   └── Start with business friction the reader feels
   └── "You need X, but standard tools only give you Y"

2. WHY IT'S HARD (Empathy)
   └── Acknowledge complexity
   └── Show you understand their world

3. THE APPROACH (Authority)
   └── Present your perspective/methodology
   └── Use systems-level language

4. THE PROOF (Credibility)
   └── Concrete examples, metrics, case references
   └── Show, don't just tell

5. THE PATH FORWARD (CTA)
   └── Clear next step
   └── Match to audience stage
```

**2. Outline Template**

```yaml
outline:
  hook:
    pain_point: "The specific frustration"
    stakes: "What happens if unsolved"

  sections:
    - heading: "The Business Challenge"
      purpose: "Establish shared understanding of problem"
      key_points:
        - "Why this is hard"
        - "Why standard solutions fail"

    - heading: "Our Architectural Approach"
      purpose: "Present methodology with authority"
      key_points:
        - "Systems-level thinking"
        - "Specific technologies/patterns"
        - "Why this approach wins"

    - heading: "Why [Company]?"
      purpose: "Differentiate from alternatives"
      key_points:
        - "What makes us different"
        - "Proof points"

  cta:
    primary: "Let's spec this out"
    secondary: "See related case study"
```

### Phase 3: Voice Application

Apply brand voice consistently throughout.

**1. Load Voice Rules**

From `brand/voice.yaml`:

```yaml
voice_check:
  personality:
    - "Confident, not arrogant"
    - "Technical, not jargon-heavy"
    - "Direct, not blunt"

  tone_settings:
    formality: 2  # Lean casual but professional
    technicality: 4  # Don't dumb down

  vocabulary:
    use: ["architect", "systems", "custom-built"]
    avoid: ["leverage", "synergy", "disruption"]
```

**2. Voice Application Rules**

| Rule | Apply As |
|------|----------|
| Problem-first | Open with friction, not solution |
| Architectural authority | Use systems language |
| The custom edge | Emphasize right-tool-for-job |
| Proof over promises | Back claims with evidence |

**3. Self-Check Questions**

Before finalizing, ask:
- Does this sound like our brand?
- Would [target audience] find this relevant?
- Is every claim backed by proof?
- Is the CTA clear and appropriate?

### Phase 4: SEO & Discoverability

Ensure content can be found.

**1. Keyword Strategy**

```yaml
seo:
  primary_keyword: "custom software development"
  secondary_keywords:
    - "enterprise software consultancy"
    - "build vs buy software"
    - "custom development partner"

  search_intent: "informational"  # informational, commercial, transactional

  target_position: "top 10 for primary keyword"
```

**2. On-Page Optimization**

```yaml
on_page:
  title:
    format: "[Value Prop] | [Brand]"
    length: "50-60 characters"
    keyword_placement: "front-loaded"

  meta_description:
    length: "150-160 characters"
    include: "primary keyword, value prop, CTA"

  headings:
    h1: "One per page, includes primary keyword"
    h2: "Section breaks, include secondary keywords"
    h3: "Subsections as needed"

  internal_links:
    - "Related blog posts"
    - "Service pages"
    - "Case studies"
```

**3. Content Formatting**

```yaml
formatting:
  intro_paragraph: "< 150 words, hook immediately"
  paragraph_length: "2-4 sentences"
  use_subheadings: "Every 200-300 words"
  include:
    - "Bullet points for scanability"
    - "Code blocks for technical content"
    - "Pull quotes for key insights"
```

### Phase 5: Conversion Integration

Connect content to business goals.

**1. CTA Strategy**

```yaml
cta_strategy:
  # Match CTA to audience stage
  awareness:
    cta: "See how we approach [topic]"
    destination: "methodology page"

  consideration:
    cta: "Let's discuss your [problem]"
    destination: "contact form"

  decision:
    cta: "Schedule architecture review"
    destination: "booking page"
```

**2. Lead Capture**

```yaml
lead_capture:
  inline_cta:
    placement: "After key insight section"
    type: "Related resource download"

  exit_intent:
    type: "Newsletter signup"
    value_prop: "Architecture insights monthly"

  bottom_cta:
    type: "Contact form"
    message: "Ready to discuss?"
```

## Content Types & Templates

### Blog Post Template

```mdx
---
title: "[Keyword-Rich, Benefit-Focused Title]"
excerpt: "[150 chars summarizing value]"
date: "YYYY-MM-DD"
author: "[Author]"
tags: ["[Category]", "[Topic]"]
audience: "[audience-id from brand/audiences]"
stage: "[awareness|consideration|decision]"
---

## The Business Challenge

[Start with friction. What's broken? Why do readers care?]

[Acknowledge complexity. Show you understand their world.]

## Our Architectural Approach

[Present your methodology. Use systems language.]

[Include specific technologies, patterns, or frameworks.]

[Explain WHY this approach, not just WHAT.]

## Implementation Considerations

[Practical details. What would this look like?]

[Address common concerns proactively.]

## Why [Company]?

[Differentiation. What makes you the right choice?]

[Proof points. Metrics, case references, credentials.]

---

**Ready to discuss [topic]?** [CTA matching audience stage]
```

### Case Study Template

```mdx
---
title: "[Client] + [Result]: [Brief Description]"
excerpt: "[The transformation achieved]"
date: "YYYY-MM-DD"
client: "[Client name or 'Enterprise SaaS Company']"
industry: "[Industry]"
services: ["[Service 1]", "[Service 2]"]
results:
  - metric: "[Metric]"
    value: "[Value]"
    context: "[What it means]"
---

## The Challenge

[What problem did the client face?]

[Why was it hard? What had they tried?]

## Our Approach

[What methodology did we use?]

[What technologies/patterns?]

[What made this approach right for them?]

## The Solution

[What did we build?]

[Key architectural decisions]

[How it addresses their specific needs]

## The Results

[Quantified outcomes]

[Client quote if available]

[Long-term impact]

## Key Takeaways

[What can readers learn from this?]

[How does it apply to their situation?]

---

**Facing a similar challenge?** [CTA]
```

## Quality Checklist

Before publishing, verify:

### Strategic Alignment
- [ ] Clear business objective defined
- [ ] Target audience identified and loaded
- [ ] Pain points addressed are relevant
- [ ] CTA matches audience stage

### Brand Voice
- [ ] Follows voice personality traits
- [ ] Uses approved vocabulary
- [ ] Avoids banned words/phrases
- [ ] Proof backs every claim

### SEO & Discoverability
- [ ] Primary keyword in title, H1, first paragraph
- [ ] Meta description optimized
- [ ] Internal links included
- [ ] Headings use secondary keywords

### Content Quality
- [ ] Hook in first two sentences
- [ ] Problem-first structure followed
- [ ] Scannable formatting (bullets, subheads)
- [ ] No fluff paragraphs

### Conversion
- [ ] Primary CTA clear and visible
- [ ] CTA matches audience stage
- [ ] Lead capture opportunity included

## Integration with Studio Workflow

Content creation integrates with the broader workflow:

```
/brand:init  →  Establishes brand context
     │
     ▼
/blog "topic"  →  Content Writer Agent
     │
     ├── Loads brand/identity.yaml
     ├── Loads brand/voice.yaml
     ├── Loads brand/audiences/[target].yaml
     └── Loads brand/messaging/*.yaml
     │
     ▼
Diagnose → Outline → Draft → Verify
     │
     ▼
Output: Brand-aligned content
```

## Content Calendar Integration

For ongoing content strategy:

```yaml
content_calendar:
  cadence: "2 posts per week"

  content_mix:
    thought_leadership: 40%
    how_to_guides: 30%
    case_studies: 20%
    news_commentary: 10%

  audience_rotation:
    week_1: "cto-enterprise"
    week_2: "technical-founder"

  funnel_coverage:
    awareness: 50%
    consideration: 35%
    decision: 15%
```

---

*"Content without strategy is just noise. Strategy without brand is just tactics. This methodology delivers both." - Content Creation Principle*
