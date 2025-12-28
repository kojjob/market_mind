# MarketMind: Implementation Roadmap (TODO.md)

**Version:** 1.0.0  
**Last Updated:** December 27, 2025  
**Target MVP Date:** Week 8 (February 21, 2026)  
**Target Launch Date:** Month 6 (June 2026)

---

## Overview

This document outlines the complete implementation roadmap for MarketMind, organized into phases, sprints, and individual tasks. Each task follows TDD principles and includes acceptance criteria.

### Legend

- 🔴 **P0** - Critical / Blocker
- 🟠 **P1** - High Priority
- 🟡 **P2** - Medium Priority
- 🟢 **P3** - Nice to Have
- ✅ Complete
- 🔄 In Progress
- ⏸️ Blocked
- ⬜ Not Started

---

## Phase 0: Project Setup (Week 0)

### Sprint 0.1: Foundation

| Status | Priority | Task | Estimated Hours |
|--------|----------|------|-----------------|
| ⬜ | 🔴 | Initialize Phoenix project with LiveView | 2 |
| ⬜ | 🔴 | Configure PostgreSQL database | 1 |
| ⬜ | 🔴 | Set up Oban for background jobs | 2 |
| ⬜ | 🔴 | Configure TailwindCSS | 1 |
| ⬜ | 🔴 | Set up test environment (ExUnit + Mox) | 2 |
| ⬜ | 🔴 | Create base project structure (DDD contexts) | 3 |
| ⬜ | 🟠 | Set up CI/CD with GitHub Actions | 2 |
| ⬜ | 🟠 | Configure Fly.io deployment | 2 |
| ⬜ | 🟠 | Set up environment variables management | 1 |
| ⬜ | 🟡 | Create development seeds | 2 |

**Sprint 0.1 Total:** ~18 hours

### Checklist: Project Structure

```
marketmind/
├── lib/
│   ├── market_mind/
│   │   ├── accounts/           # User/Auth context
│   │   ├── products/           # Product Intelligence context
│   │   ├── personas/           # Persona Management context
│   │   ├── content/            # Content Generation context
│   │   ├── campaigns/          # Campaign Orchestration context
│   │   ├── leads/              # Lead Management context
│   │   ├── analytics/          # Analytics & Insights context
│   │   ├── agents/             # Agent Orchestration context
│   │   │   ├── worker.ex
│   │   │   ├── pool.ex
│   │   │   └── orchestrator.ex
│   │   ├── skills/             # Skill System
│   │   │   ├── skill.ex
│   │   │   ├── registry.ex
│   │   │   └── executor.ex
│   │   └── llm/                # LLM Abstraction
│   │       ├── client.ex
│   │       ├── gemini.ex
│   │       └── claude.ex
│   └── market_mind_web/
│       ├── live/
│       ├── components/
│       └── layouts/
├── test/
├── priv/
│   └── repo/migrations/
└── config/
```

---

## Phase 1: MVP Core (Weeks 1-8)

### Sprint 1.1: Authentication & Projects (Week 1-2)

#### Authentication
| Status | Priority | Task | Hours | Acceptance Criteria |
|--------|----------|------|-------|---------------------|
| ⬜ | 🔴 | Set up phx.gen.auth | 2 | Users can register/login |
| ⬜ | 🔴 | Create User schema with fields | 1 | name, email, password_hash, confirmed_at |
| ⬜ | 🔴 | Email confirmation flow | 3 | Users must confirm email |
| ⬜ | 🟠 | Password reset flow | 2 | Users can reset password |
| ⬜ | 🟠 | Session management | 2 | Remember me, session expiry |
| ⬜ | 🟡 | OAuth (Google) - defer | 0 | Deferred to later |

#### Projects Context
| Status | Priority | Task | Hours | Acceptance Criteria |
|--------|----------|------|-------|---------------------|
| ⬜ | 🔴 | Create Project schema | 2 | name, slug, url, description, user_id |
| ⬜ | 🔴 | Create projects table migration | 1 | All fields, indexes |
| ⬜ | 🔴 | Project CRUD operations | 3 | create, read, update, delete |
| ⬜ | 🔴 | Project context module | 2 | Products.create_project/1, etc. |
| ⬜ | 🔴 | Project LiveView - List | 3 | Display all user projects |
| ⬜ | 🔴 | Project LiveView - Create | 3 | Form to add project by URL |
| ⬜ | 🟠 | Project LiveView - Edit | 2 | Edit project details |
| ⬜ | 🟠 | Project switching in nav | 2 | Select active project |

**Sprint 1.1 Total:** ~28 hours

#### Tests Required
- [ ] `test/market_mind/products_test.exs` - Project CRUD
- [ ] `test/market_mind_web/live/project_live_test.exs` - LiveView tests

---

### Sprint 1.2: Product Analyzer Agent (Week 2-3)

#### LLM Infrastructure
| Status | Priority | Task | Hours | Acceptance Criteria |
|--------|----------|------|-------|---------------------|
| ⬜ | 🔴 | Create LLM.Client behaviour | 2 | Common interface for all providers |
| ⬜ | 🔴 | Implement LLM.Gemini module | 4 | Gemini Flash API integration |
| ⬜ | 🔴 | Request/response parsing | 2 | Handle API responses, errors |
| ⬜ | 🔴 | Token counting utilities | 2 | Estimate tokens before request |
| ⬜ | 🟠 | Response caching (ETS) | 3 | Cache identical prompts |
| ⬜ | 🟠 | Rate limiting | 2 | Respect API limits |
| ⬜ | 🟡 | Usage tracking | 2 | Log tokens used per request |

#### Skills Infrastructure
| Status | Priority | Task | Hours | Acceptance Criteria |
|--------|----------|------|-------|---------------------|
| ⬜ | 🔴 | Create Skill schema | 2 | name, prompt_template, input_schema, etc. |
| ⬜ | 🔴 | Skills table migration | 1 | All fields, indexes |
| ⬜ | 🔴 | Skill.Registry module | 3 | Load, cache, retrieve skills |
| ⬜ | 🔴 | Skill.Executor module | 4 | Build prompt, execute, parse output |
| ⬜ | 🟠 | Seed initial skills | 2 | product_analyzer, persona_builder, etc. |

#### Product Analyzer Skill
| Status | Priority | Task | Hours | Acceptance Criteria |
|--------|----------|------|-------|---------------------|
| ⬜ | 🔴 | Website fetcher (Req) | 3 | Fetch HTML from URL |
| ⬜ | 🔴 | HTML parser (Floki) | 2 | Extract text, meta, headings |
| ⬜ | 🔴 | Product analyzer skill definition | 3 | Prompt template for analysis |
| ⬜ | 🔴 | Store analysis results in Project | 2 | JSON in analysis_data field |
| ⬜ | 🔴 | Background job for analysis | 2 | Oban worker |
| ⬜ | 🟠 | Analysis progress indicator | 2 | LiveView updates |
| ⬜ | 🟠 | Error handling for failed fetches | 2 | Retry logic, user notification |

**Sprint 1.2 Total:** ~43 hours

#### Tests Required
- [ ] `test/market_mind/llm/gemini_test.exs` - Mock API tests
- [ ] `test/market_mind/skills/executor_test.exs` - Skill execution
- [ ] `test/market_mind/products/analyzer_test.exs` - Analysis logic

---

### Sprint 1.3: Persona Builder Agent (Week 3-4)

#### Personas Context
| Status | Priority | Task | Hours | Acceptance Criteria |
|--------|----------|------|-------|---------------------|
| ⬜ | 🔴 | Create Persona schema | 2 | name, role, project_id, demographics, etc. |
| ⬜ | 🔴 | Personas table migration | 1 | All fields, JSONB for nested data |
| ⬜ | 🔴 | Persona CRUD operations | 3 | Full context module |
| ⬜ | 🔴 | Persona builder skill definition | 3 | Prompt for ICP generation |
| ⬜ | 🔴 | Generate personas from product | 3 | Oban job using product data |
| ⬜ | 🔴 | Persona LiveView - List | 3 | Display personas per project |
| ⬜ | 🔴 | Persona LiveView - Detail | 2 | Full persona view |
| ⬜ | 🟠 | Persona LiveView - Edit | 2 | Manual adjustments |
| ⬜ | 🟠 | Mark primary persona | 1 | Toggle in UI |
| ⬜ | 🟡 | Persona comparison view | 3 | Side-by-side comparison |

**Sprint 1.3 Total:** ~23 hours

#### Persona Schema Fields
```elixir
schema "personas" do
  field :name, :string
  field :role, :string
  field :description, :string
  
  # JSONB fields
  field :demographics, :map  # age_range, location, income
  field :goals, {:array, :string}
  field :pain_points, {:array, :string}
  field :objections, {:array, :string}
  field :motivations, {:array, :string}
  field :channels, {:array, :string}
  field :keywords, {:array, :string}
  field :personality_traits, :map  # for simulation
  
  field :is_primary, :boolean, default: false
  
  belongs_to :project, Project
  timestamps()
end
```

---

### Sprint 1.4: Content Writer Agent (Week 4-5)

#### Content Context
| Status | Priority | Task | Hours | Acceptance Criteria |
|--------|----------|------|-------|---------------------|
| ⬜ | 🔴 | Create ContentPiece schema | 2 | title, body, type, status, project_id, persona_id |
| ⬜ | 🔴 | Content table migration | 1 | All fields |
| ⬜ | 🔴 | Content CRUD operations | 3 | Full context module |
| ⬜ | 🔴 | SEO blog writer skill | 4 | Comprehensive prompt |
| ⬜ | 🔴 | Content generation job | 3 | Oban worker with persona context |
| ⬜ | 🔴 | Content LiveView - List | 3 | Table of all content |
| ⬜ | 🔴 | Content LiveView - Create | 3 | Form to request new content |
| ⬜ | 🔴 | Content LiveView - Preview | 2 | Rendered markdown |
| ⬜ | 🟠 | Keyword targeting input | 2 | Primary/secondary keywords |
| ⬜ | 🟠 | AEO formatting option | 2 | FAQ sections, TL;DR |
| ⬜ | 🟡 | Content templates | 3 | Pre-built content structures |

**Sprint 1.4 Total:** ~28 hours

#### Content Types (Enum)
```elixir
# :blog, :email, :social_twitter, :social_linkedin, :ad_copy, :landing_page
```

#### SEO Blog Skill Template (Example)
```elixir
%Skill{
  name: "seo_blog_writer",
  prompt_template: """
  You are an expert SEO content writer. Create a blog post for:

  PRODUCT: {{product.name}}
  {{product.description}}
  Value Props: {{product.value_propositions}}

  TARGET PERSONA: {{persona.name}} - {{persona.role}}
  Pain Points: {{persona.pain_points | join(", ")}}
  Goals: {{persona.goals | join(", ")}}

  PRIMARY KEYWORD: {{primary_keyword}}
  SECONDARY KEYWORDS: {{secondary_keywords | join(", ")}}
  
  WORD COUNT: {{word_count | default: 1500}}
  TONE: {{brand_voice.tone | default: "professional but friendly"}}

  REQUIREMENTS:
  - SEO: Include primary keyword in title, first paragraph, 2+ H2 headings
  - AEO: Add TL;DR summary at top, include FAQ section with 3-5 questions
  - Structure: Clear H2/H3 hierarchy, short paragraphs (3-4 sentences max)
  - Engagement: Include relevant examples, actionable tips

  OUTPUT FORMAT (JSON):
  {
    "title": "SEO-optimized title with keyword",
    "meta_description": "155 characters max",
    "slug": "url-friendly-slug",
    "tldr": "2-3 sentence summary",
    "content": "Full markdown content with ## and ### headings",
    "faq": [
      {"question": "...", "answer": "..."}
    ],
    "estimated_read_time": "X min"
  }
  """,
  input_schema: %{
    "type" => "object",
    "required" => ["primary_keyword"],
    "properties" => %{
      "primary_keyword" => %{"type" => "string"},
      "secondary_keywords" => %{"type" => "array", "items" => %{"type" => "string"}},
      "word_count" => %{"type" => "integer", "default" => 1500}
    }
  }
}
```

---

### Sprint 1.5: Approval Workflow (Week 5-6)

| Status | Priority | Task | Hours | Acceptance Criteria |
|--------|----------|------|-------|---------------------|
| ⬜ | 🔴 | Add approval_status to ContentPiece | 1 | pending, approved, rejected, revision_requested |
| ⬜ | 🔴 | Approval queue LiveView | 4 | List pending content |
| ⬜ | 🔴 | Approve action | 2 | Update status, timestamp |
| ⬜ | 🔴 | Reject action | 2 | Update status, store reason |
| ⬜ | 🔴 | Request revision action | 3 | Store feedback, trigger regeneration |
| ⬜ | 🟠 | Revision diff view | 3 | Side-by-side old vs new |
| ⬜ | 🟠 | Batch approval | 2 | Select multiple, approve all |
| ⬜ | 🟡 | Email notifications | 3 | Notify when content ready |
| ⬜ | 🟡 | Auto-approve rules | 4 | Trust after N approvals |

**Sprint 1.5 Total:** ~24 hours

#### Approval State Machine
```
   ┌──────────┐
   │ pending  │
   └────┬─────┘
        │
   ┌────┴────────────────┬────────────────┐
   ▼                     ▼                ▼
┌──────────┐      ┌───────────┐    ┌──────────┐
│ approved │      │  rejected │    │ revision │
└──────────┘      └───────────┘    │_requested│
                                   └─────┬────┘
                                         │
                                    ┌────▼────┐
                                    │ pending │ (new version)
                                    └─────────┘
```

---

### Sprint 1.6: Dashboard & Analytics (Week 6-7)

| Status | Priority | Task | Hours | Acceptance Criteria |
|--------|----------|------|-------|---------------------|
| ⬜ | 🔴 | Main dashboard LiveView | 4 | Overview of all projects |
| ⬜ | 🔴 | Project summary cards | 3 | Name, content count, pending |
| ⬜ | 🔴 | Recent activity feed | 3 | Last 10 actions |
| ⬜ | 🔴 | Pending approvals indicator | 2 | Badge with count |
| ⬜ | 🟠 | Content created chart | 3 | Weekly bar chart |
| ⬜ | 🟠 | Token usage display | 2 | Current period usage |
| ⬜ | 🟡 | Agent status cards | 3 | Working/available agents |
| ⬜ | 🟡 | Quick actions panel | 2 | Generate content, add project |

**Sprint 1.6 Total:** ~22 hours

---

### Sprint 1.7: Agent System Core (Week 7-8)

| Status | Priority | Task | Hours | Acceptance Criteria |
|--------|----------|------|-------|---------------------|
| ⬜ | 🔴 | Agent schema | 2 | id, name, status, current_project_id |
| ⬜ | 🔴 | Agents table migration | 1 | All fields |
| ⬜ | 🔴 | Agents.Worker GenServer | 6 | Full worker implementation |
| ⬜ | 🔴 | Agents.Pool supervisor | 4 | Manage worker pool |
| ⬜ | 🔴 | Agents.Orchestrator | 5 | Task routing, assignment |
| ⬜ | 🔴 | Task schema | 2 | type, input, output, status |
| ⬜ | 🔴 | Tasks table migration | 1 | All fields |
| ⬜ | 🔴 | Task queue integration | 3 | Priority queue with Oban |
| ⬜ | 🟠 | Skill execution logging | 3 | skill_executions table |
| ⬜ | 🟠 | Agent performance metrics | 2 | Tasks completed, avg duration |

**Sprint 1.7 Total:** ~29 hours

---

### Sprint 1.8: MVP Polish & Testing (Week 8)

| Status | Priority | Task | Hours | Acceptance Criteria |
|--------|----------|------|-------|---------------------|
| ⬜ | 🔴 | End-to-end testing | 8 | Full user journey works |
| ⬜ | 🔴 | Error handling review | 4 | Graceful failures |
| ⬜ | 🔴 | Loading states | 3 | Skeleton loaders |
| ⬜ | 🔴 | Empty states | 2 | Helpful messages |
| ⬜ | 🔴 | Flash messages | 2 | Success/error toasts |
| ⬜ | 🟠 | Responsive design check | 4 | Mobile-friendly |
| ⬜ | 🟠 | Performance profiling | 3 | Identify bottlenecks |
| ⬜ | 🟠 | Security review | 4 | Input validation, auth |
| ⬜ | 🟡 | Documentation | 4 | README, setup guide |
| ⬜ | 🟡 | Deploy to production | 3 | Fly.io setup |

**Sprint 1.8 Total:** ~37 hours

---

## Phase 1 Summary

| Sprint | Hours | Focus |
|--------|-------|-------|
| 0.1 | 18 | Project setup |
| 1.1 | 28 | Auth & Projects |
| 1.2 | 43 | Product Analyzer |
| 1.3 | 23 | Persona Builder |
| 1.4 | 28 | Content Writer |
| 1.5 | 24 | Approval Workflow |
| 1.6 | 22 | Dashboard |
| 1.7 | 29 | Agent System |
| 1.8 | 37 | Polish & Testing |
| **Total** | **252** | **~8 weeks @ 32 hrs/week** |

---

## Phase 2: Core Features (Weeks 9-16)

### Sprint 2.1: Content Atomizer (Week 9-10)

| Status | Priority | Task | Hours |
|--------|----------|------|-------|
| ⬜ | 🔴 | Content atomizer skill | 4 |
| ⬜ | 🔴 | Twitter thread generator | 3 |
| ⬜ | 🔴 | LinkedIn post generator | 3 |
| ⬜ | 🔴 | Email summary generator | 2 |
| ⬜ | 🔴 | Quote extractor | 2 |
| ⬜ | 🟠 | Atomize action in UI | 3 |
| ⬜ | 🟠 | Preview all formats | 3 |
| ⬜ | 🟠 | Selective regeneration | 2 |
| ⬜ | 🟡 | Reddit post formatter | 2 |
| ⬜ | 🟡 | IH comment generator | 2 |

**Sprint 2.1 Total:** ~26 hours

---

### Sprint 2.2: Email Sequences (Week 10-11)

| Status | Priority | Task | Hours |
|--------|----------|------|-------|
| ⬜ | 🔴 | EmailSequence schema | 2 |
| ⬜ | 🔴 | SequenceStep schema | 2 |
| ⬜ | 🔴 | SendGrid integration | 4 |
| ⬜ | 🔴 | Sequence templates (welcome, nurture) | 4 |
| ⬜ | 🔴 | Email writer skill | 4 |
| ⬜ | 🔴 | Sequence builder LiveView | 6 |
| ⬜ | 🟠 | Visual sequence editor | 6 |
| ⬜ | 🟠 | Delay configuration | 2 |
| ⬜ | 🟡 | A/B test subjects | 4 |
| ⬜ | 🟡 | Send analytics | 4 |

**Sprint 2.2 Total:** ~38 hours

---

### Sprint 2.3: Skill Management (Week 11-12)

| Status | Priority | Task | Hours |
|--------|----------|------|-------|
| ⬜ | 🔴 | Skill management LiveView | 4 |
| ⬜ | 🔴 | Skill detail view | 3 |
| ⬜ | 🟠 | Create custom skill form | 5 |
| ⬜ | 🟠 | Skill versioning | 4 |
| ⬜ | 🟠 | Skill version migration | 2 |
| ⬜ | 🟡 | A/B test skill versions | 5 |
| ⬜ | 🟡 | Skill performance charts | 4 |
| ⬜ | 🟡 | Import/export skills | 3 |

**Sprint 2.3 Total:** ~30 hours

---

### Sprint 2.4: Keyword Research (Week 12-13)

| Status | Priority | Task | Hours |
|--------|----------|------|-------|
| ⬜ | 🟠 | Keyword suggestion skill | 4 |
| ⬜ | 🟠 | Keyword tracking table | 2 |
| ⬜ | 🟠 | Keyword management UI | 4 |
| ⬜ | 🟠 | Keyword-to-content mapping | 3 |
| ⬜ | 🟡 | Search volume estimates | 4 |
| ⬜ | 🟡 | Keyword difficulty scoring | 4 |
| ⬜ | 🟡 | Competitor keyword analysis | 5 |

**Sprint 2.4 Total:** ~26 hours

---

### Sprint 2.5: Enhanced Analytics (Week 13-14)

| Status | Priority | Task | Hours |
|--------|----------|------|-------|
| ⬜ | 🟠 | Content performance tracking | 4 |
| ⬜ | 🟠 | Skill execution analytics | 4 |
| ⬜ | 🟠 | Cost tracking dashboard | 4 |
| ⬜ | 🟠 | Export analytics (CSV) | 3 |
| ⬜ | 🟡 | Persona effectiveness | 4 |
| ⬜ | 🟡 | A/B test results | 5 |
| ⬜ | 🟡 | Custom date ranges | 3 |

**Sprint 2.5 Total:** ~27 hours

---

### Sprint 2.6: Claude SDK Integration (Week 14-15)

| Status | Priority | Task | Hours |
|--------|----------|------|-------|
| ⬜ | 🔴 | LLM.Claude module | 4 |
| ⬜ | 🔴 | Tool use implementation | 6 |
| ⬜ | 🔴 | Web search tool | 4 |
| ⬜ | 🟠 | Competitor analysis tool | 5 |
| ⬜ | 🟠 | Keyword research tool | 4 |
| ⬜ | 🟠 | LLM routing logic | 4 |
| ⬜ | 🟡 | MCP server setup | 6 |

**Sprint 2.6 Total:** ~33 hours

---

### Sprint 2.7: Lead Capture (Week 15-16)

| Status | Priority | Task | Hours |
|--------|----------|------|-------|
| ⬜ | 🟠 | Lead schema | 2 |
| ⬜ | 🟠 | Lead capture form component | 4 |
| ⬜ | 🟠 | Embed code generator | 3 |
| ⬜ | 🟠 | Lead list view | 3 |
| ⬜ | 🟠 | Lead-to-sequence assignment | 3 |
| ⬜ | 🟡 | Lead scoring skill | 5 |
| ⬜ | 🟡 | Lead enrichment | 4 |

**Sprint 2.7 Total:** ~24 hours

---

### Sprint 2.8: Phase 2 Polish (Week 16)

| Status | Priority | Task | Hours |
|--------|----------|------|-------|
| ⬜ | 🔴 | Integration testing | 8 |
| ⬜ | 🔴 | Bug fixes | 8 |
| ⬜ | 🟠 | Performance optimization | 6 |
| ⬜ | 🟠 | UI/UX refinements | 6 |
| ⬜ | 🟡 | Documentation updates | 4 |

**Sprint 2.8 Total:** ~32 hours

---

## Phase 2 Summary

| Sprint | Hours | Focus |
|--------|-------|-------|
| 2.1 | 26 | Content Atomizer |
| 2.2 | 38 | Email Sequences |
| 2.3 | 30 | Skill Management |
| 2.4 | 26 | Keyword Research |
| 2.5 | 27 | Analytics |
| 2.6 | 33 | Claude SDK |
| 2.7 | 24 | Lead Capture |
| 2.8 | 32 | Polish |
| **Total** | **236** | **~8 weeks @ 30 hrs/week** |

---

## Phase 3: Disruptive Features (Weeks 17-24)

### Sprint 3.1-3.2: Persona Simulation Engine (Week 17-18)

| Status | Priority | Task | Hours |
|--------|----------|------|-------|
| ⬜ | 🟠 | Persona simulation skill | 6 |
| ⬜ | 🟠 | Simulation UI | 5 |
| ⬜ | 🟠 | Message/copy input | 3 |
| ⬜ | 🟠 | Reaction generation | 4 |
| ⬜ | 🟠 | Objection prediction | 4 |
| ⬜ | 🟠 | Suggestion generation | 4 |
| ⬜ | 🟡 | Multi-persona simulation | 5 |
| ⬜ | 🟡 | Simulation history | 3 |

**Sprint 3.1-3.2 Total:** ~34 hours

---

### Sprint 3.3-3.4: Churn Prophecy Engine (Week 19-20)

| Status | Priority | Task | Hours |
|--------|----------|------|-------|
| ⬜ | 🟠 | Churn signal schema | 3 |
| ⬜ | 🟠 | Signal collection API | 5 |
| ⬜ | 🟠 | Churn prediction skill | 6 |
| ⬜ | 🟠 | Risk score calculation | 4 |
| ⬜ | 🟠 | Churn dashboard | 4 |
| ⬜ | 🟠 | Intervention suggestions | 4 |
| ⬜ | 🟡 | Auto-trigger win-back | 5 |
| ⬜ | 🟡 | Integration hooks | 4 |

**Sprint 3.3-3.4 Total:** ~35 hours

---

### Sprint 3.5-3.6: Competitor Radar (Week 21-22)

| Status | Priority | Task | Hours |
|--------|----------|------|-------|
| ⬜ | 🟠 | Competitor schema | 2 |
| ⬜ | 🟠 | Website monitoring job | 6 |
| ⬜ | 🟠 | Change detection | 5 |
| ⬜ | 🟠 | Competitor dashboard | 4 |
| ⬜ | 🟠 | Alert system | 4 |
| ⬜ | 🟡 | Pricing tracking | 4 |
| ⬜ | 🟡 | Feature comparison | 5 |
| ⬜ | 🟡 | Content analysis | 4 |

**Sprint 3.5-3.6 Total:** ~34 hours

---

### Sprint 3.7-3.8: Phase 3 Integration & Polish (Week 23-24)

| Status | Priority | Task | Hours |
|--------|----------|------|-------|
| ⬜ | 🔴 | Feature integration testing | 12 |
| ⬜ | 🔴 | Cross-feature workflows | 8 |
| ⬜ | 🟠 | Performance optimization | 8 |
| ⬜ | 🟠 | UI consistency | 6 |
| ⬜ | 🟠 | Error handling | 6 |
| ⬜ | 🟡 | Documentation | 6 |

**Sprint 3.7-3.8 Total:** ~46 hours

---

## Phase 3 Summary

| Sprint | Hours | Focus |
|--------|-------|-------|
| 3.1-3.2 | 34 | Persona Simulation |
| 3.3-3.4 | 35 | Churn Prophecy |
| 3.5-3.6 | 34 | Competitor Radar |
| 3.7-3.8 | 46 | Integration |
| **Total** | **149** | **~8 weeks @ 19 hrs/week** |

---

## Phase 4: Integrations & Launch (Weeks 25-32)

### Sprint 4.1-4.2: CRM Integrations (Week 25-26)

| Status | Priority | Task | Hours |
|--------|----------|------|-------|
| ⬜ | 🟠 | HubSpot integration | 12 |
| ⬜ | 🟠 | Pipedrive integration | 10 |
| ⬜ | 🟡 | Notion integration | 8 |
| ⬜ | 🟡 | Custom webhooks | 6 |

**Sprint 4.1-4.2 Total:** ~36 hours

---

### Sprint 4.3-4.4: Analytics Integrations (Week 27-28)

| Status | Priority | Task | Hours |
|--------|----------|------|-------|
| ⬜ | 🟠 | GA4 integration | 10 |
| ⬜ | 🟠 | Plausible integration | 8 |
| ⬜ | 🟡 | PostHog integration | 8 |
| ⬜ | 🟡 | Custom events API | 6 |

**Sprint 4.3-4.4 Total:** ~32 hours

---

### Sprint 4.5-4.6: Billing & Subscriptions (Week 29-30)

| Status | Priority | Task | Hours |
|--------|----------|------|-------|
| ⬜ | 🔴 | Stripe integration | 10 |
| ⬜ | 🔴 | Subscription tiers | 6 |
| ⬜ | 🔴 | Usage limits | 6 |
| ⬜ | 🔴 | Billing portal | 6 |
| ⬜ | 🟠 | Trial period | 4 |
| ⬜ | 🟠 | Upgrade prompts | 4 |

**Sprint 4.5-4.6 Total:** ~36 hours

---

### Sprint 4.7-4.8: Launch Preparation (Week 31-32)

| Status | Priority | Task | Hours |
|--------|----------|------|-------|
| ⬜ | 🔴 | Landing page | 12 |
| ⬜ | 🔴 | Documentation site | 10 |
| ⬜ | 🔴 | Product Hunt preparation | 8 |
| ⬜ | 🔴 | Beta user feedback | 8 |
| ⬜ | 🟠 | Marketing content (using MarketMind!) | 10 |
| ⬜ | 🟠 | Onboarding flow | 8 |
| ⬜ | 🟠 | Final testing | 8 |

**Sprint 4.7-4.8 Total:** ~64 hours

---

## Phase 4 Summary

| Sprint | Hours | Focus |
|--------|-------|-------|
| 4.1-4.2 | 36 | CRM Integrations |
| 4.3-4.4 | 32 | Analytics |
| 4.5-4.6 | 36 | Billing |
| 4.7-4.8 | 64 | Launch |
| **Total** | **168** | **~8 weeks @ 21 hrs/week** |

---

## Grand Total Summary

| Phase | Weeks | Hours | Focus |
|-------|-------|-------|-------|
| **Phase 0** | 1 | 18 | Setup |
| **Phase 1** | 8 | 252 | MVP Core |
| **Phase 2** | 8 | 236 | Core Features |
| **Phase 3** | 8 | 149 | Disruptive Features |
| **Phase 4** | 8 | 168 | Integrations & Launch |
| **TOTAL** | **33** | **823** | **Full Product** |

---

## Milestone Checklist

### Milestone 1: MVP Complete (Week 8) ⬜
- [ ] Users can register and authenticate
- [ ] Users can add projects by URL
- [ ] Product Analyzer extracts info automatically
- [ ] Persona Builder generates ICPs
- [ ] Content Writer creates SEO blog posts
- [ ] Approval workflow functional
- [ ] Basic dashboard operational
- [ ] Agent system working
- [ ] Deployed to production

### Milestone 2: Beta Ready (Week 16) ⬜
- [ ] Content Atomizer working
- [ ] Email sequences functional
- [ ] Skill management UI complete
- [ ] Claude SDK integrated
- [ ] Lead capture working
- [ ] 20 beta users onboarded

### Milestone 3: Feature Complete (Week 24) ⬜
- [ ] Persona Simulation Engine working
- [ ] Churn Prophecy functional
- [ ] Competitor Radar tracking
- [ ] All disruptive features integrated

### Milestone 4: Launch Ready (Week 32) ⬜
- [ ] All integrations working
- [ ] Billing/subscriptions active
- [ ] Landing page live
- [ ] Documentation complete
- [ ] Product Hunt launched
- [ ] First paying customers

---

## Risk Tracking

| Risk | Status | Mitigation |
|------|--------|------------|
| LLM API costs spike | ⬜ Monitoring | Caching, usage limits |
| Feature creep | ⬜ Monitoring | Stick to roadmap |
| Solo founder burnout | ⬜ Monitoring | Sustainable pace, breaks |
| Technical debt | ⬜ Monitoring | Regular refactoring sprints |
| Market timing | ⬜ Monitoring | Ship MVP fast |

---

## Weekly Progress Tracker

### Week 1 (Starting: TBD)
- [ ] Sprint 0.1 complete
- [ ] Sprint 1.1 started
- Hours logged: ___

### Week 2
- [ ] Sprint 1.1 complete
- [ ] Sprint 1.2 started
- Hours logged: ___

*(Continue for all weeks...)*

---

## Notes & Decisions

### Architecture Decisions
- **Decision:** Use GenServer for agents instead of GenStage
  - **Rationale:** Simpler for initial implementation, can migrate later
  - **Date:** 2025-12-27

### Deferred Features
- OAuth login → Post-launch
- Mobile app → v2
- Team collaboration → Post-launch
- API access → Agency tier only

---

**Last Updated:** December 27, 2025  
**Next Review:** Weekly on Mondays
