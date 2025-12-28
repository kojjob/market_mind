# MarketMind: Product Requirements Document (PRD)

**Version:** 1.0.0  
**Last Updated:** December 27, 2025  
**Author:** Kojo  
**Status:** Draft → Ready for Implementation

---

## Executive Summary

MarketMind is an AI-powered marketing automation platform designed specifically for indie makers, solo founders, and micro-SaaS builders who operate multiple applications. Unlike enterprise solutions (HubSpot at $800+/mo) or content-only tools (Jasper, Copy.ai), MarketMind provides a complete AI marketing team at SMB-friendly prices ($29-99/mo).

### Vision Statement

> "Give every solo founder the marketing power of a 10-person team, at the cost of a nice dinner."

### Mission

Democratize sophisticated marketing automation by leveraging agentic AI to handle everything from persona discovery to content creation to lead nurturing—all orchestrated autonomously with human-in-the-loop approval.

---

## Market Opportunity

### Market Size

| Metric | Value | Source |
|--------|-------|--------|
| **TAM** (AI in Marketing, 2030) | $82.2B | MarketsandMarkets |
| **SAM** (Marketing Automation Software) | $47B → $81B by 2030 | Industry Reports |
| **SOM** (AI Agent Marketing for SMBs) | $500M - $2B | Estimated |
| **Agentic AI CAGR** | 43.84% | Fastest growing segment |

### Target Market

**Primary:** Solo founders and indie makers with 1-5 SaaS applications who:
- Cannot afford agencies ($5K-50K/month)
- Don't have time to do marketing themselves
- Need marketing that scales across multiple products
- Are tech-savvy enough to trust AI automation

**Secondary:** Small marketing teams (2-5 people) at early-stage startups who need to 10x their output.

### Competitive Landscape

```
                    COMPREHENSIVE
                         ↑
                         │
    ┌────────────────────┼────────────────────┐
    │                    │                    │
    │  HubSpot          │                    │
    │  Marketo          │    MARKETMIND      │
    │  Pardot           │    ★ TARGET        │
    │                    │                    │
    │  ($800+/mo)       │    ($29-99/mo)     │
LOW ├────────────────────┼────────────────────┤ HIGH
PRICE│                    │                    │ PRICE
    │                    │                    │
    │  Copy.ai          │    Jasper          │
    │  Writesonic       │    (going upmarket)│
    │  ($20-49/mo)      │    ($59-99/mo)     │
    │                    │                    │
    │  [Content Only]   │    [Content Focus] │
    └────────────────────┼────────────────────┘
                         │
                         ↓
                    CONTENT ONLY
```

### Key Differentiators

1. **Multi-Product Intelligence** - Manages portfolio of SaaS apps with cross-sell optimization
2. **Persona-to-Product Matching** - AI discovers ideal customers, not just writes content
3. **Autonomous Agents** - Full GTM execution, not just content generation
4. **Cost Structure** - Elixir + Gemini Flash = profitable at $29/mo
5. **Dogfooding** - Built by a founder, tested on real products (WellnessConnect, Linklysis)

---

## Product Architecture

### Core Philosophy

MarketMind follows **Domain-Driven Design (DDD)** with clear bounded contexts and an **agentic architecture** where AI agents are dynamic, skill-equipped workers that can be assigned to any project.

### Bounded Contexts

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        MARKETMIND BOUNDED CONTEXTS                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1. PRODUCT INTELLIGENCE          2. PERSONA MANAGEMENT                    │
│     ─────────────────────            ────────────────────                  │
│     • App registration              • Persona discovery                    │
│     • URL analysis                  • ICP generation                       │
│     • Value prop extraction         • Pain point mapping                   │
│     • Feature cataloging            • Channel preferences                  │
│     • Competitor tracking           • Persona simulation                   │
│                                                                             │
│  3. CONTENT GENERATION            4. CAMPAIGN ORCHESTRATION                │
│     ─────────────────────            ──────────────────────                │
│     • Blog writing (SEO/AEO)        • Email sequences                      │
│     • Social posts                  • Drip campaigns                       │
│     • Email copy                    • Multi-channel sync                   │
│     • Ad copy                       • A/B testing                          │
│     • Content atomization           • Send scheduling                      │
│                                                                             │
│  5. LEAD MANAGEMENT               6. ANALYTICS & INSIGHTS                  │
│     ─────────────────────            ─────────────────────                 │
│     • Lead capture                  • Content performance                  │
│     • Lead scoring                  • Conversion tracking                  │
│     • Nurture assignment            • Churn prediction                     │
│     • CRM sync                      • ROI analysis                         │
│     • Handoff triggers              • Agent performance                    │
│                                                                             │
│  7. AGENT ORCHESTRATION (NEW)                                              │
│     ─────────────────────────                                              │
│     • Dynamic skill system                                                 │
│     • Project-agnostic agents                                              │
│     • Task queue management                                                │
│     • LLM provider routing                                                 │
│     • Execution logging                                                    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Agent Architecture

MarketMind uses a **dynamic agent system** where agents are generic workers equipped with skills at runtime:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         DYNAMIC AGENT SYSTEM                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  SKILL REGISTRY                                                             │
│  ══════════════                                                             │
│  • Skills are versioned, reusable prompt templates                         │
│  • Each skill defines: inputs, outputs, required context, LLM config       │
│  • Skills can be A/B tested with traffic allocation                        │
│  • Performance tracked per skill per project                               │
│                                                                             │
│  AGENT POOL                                                                 │
│  ══════════════                                                             │
│  • Agents are GenServer processes (Elixir)                                 │
│  • Agents can be assigned to any project dynamically                       │
│  • Agents equip skills on-demand                                           │
│  • Project context injected at runtime                                     │
│                                                                             │
│  ORCHESTRATOR                                                               │
│  ══════════════                                                             │
│  • Routes tasks to available agents                                        │
│  • Handles agent checkout/checkin                                          │
│  • Manages task queue with priorities                                      │
│  • Broadcasts results via PubSub                                           │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Agent Types & Autonomy Levels

| Agent | Primary Skills | Autonomy | Approval Required |
|-------|---------------|----------|-------------------|
| **Product Analyzer** | product_analysis, feature_extraction | High | No |
| **Persona Builder** | persona_discovery, icp_generation | High | Optional |
| **Content Writer** | seo_blog, email_copy, social_posts | Medium | Yes (content) |
| **Content Atomizer** | content_repurposing, format_conversion | Medium | Yes (first time) |
| **Campaign Manager** | sequence_builder, send_scheduler | Low | Yes (campaigns) |
| **Lead Scorer** | lead_analysis, score_calculation | High | No |
| **Churn Prophet** | behavior_analysis, churn_prediction | High | No |

---

## Feature Specifications

### Phase 1: MVP (Weeks 1-8)

#### F1.1: Project Management

**Description:** Users can register and manage multiple SaaS applications.

**User Stories:**
- As a founder, I can add my SaaS app by URL so the system can analyze it
- As a founder, I can manage multiple apps from a single dashboard
- As a founder, I can see analysis status and results for each app

**Requirements:**
| ID | Requirement | Priority |
|----|-------------|----------|
| F1.1.1 | Add project via URL | P0 |
| F1.1.2 | Auto-extract product name, description, features | P0 |
| F1.1.3 | Store and display value propositions | P0 |
| F1.1.4 | Project switching in UI | P0 |
| F1.1.5 | Project settings (brand voice, tone) | P1 |
| F1.1.6 | Manual override of extracted data | P1 |

**Acceptance Criteria:**
- [ ] User can add a project by entering a valid URL
- [ ] System extracts product info within 60 seconds
- [ ] Extracted data is editable
- [ ] User can switch between projects in < 2 clicks

---

#### F1.2: Product Analyzer Agent

**Description:** AI agent that analyzes a SaaS product URL and extracts marketing-relevant information.

**User Stories:**
- As a founder, I want the system to understand my product automatically
- As a founder, I want to see what value props the AI identified

**Requirements:**
| ID | Requirement | Priority |
|----|-------------|----------|
| F1.2.1 | Fetch and parse website content | P0 |
| F1.2.2 | Extract product name, tagline | P0 |
| F1.2.3 | Identify 3-5 value propositions | P0 |
| F1.2.4 | List key features | P0 |
| F1.2.5 | Detect pricing model | P1 |
| F1.2.6 | Identify target industries | P1 |
| F1.2.7 | Analyze landing page effectiveness | P2 |

**Technical Notes:**
- Use Req for HTTP fetching
- Use Gemini Flash for analysis
- Cache results (24-hour TTL)
- Store structured JSON in PostgreSQL

---

#### F1.3: Persona Builder Agent

**Description:** AI agent that generates Ideal Customer Profiles (ICPs) based on product analysis.

**User Stories:**
- As a founder, I want to understand who my ideal customers are
- As a founder, I want personas with actionable marketing insights

**Requirements:**
| ID | Requirement | Priority |
|----|-------------|----------|
| F1.3.1 | Generate 2-4 personas per product | P0 |
| F1.3.2 | Include demographics, goals, pain points | P0 |
| F1.3.3 | Identify preferred channels | P0 |
| F1.3.4 | Generate relevant keywords per persona | P1 |
| F1.3.5 | Mark one persona as primary | P1 |
| F1.3.6 | Allow manual persona editing | P1 |
| F1.3.7 | Persona comparison view | P2 |

**Output Schema:**
```json
{
  "name": "The Overwhelmed Indie Maker",
  "role": "Solo Founder / Technical CEO",
  "demographics": {
    "age_range": "28-45",
    "location": "US, EU, Remote-first",
    "income": "$50K-200K"
  },
  "goals": [
    "Ship product updates faster",
    "Grow MRR without hiring",
    "Reduce time on non-core tasks"
  ],
  "pain_points": [
    "Marketing takes too much time",
    "Can't afford agencies",
    "Content creation is overwhelming"
  ],
  "objections": [
    "Will AI content sound generic?",
    "How do I maintain brand voice?"
  ],
  "channels": ["Twitter/X", "Indie Hackers", "HN", "Reddit"],
  "keywords": ["saas marketing", "solo founder tips", "bootstrap marketing"]
}
```

---

#### F1.4: SEO/AEO Content Writer Agent

**Description:** AI agent that writes search-optimized blog content.

**User Stories:**
- As a founder, I want blog posts optimized for both Google and AI search
- As a founder, I want to approve content before publishing

**Requirements:**
| ID | Requirement | Priority |
|----|-------------|----------|
| F1.4.1 | Generate SEO-optimized blog posts | P0 |
| F1.4.2 | Target specific keywords | P0 |
| F1.4.3 | Match brand voice settings | P0 |
| F1.4.4 | Include meta title and description | P0 |
| F1.4.5 | AEO formatting (FAQ sections, summaries) | P1 |
| F1.4.6 | Suggested internal links | P1 |
| F1.4.7 | Readability scoring | P2 |
| F1.4.8 | Plagiarism check | P2 |

**AEO (Answer Engine Optimization) Specifics:**
- Include TL;DR at top
- Structure with clear H2/H3 hierarchy
- Add FAQ section (structured data ready)
- Use concise, quotable sentences
- Optimize for featured snippets

---

#### F1.5: Approval Workflow

**Description:** Human-in-the-loop system for reviewing AI-generated content.

**User Stories:**
- As a founder, I want to review content before it goes live
- As a founder, I want to request revisions easily

**Requirements:**
| ID | Requirement | Priority |
|----|-------------|----------|
| F1.5.1 | Pending approval queue | P0 |
| F1.5.2 | Approve/Reject actions | P0 |
| F1.5.3 | Request revision with feedback | P0 |
| F1.5.4 | Side-by-side diff for revisions | P1 |
| F1.5.5 | Batch approval | P1 |
| F1.5.6 | Approval notifications | P1 |
| F1.5.7 | Auto-approve rules (optional) | P2 |

---

#### F1.6: Dashboard & Analytics

**Description:** Central hub for viewing marketing performance across all projects.

**User Stories:**
- As a founder, I want to see all my marketing activity at a glance
- As a founder, I want to track content creation velocity

**Requirements:**
| ID | Requirement | Priority |
|----|-------------|----------|
| F1.6.1 | Project overview cards | P0 |
| F1.6.2 | Content created count | P0 |
| F1.6.3 | Pending approvals indicator | P0 |
| F1.6.4 | Recent activity feed | P1 |
| F1.6.5 | Token/cost usage display | P1 |
| F1.6.6 | Agent status indicators | P2 |

---

### Phase 2: Core Features (Weeks 9-16)

#### F2.1: Content Atomizer Agent

**Description:** Transforms one piece of content into multiple formats.

**Transformation Matrix:**
```
INPUT: 1 Blog Post (1500 words)
                ↓
        ┌───────┴───────┐
        ↓               ↓
    ┌───────────────────────────────────────┐
    │  OUTPUT: 10-15 Assets                 │
    │  • 3-5 Twitter/X threads              │
    │  • 2-3 LinkedIn posts                 │
    │  • 1 Newsletter section               │
    │  • 5 Quote graphics (text for)        │
    │  • 1 Reddit post                      │
    │  • 2-3 Indie Hackers comments         │
    │  • 1 Summary for email                │
    └───────────────────────────────────────┘
```

---

#### F2.2: Email Sequence Builder

**Description:** Create and manage email nurture sequences.

**Requirements:**
| ID | Requirement | Priority |
|----|-------------|----------|
| F2.2.1 | Sequence templates (welcome, nurture, win-back) | P0 |
| F2.2.2 | AI-generated email content | P0 |
| F2.2.3 | Visual sequence builder | P1 |
| F2.2.4 | SendGrid integration | P0 |
| F2.2.5 | Delay/trigger configuration | P1 |
| F2.2.6 | A/B test subjects | P2 |

---

#### F2.3: Skill Management System

**Description:** Create, version, and manage AI skills.

**Requirements:**
| ID | Requirement | Priority |
|----|-------------|----------|
| F2.3.1 | View all skills in library | P0 |
| F2.3.2 | Create custom skills | P1 |
| F2.3.3 | Skill versioning | P1 |
| F2.3.4 | A/B test skill versions | P2 |
| F2.3.5 | Skill performance analytics | P1 |
| F2.3.6 | Import/export skills | P2 |

---

### Phase 3: Disruptive Features (Weeks 17-24)

#### F3.1: Persona Simulation Engine

**Description:** AI focus groups that test messaging before launch.

**How It Works:**
1. Select a persona
2. Present marketing copy/messaging
3. AI simulates persona's reaction
4. Get feedback, objections, suggestions
5. Iterate before real audience exposure

**Use Cases:**
- Test landing page headlines
- Evaluate email subject lines
- Validate value proposition messaging
- Predict objection patterns

---

#### F3.2: Churn Prophecy Engine

**Description:** Predict which users are likely to churn based on behavior patterns.

**Signals Analyzed:**
- Login frequency trends
- Feature usage patterns
- Support ticket sentiment
- Payment history
- Engagement with emails

**Output:**
- Churn risk score (0-100)
- Risk factors identified
- Suggested intervention (win-back email, feature highlight, etc.)
- Triggered nurture sequence

---

#### F3.3: Competitor Radar

**Description:** Continuous monitoring of competitor activities.

**Tracked:**
- Website changes
- Pricing updates
- New feature launches
- Content publication
- Social media activity

**Alerts:**
- "Competitor X just launched feature Y"
- "Competitor X changed pricing"
- "Competitor X published blog about Z"

---

### Phase 4: Advanced Integrations (Weeks 25-32)

#### F4.1: Claude SDK Integration

**Description:** Use Claude for complex reasoning tasks via tool use.

**Capabilities:**
- Function calling for external data
- Multi-step reasoning for campaign planning
- Tool use for web research
- MCP server for external integrations

---

#### F4.2: CRM Integrations

**Description:** Sync leads with popular CRM systems.

**Supported:**
- HubSpot (via API)
- Pipedrive
- Notion databases
- Custom webhooks

---

#### F4.3: Analytics Integrations

**Description:** Pull performance data for AI optimization.

**Supported:**
- Google Analytics 4
- Plausible
- PostHog
- Custom events via API

---

## Technical Specifications

### Technology Stack

| Layer | Technology | Rationale |
|-------|------------|-----------|
| **Backend** | Elixir 1.16+ / Phoenix 1.7+ | BEAM concurrency, fault tolerance, LiveView |
| **Database** | PostgreSQL 16 | JSONB for flexible schemas, reliability |
| **Background Jobs** | Oban | Robust job processing, scheduling, retries |
| **Real-time** | Phoenix LiveView + PubSub | No separate frontend, instant updates |
| **Cache** | ETS + Redis (optional) | In-memory speed, distributed option |
| **Primary LLM** | Gemini Flash | Lowest cost ($0.075/1M tokens) |
| **Complex Tasks** | Claude Sonnet | Tool use, complex reasoning |
| **Email** | SendGrid | Free tier, deliverability |
| **Hosting** | Fly.io | Global edge, easy deploys |
| **CSS** | TailwindCSS | Utility-first, rapid development |

### Cost Structure

| Service | Monthly Cost | Notes |
|---------|-------------|-------|
| Fly.io (2 shared-1x) | $10-15 | 512MB RAM each |
| PostgreSQL (Fly) | $0-7 | Free tier initially |
| Gemini Flash | $5-15 | ~200K tokens/day |
| SendGrid | $0 | Free tier (100 emails/day) |
| Domain + misc | $5-10 | |
| **Total** | **$20-47/mo** | |

### Break-Even Analysis

- At $29/mo tier: **2 customers** = break-even
- At $79/mo tier: **1 customer** = break-even with profit

### Database Schema (Key Tables)

```sql
-- Core tables
projects, personas, skills, agents, tasks

-- Content tables  
content_pieces, content_versions, approval_queue

-- Campaign tables
email_sequences, sequence_steps, campaign_sends

-- Analytics tables
skill_executions, agent_performance, content_metrics

-- User tables
users, accounts, subscriptions
```

---

## Non-Functional Requirements

### Performance

| Metric | Target |
|--------|--------|
| Dashboard load time | < 1 second |
| Content generation | < 30 seconds |
| Agent response time | < 5 seconds |
| API response (95th percentile) | < 200ms |

### Reliability

| Metric | Target |
|--------|--------|
| Uptime | 99.9% |
| Data durability | 99.999% |
| Job retry success | 99% within 3 attempts |

### Security

- [ ] SSL/TLS everywhere
- [ ] API key encryption at rest
- [ ] Rate limiting per user
- [ ] Input sanitization
- [ ] OWASP Top 10 compliance
- [ ] SOC 2 readiness (future)

### Scalability

- Designed for 10,000 users initially
- Horizontal scaling via Fly.io machines
- Stateless agents (can add more workers)
- Database connection pooling

---

## Pricing Strategy

### Tiers

| Tier | Price | Apps | Content/mo | Features |
|------|-------|------|------------|----------|
| **Free** | $0 | 1 | 5 posts | Basic persona, limited skills |
| **Starter** | $29/mo | 3 | 25 posts | Email sequences, all content types |
| **Pro** | $79/mo | 10 | Unlimited | All agents, advanced analytics |
| **Agency** | $199/mo | Unlimited | Unlimited | White-label, API access, priority |

### Competitive Positioning

- **vs Jasper ($59-99/mo):** More comprehensive (full GTM), similar price
- **vs Copy.ai ($49-249/mo):** Multi-product support, persona discovery
- **vs HubSpot ($800+/mo):** 10-30x cheaper, AI-native
- **vs Agencies ($5K+/mo):** 50-100x cheaper, always-on

---

## Success Metrics

### North Star Metric

**Marketing Tasks Completed Per User Per Month**

### Key Metrics

| Category | Metric | Target (Year 1) |
|----------|--------|-----------------|
| **Growth** | MRR | $5,000 |
| **Growth** | Paying Customers | 100 |
| **Growth** | Free Users | 500 |
| **Engagement** | Tasks/User/Month | 20+ |
| **Engagement** | Content Pieces Created | 10,000 |
| **Engagement** | Approval Rate | > 80% |
| **Retention** | Monthly Churn | < 5% |
| **Quality** | Content Quality Score | > 4.0/5.0 |
| **Quality** | NPS | > 40 |

---

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Big player launches similar | High | Medium | Focus on indie niche, build community |
| AI content commoditization | Medium | Medium | Unique features (persona sim, churn) |
| Users don't trust AI | Medium | High | Human-in-loop, transparency, case studies |
| LLM costs increase | Low | High | Aggressive caching, model flexibility |
| Solo founder execution | Medium | High | Phased approach, dogfooding, community |
| Content quality issues | Medium | Medium | Quality scoring, feedback loops |

---

## Go-to-Market Strategy

### Launch Plan

1. **Month 1-3:** Build MVP, dogfood on WellnessConnect & Linklysis
2. **Month 4:** Private beta with 20 indie makers
3. **Month 5:** Iterate based on feedback
4. **Month 6:** Public launch on Product Hunt
5. **Month 7-12:** Content marketing, community building

### Channels

| Channel | Strategy |
|---------|----------|
| **Indie Hackers** | Build in public, case studies |
| **Twitter/X** | Daily tips, product updates |
| **Product Hunt** | Launch for awareness |
| **Content** | SEO blog (using MarketMind!) |
| **Reddit** | r/SaaS, r/EntrepreneurRideAlong |

### Positioning Statement

> "MarketMind is the AI marketing team for indie makers. Unlike Jasper (content only) or HubSpot (enterprise pricing), MarketMind gives solo founders a complete go-to-market engine—from persona discovery to content creation to lead nurturing—at a price that makes sense for bootstrapped businesses."

---

## Appendix

### A. Glossary

| Term | Definition |
|------|------------|
| **Agentic AI** | AI that can take autonomous actions, not just generate content |
| **AEO** | Answer Engine Optimization - optimizing for AI search (ChatGPT, Perplexity) |
| **ICP** | Ideal Customer Profile |
| **Skill** | A reusable AI capability with defined inputs/outputs |
| **Bounded Context** | DDD term for a self-contained domain with clear boundaries |

### B. Competitive Analysis Links

- Jasper: https://jasper.ai
- Copy.ai: https://copy.ai
- HubSpot: https://hubspot.com
- TheHog.ai: https://thehog.ai

### C. Market Research Sources

- MarketsandMarkets: Marketing Automation Market Report (2025)
- Yahoo Finance: AI in Marketing projections
- Y Combinator: Marketing startup landscape

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2025-12-27 | Kojo | Initial PRD |

---

**Next Steps:** Review PRD → Finalize TODO.md → Begin Phase 1 Sprint 1
