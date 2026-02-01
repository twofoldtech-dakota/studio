---
name: brand-discovery
description: Brand discovery methodology for establishing identity, voice, and messaging
triggers:
  - "brand"
  - "brand discovery"
  - "brand init"
  - "define brand"
  - "brand voice"
  - "messaging"
---

# Brand Discovery Skill: Establishing Your Source of Truth

This skill teaches the **Brand Discovery** methodology for establishing and maintaining a comprehensive brand foundation. It ensures all content and public-facing work speaks with one consistent voice.

## The Core Insight

Most brand inconsistency comes from never documenting the brand properly in the first place. The Brand Discovery methodology addresses this by conducting structured interviews and producing machine-readable brand files.

```
Traditional Approach:           Brand Discovery Approach:
─────────────────────           ───────────────────────

Brand → Tribal Knowledge        Brand → Structured Discovery
         ↓                                    ↓
Content → Inconsistent Voice    Interview → Document → Validate
         ↓                                    ↓
Review → "That doesn't          Content → Embedded Brand Context
          sound like us"                      ↓
                                Review → Consistent Voice
```

## The Five Discovery Phases

Brand Discovery operates in five sequential phases:

### Phase 1: Identity Discovery
**Goal:** Establish who you are at your core

```yaml
identity:
  mission: "What you do daily"
  vision: "Where you're heading"
  values: ["Non-negotiable principles"]
  origin_story: "Why you exist"
  core_purpose: "The gap you fill"
```

**Key Questions:**
- What problem do you solve that others don't?
- What would you refuse to do, even for money?
- Why was this company founded?

### Phase 2: Audience Discovery
**Goal:** Define who you serve and who you don't

```yaml
audiences:
  primary:
    title: "CTO / VP Engineering"
    company_size: "50-500 employees"
    pain_points: ["Technical debt", "Scaling challenges"]
    triggers: ["Failed project", "Key departure"]
    watering_holes: ["Hacker News", "InfoQ"]
  anti_audience:
    - "Startups with no budget"
    - "Companies wanting staff augmentation only"
```

**Key Questions:**
- Who is your ideal customer?
- What keeps them up at night?
- Who is NOT a good fit?

### Phase 3: Voice Discovery
**Goal:** Define how you sound

```yaml
voice:
  personality:
    - "Confident, not arrogant"
    - "Technical, not jargon-heavy"
    - "Direct, not blunt"

  tone_spectrum:
    formality: 3  # 1=casual, 5=formal
    humor: 2      # 1=serious, 5=playful
    technicality: 4  # 1=accessible, 5=expert

  vocabulary:
    use: ["architect", "systems", "custom-built"]
    avoid: ["leverage", "synergy", "disruption"]
```

**Key Questions:**
- If your brand were a person, how would they sound?
- What words do you always use?
- What words should you never use?

### Phase 4: Positioning Discovery
**Goal:** Define your place in the market

```yaml
positioning:
  category: "Elite software consultancy"
  one_liner: "We build what others can't"

  differentiation:
    primary: "Platform-agnostic custom development"
    proof: "We've built on Sitecore, Next.js, and custom stacks"

  competitors:
    - name: "Accenture"
      their_strength: "Scale and brand recognition"
      our_advantage: "Speed and technical depth"
```

**Key Questions:**
- What's your unfair advantage?
- Why do customers choose you over alternatives?
- What category do you compete in?

### Phase 5: Messaging Discovery
**Goal:** Define what you say

```yaml
messaging:
  value_propositions:
    - headline: "Custom software that scales"
      proof: "We've built systems handling 10M+ users"

  objection_responses:
    "too_expensive":
      reframe: "What's the cost of the wrong solution?"
      proof: "Our builds have 3x longer lifespan than agency work"

  cta:
    primary: "Let's spec this out"
    low_commitment: "See our architecture approach"
```

**Key Questions:**
- What are the top 3 benefits you deliver?
- What's the #1 objection you face?
- What action do you want people to take?

## The Discovery Interview Process

### Before the Interview

1. **Review existing materials:**
   - Website copy
   - Past blog posts
   - Sales decks
   - Customer testimonials

2. **Identify gaps:**
   - What's inconsistent?
   - What's missing?
   - What's outdated?

### During the Interview

1. **Follow the phase order** - Each phase builds on the previous
2. **Push past platitudes** - "Quality" needs specifics
3. **Capture exact language** - Their natural phrasing is gold
4. **Ask for examples** - Stories reveal more than statements
5. **Note contradictions** - These are worth exploring

### After the Interview

1. **Structure the output** - Convert to YAML files
2. **Validate with examples** - Test against real content
3. **Identify gaps** - What still needs definition?
4. **Create templates** - Based on voice and messaging

## Output File Structures

### identity.yaml

```yaml
# Brand Identity - Source of Truth
# Generated by Brand Discovery on [date]

company:
  name: "Twofold"
  legal_name: "Twofold Technologies LLC"
  founded: 2020
  headquarters: "Remote-first"

mission: |
  We build custom software solutions that enterprise teams
  can't build themselves and agencies won't build right.

vision: |
  To be the technical partner CTOs call when the project
  is too important to risk on the wrong team.

values:
  - name: "Technical Excellence"
    description: "We don't cut corners on architecture"
    behaviors:
      - "Code review everything"
      - "Document decisions"
      - "Test thoroughly"

  - name: "Radical Honesty"
    description: "We tell clients what they need to hear"
    behaviors:
      - "Push back on bad requirements"
      - "Surface risks early"
      - "Admit when we don't know"

origin_story: |
  Founded by engineers who were tired of watching agencies
  deliver mediocre solutions to complex problems. We started
  Twofold to prove that consultancy could mean technical
  excellence, not just warm bodies.

positioning:
  category: "Elite software consultancy"
  tagline: "We build what others can't"

  one_liner: |
    Twofold is an elite software consultancy that builds
    custom solutions when off-the-shelf doesn't cut it.

  elevator_pitch: |
    We're the team CTOs call when they need custom software
    built right the first time. Unlike agencies that staff
    projects with junior developers, we bring senior architects
    who've built systems at scale. We combine enterprise
    stability with modern speed.
```

### voice.yaml

```yaml
# Brand Voice - Source of Truth
# Generated by Brand Discovery on [date]

personality:
  primary_traits:
    - trait: "Confident"
      not: "Arrogant"
      example: "We've solved this before" vs "We're the best"

    - trait: "Technical"
      not: "Jargon-heavy"
      example: "Event-driven architecture" vs "Synergistic paradigm shift"

    - trait: "Direct"
      not: "Blunt"
      example: "This approach has risks" vs "This is a bad idea"

tone_spectrum:
  # Scale: 1-5 where 1 is left, 5 is right
  formal_casual: 2          # Lean casual but professional
  serious_playful: 2        # Mostly serious, occasional wit
  technical_accessible: 4   # Technical audience, don't dumb down
  reserved_bold: 4          # Make strong claims, back them up
  traditional_innovative: 4 # Modern approach, proven methods

writing_principles:
  - principle: "Problem-first"
    description: "Start with the business friction, not the solution"
    example: "You need X, but standard tools only give you Y"

  - principle: "Architectural authority"
    description: "Discuss solutions in terms of systems"
    terms: ["Event-driven", "Composable", "Orchestration"]

  - principle: "The custom edge"
    description: "Emphasize we choose the best tool, not force a platform"
    example: "We're platform-agnostic but opinionated"

  - principle: "Proof over promises"
    description: "Back every claim with evidence"
    example: "We've built systems handling 10M+ requests/day"

vocabulary:
  always_use:
    - word: "architect"
      context: "We architect solutions, not just build them"
    - word: "custom-built"
      context: "Emphasizes bespoke nature"
    - word: "systems"
      context: "We think in systems, not features"

  never_use:
    - word: "leverage"
      reason: "Corporate buzzword, say 'use' instead"
    - word: "synergy"
      reason: "Meaningless, be specific"
    - word: "disruption"
      reason: "Overused, describe the actual change"
    - word: "guru/ninja/rockstar"
      reason: "Unprofessional, say 'expert' or 'specialist'"

industry_terms:
  embrace:
    - "Micro-services"
    - "Event-driven"
    - "Composable architecture"
    - "RAG pipelines"

  use_carefully:
    - term: "AI"
      guidance: "Be specific: 'LLM-powered' or 'ML-based'"
    - term: "Cloud-native"
      guidance: "Only if actually using cloud-native patterns"

  avoid:
    - term: "Blockchain"
      reason: "Unless specifically relevant"
    - term: "Web3"
      reason: "Not our focus area"
```

### audiences/cto-enterprise.yaml

```yaml
# Audience Profile: Enterprise CTO
# Generated by Brand Discovery on [date]

audience:
  id: "cto-enterprise"
  name: "Enterprise CTO / VP Engineering"
  priority: "primary"

demographics:
  titles:
    - "CTO"
    - "VP of Engineering"
    - "Chief Architect"
  company_size: "200-2000 employees"
  industries:
    - "SaaS"
    - "FinTech"
    - "HealthTech"
    - "E-commerce"
  geography: "North America, primarily"

psychographics:
  goals:
    - "Deliver projects on time without burning out team"
    - "Modernize legacy systems without breaking everything"
    - "Find partners who understand enterprise complexity"

  pain_points:
    - "Agencies deliver pretty demos but unmaintainable code"
    - "Internal team is stretched too thin for new initiatives"
    - "Past consultants didn't understand our domain"
    - "Technical debt is slowing everything down"

  fears:
    - "Picking the wrong partner and wasting 6 months"
    - "Being sold a solution that doesn't fit"
    - "Consultants who disappear after go-live"

  aspirations:
    - "Be seen as the leader who modernized the platform"
    - "Build a team that can maintain what's built"
    - "Have systems that scale with the business"

behavior:
  information_sources:
    - "Hacker News"
    - "InfoQ"
    - "ThoughtWorks Technology Radar"
    - "Peer recommendations"

  buying_triggers:
    - "Failed project with another vendor"
    - "Key architect leaving"
    - "Board pressure to modernize"
    - "Acquisition requiring integration"

  decision_process:
    timeline: "2-6 months"
    stakeholders:
      - "CTO (technical decision)"
      - "CFO (budget approval)"
      - "CEO (strategic alignment)"
    evaluation_criteria:
      - "Technical depth of team"
      - "Relevant experience"
      - "Cultural fit"
      - "Pricing model flexibility"

messaging:
  key_message: |
    You don't need another agency. You need a technical partner
    who can architect solutions your team can maintain.

  proof_points:
    - "Our team averages 15+ years experience"
    - "We've rescued 12 failed enterprise projects"
    - "90% of our work comes from referrals"

  objections:
    "Why not use our internal team?":
      response: |
        Your team knows your domain. We bring fresh patterns
        and dedicated focus. Together, we move faster than either alone.

    "We've been burned by consultants before":
      response: |
        So have we, as clients. That's why we structure engagements
        with weekly deliverables and no lock-in. You see progress
        or you walk.

cta:
  primary: "Let's discuss your architecture challenges"
  secondary: "See how we approached a similar project"
```

### messaging/value-propositions.yaml

```yaml
# Value Propositions - Source of Truth
# Generated by Brand Discovery on [date]

primary_value_prop:
  headline: "We build what others can't"
  subhead: "Custom software for complex problems"
  body: |
    When off-the-shelf doesn't fit and agencies keep failing,
    CTOs call Twofold. We combine enterprise experience with
    modern architecture to build systems that scale.
  proof: "50+ custom enterprise builds delivered"

value_pillars:
  - id: "technical-depth"
    headline: "Senior architects, not junior developers"
    description: |
      Every project is led by engineers with 10+ years experience.
      No bait-and-switch with junior resources.
    proof_points:
      - "Average team experience: 15 years"
      - "All architects have built systems at scale"
      - "We've worked at: Google, Amazon, Stripe, Shopify"
    icon: "architect"

  - id: "platform-agnostic"
    headline: "Best tool for the job, not our favorite tool"
    description: |
      We're fluent in enterprise (Sitecore, .NET) and modern
      (Next.js, Vercel). We choose based on your needs.
    proof_points:
      - "Built on 12+ different platforms"
      - "Migrated clients off platforms we originally recommended"
      - "No vendor partnerships influencing recommendations"
    icon: "tools"

  - id: "ai-native"
    headline: "AI baked in, not bolted on"
    description: |
      Every system we build considers how AI agents and
      automation can reduce operational load.
    proof_points:
      - "Built 8 production RAG systems"
      - "Automated 70% of ops tasks for clients"
      - "Custom AI agents running in production"
    icon: "ai"

differentiators:
  vs_agencies:
    them: "Staff projects with available resources"
    us: "Assign based on technical fit"
    proof: "We turn down projects where we're not the best fit"

  vs_big_consultancies:
    them: "Process-heavy, slow to start"
    us: "Shipping code in week one"
    proof: "Average time to first deploy: 5 days"

  vs_offshore:
    them: "Lower cost, higher risk"
    us: "Higher investment, lower total cost of ownership"
    proof: "Our builds have 3x longer lifespan before major refactor"

transformation_statement: |
  From: Struggling with failed projects and technical debt
  To: Confident in your platform with a team that can maintain it
  Through: Partnership with architects who've solved this before
```

### messaging/objections.yaml

```yaml
# Objection Handling - Source of Truth
# Generated by Brand Discovery on [date]

objections:
  - id: "too-expensive"
    trigger_phrases:
      - "Your rates are higher than other consultancies"
      - "We can get this done cheaper offshore"
      - "That's over our budget"

    reframe: |
      What's the cost of the wrong solution? Our rates reflect
      senior engineers who get it right the first time.

    response: |
      We're not the cheapest option, and we're not trying to be.
      Our clients come to us after cheaper options failed.

      Consider: a $200k project that ships in 3 months and runs
      for 5 years vs a $100k project that takes 6 months and
      needs rebuilding in 18 months. Which is actually cheaper?

    proof_points:
      - "Average project comes in 15% under budget"
      - "Zero projects have required complete rebuild"
      - "Clients report 40% lower maintenance costs"

    follow_up: "Want to see a cost comparison from a recent project?"

  - id: "build-internally"
    trigger_phrases:
      - "We think we can do this ourselves"
      - "We'd rather build internal capability"
      - "We have developers who could do this"

    reframe: |
      Your team knows your domain better than anyone. The question
      is whether this project is the best use of their time.

    response: |
      Your internal team should absolutely own this long-term.
      The question is: should they spend 6 months building
      something we can deliver in 6 weeks?

      We often work alongside internal teams—we handle the
      heavy architecture lifting, they handle domain logic,
      and we transfer knowledge throughout.

    proof_points:
      - "85% of projects include knowledge transfer"
      - "We've trained 200+ internal developers"
      - "Most clients bring us back for next project"

    follow_up: "How is your team's bandwidth looking for Q2?"

  - id: "bad-experience"
    trigger_phrases:
      - "We've been burned by consultants before"
      - "Last agency was a disaster"
      - "We're hesitant to bring in outside help"

    reframe: |
      We understand. We've been on the client side of failed
      consulting engagements. That experience shapes how we work.

    response: |
      You're right to be cautious. Here's how we're different:

      1. Weekly deliverables—you see working code every week
      2. No lock-in—30-day out clause in every contract
      3. All senior team—the people you meet are the people who build
      4. Fixed-scope options—know the cost before you start

      We'd rather lose a deal than take a project we'll fail.

    proof_points:
      - "Net Promoter Score: 72"
      - "90% of work from referrals"
      - "Published case studies with real client names"

    follow_up: "Want to talk to a recent client about their experience?"

  - id: "not-ready"
    trigger_phrases:
      - "We're not ready to start yet"
      - "Maybe next quarter"
      - "We need to get internal alignment first"

    reframe: |
      Timing matters. Let's make sure you're set up to move
      fast when you are ready.

    response: |
      That makes sense. A few things that help clients move
      faster when they're ready:

      1. Architecture review—we document current state now
      2. Stakeholder alignment—we help build the business case
      3. Proof of concept—small engagement to prove the approach

      Which would be most valuable for your situation?

    proof_points:
      - "Architecture reviews take 2 weeks"
      - "POCs typically run 4-6 weeks"
      - "80% of POCs convert to full projects"

    follow_up: "When is your planning cycle for next year?"
```

## Brand Validation Checklist

Before finalizing brand files, validate:

- [ ] Mission is actionable, not aspirational fluff
- [ ] Values have specific behaviors attached
- [ ] Voice guidelines include concrete examples
- [ ] Audience profiles are specific enough to be useful
- [ ] Vocabulary lists are comprehensive
- [ ] Objection responses are tested in real conversations
- [ ] Proof points are accurate and up-to-date
- [ ] All files parse as valid YAML

## Integration with Content Workflow

The brand files feed directly into content creation:

```
/blog "Topic"
     │
     ▼
┌─────────────────────────────────────────┐
│  Content Writer Agent loads:            │
│                                         │
│  1. brand/identity.yaml                 │
│     → Positioning, mission for framing  │
│                                         │
│  2. brand/voice.yaml                    │
│     → Tone, vocabulary for writing      │
│                                         │
│  3. brand/audiences/[target].yaml       │
│     → Pain points for relevance         │
│                                         │
│  4. brand/messaging/value-props.yaml    │
│     → Key messages to reinforce         │
│                                         │
└─────────────────────────────────────────┘
     │
     ▼
  Content Draft (brand-aligned)
```

## Maintaining the Brand

Brand is not static. Schedule regular reviews:

**Quarterly:**
- Review proof points for accuracy
- Update objection responses based on sales conversations
- Add new vocabulary from successful content

**Annually:**
- Full brand audit
- Audience validation with customer interviews
- Competitive positioning review

---

*"Your brand is what people say about you when you're not in the room. These files ensure they say what you intend." - Brand Discovery Principle*
