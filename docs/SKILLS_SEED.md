# Skill Seed Data

> Initial skills to seed into the database for MarketMind MVP.

## Skill Structure Reference

```elixir
%{
  name: "skill_name",
  slug: "skill-name",
  description: "What this skill does",
  version: "1.0.0",
  category: :content | :analysis | :outreach | :optimization | :meta,
  
  # Prompts
  prompt_template: "...",  # Main prompt with {{placeholders}}
  system_prompt: "...",    # System context
  
  # Schemas
  input_schema: %{...},    # Expected input structure
  output_schema: %{...},   # Expected output structure
  required_context: [...], # Context fields needed (e.g., ["project", "persona"])
  
  # LLM Config
  llm_provider: :gemini | :claude,
  llm_model: "model-name",
  llm_config: %{temperature: 0.7, max_tokens: 4096}
}
```

---

## Phase 1 MVP Skills

### 1. Product Analyzer

```elixir
# priv/repo/seeds/skills/product_analyzer.exs
%{
  name: "product_analyzer",
  slug: "product-analyzer",
  description: "Analyzes a product website to extract value propositions, features, target audience, and brand voice.",
  version: "1.0.0",
  category: :analysis,
  
  system_prompt: """
  You are an expert product analyst and marketing strategist. Your job is to analyze websites and extract key marketing insights.
  
  Be thorough but concise. Focus on what makes this product unique and valuable to its target customers.
  
  Always respond in valid JSON format.
  """,
  
  prompt_template: """
  Analyze the following website content and extract marketing insights.

  ## Website URL
  {{input.url}}

  ## Website Content
  {{input.content}}

  ## Analysis Required

  Extract and return the following in JSON format:

  {
    "product_name": "Name of the product/company",
    "tagline": "Main tagline or headline",
    "description": "2-3 sentence description of what the product does",
    "value_propositions": [
      "Value prop 1",
      "Value prop 2",
      "Value prop 3"
    ],
    "features": [
      {
        "name": "Feature name",
        "description": "What it does",
        "benefit": "Why it matters to users"
      }
    ],
    "target_audience": {
      "primary": "Primary target audience description",
      "secondary": "Secondary audience if applicable",
      "industries": ["Industry 1", "Industry 2"],
      "company_sizes": ["Startup", "SMB", "Enterprise"]
    },
    "brand_voice": {
      "tone": "Professional/Casual/Technical/Friendly/etc",
      "personality_traits": ["Trait 1", "Trait 2"],
      "writing_style": "Description of writing style"
    },
    "competitors_mentioned": ["Competitor 1", "Competitor 2"],
    "pricing_model": "Free/Freemium/Subscription/One-time/etc",
    "unique_differentiators": [
      "What makes this product different from alternatives"
    ]
  }
  """,
  
  input_schema: %{
    type: "object",
    properties: %{
      url: %{type: "string", description: "Website URL to analyze"},
      content: %{type: "string", description: "Scraped website content"}
    },
    required: ["url", "content"]
  },
  
  output_schema: %{
    type: "object",
    properties: %{
      product_name: %{type: "string"},
      tagline: %{type: "string"},
      description: %{type: "string"},
      value_propositions: %{type: "array", items: %{type: "string"}},
      features: %{type: "array"},
      target_audience: %{type: "object"},
      brand_voice: %{type: "object"},
      competitors_mentioned: %{type: "array"},
      pricing_model: %{type: "string"},
      unique_differentiators: %{type: "array"}
    }
  },
  
  required_context: [],
  
  llm_provider: :gemini,
  llm_model: "gemini-1.5-flash",
  llm_config: %{
    temperature: 0.3,
    max_tokens: 4096,
    response_format: :json
  }
}
```

---

### 2. Persona Builder

```elixir
# priv/repo/seeds/skills/persona_builder.exs
%{
  name: "persona_builder",
  slug: "persona-builder",
  description: "Generates detailed buyer personas based on product analysis and target market.",
  version: "1.0.0",
  category: :analysis,
  
  system_prompt: """
  You are an expert in customer research and buyer persona development. You create detailed, actionable buyer personas that help marketing teams understand and connect with their target customers.
  
  Create personas that are:
  - Specific and realistic (not generic)
  - Based on the product's actual value propositions
  - Actionable for content and messaging decisions
  
  Always respond in valid JSON format.
  """,
  
  prompt_template: """
  Create a detailed buyer persona for the following product.

  ## Product Information
  - **Name:** {{context.project.name}}
  - **Description:** {{context.project.description}}
  - **Value Propositions:** {{context.project.value_propositions}}
  - **Target Industries:** {{context.project.target_industries}}

  ## Persona Requirements
  {{input.requirements}}

  ## Generate Persona

  Return a detailed persona in this JSON format:

  {
    "name": "Persona name (e.g., 'Startup Sarah')",
    "role": "Job title",
    "description": "2-3 sentence overview of this persona",
    "demographics": {
      "age_range": "25-35",
      "gender": "Any/Male/Female",
      "location": "Urban areas, US",
      "education": "Bachelor's degree or higher",
      "income_range": "$80,000-$150,000"
    },
    "professional": {
      "company_size": "10-50 employees",
      "industry": "Technology/SaaS",
      "years_experience": "5-10 years",
      "reports_to": "CEO/Founder",
      "team_size": "3-5 direct reports"
    },
    "goals": [
      "Primary goal 1",
      "Primary goal 2",
      "Primary goal 3"
    ],
    "pain_points": [
      "Pain point 1 - specific and relatable",
      "Pain point 2",
      "Pain point 3"
    ],
    "objections": [
      "Why they might hesitate to buy",
      "Common concern 2"
    ],
    "motivations": [
      "What drives their decisions",
      "What success looks like to them"
    ],
    "channels": [
      "LinkedIn",
      "Twitter",
      "Industry podcasts",
      "Google search"
    ],
    "keywords": [
      "Search terms they use",
      "Topics they care about"
    ],
    "content_preferences": {
      "formats": ["Blog posts", "Case studies", "Video tutorials"],
      "tone": "Professional but approachable",
      "length": "Prefers concise, scannable content"
    },
    "buying_journey": {
      "awareness_triggers": ["What makes them realize they have a problem"],
      "research_behavior": ["How they evaluate solutions"],
      "decision_factors": ["What matters most in their decision"]
    },
    "quotes": [
      "A quote this persona might say about their challenges",
      "A quote about what they're looking for in a solution"
    ]
  }
  """,
  
  input_schema: %{
    type: "object",
    properties: %{
      requirements: %{type: "string", description: "Specific requirements or focus for this persona"}
    },
    required: []
  },
  
  output_schema: %{
    type: "object",
    properties: %{
      name: %{type: "string"},
      role: %{type: "string"},
      description: %{type: "string"},
      demographics: %{type: "object"},
      professional: %{type: "object"},
      goals: %{type: "array"},
      pain_points: %{type: "array"},
      objections: %{type: "array"},
      motivations: %{type: "array"},
      channels: %{type: "array"},
      keywords: %{type: "array"},
      content_preferences: %{type: "object"},
      buying_journey: %{type: "object"},
      quotes: %{type: "array"}
    }
  },
  
  required_context: ["project"],
  
  llm_provider: :gemini,
  llm_model: "gemini-1.5-flash",
  llm_config: %{
    temperature: 0.7,
    max_tokens: 4096,
    response_format: :json
  }
}
```

---

### 3. SEO Blog Writer

```elixir
# priv/repo/seeds/skills/seo_blog_writer.exs
%{
  name: "seo_blog_writer",
  slug: "seo-blog-writer",
  description: "Writes SEO-optimized blog posts with AEO (Answer Engine Optimization) elements.",
  version: "1.0.0",
  category: :content,
  
  system_prompt: """
  You are an expert SEO content writer who creates engaging, well-researched blog posts optimized for both search engines and readers.

  Your content should:
  - Be genuinely helpful and informative
  - Include natural keyword usage (no stuffing)
  - Have clear structure with H2/H3 headings
  - Include AEO elements (TL;DR, FAQ) for AI search engines
  - Match the brand voice provided
  - Be written for the target persona

  Write in a conversational, expert tone. Use examples and actionable advice.
  """,
  
  prompt_template: """
  Write an SEO-optimized blog post for the following product and persona.

  ## Product Context
  - **Product:** {{context.project.name}}
  - **Description:** {{context.project.description}}
  - **Value Props:** {{context.project.value_propositions}}
  - **Brand Voice:** {{context.project.brand_voice.tone}}

  ## Target Persona
  - **Name:** {{context.persona.name}}
  - **Role:** {{context.persona.role}}
  - **Pain Points:** {{context.persona.pain_points}}
  - **Goals:** {{context.persona.goals}}

  ## Content Requirements
  - **Primary Keyword:** {{input.primary_keyword}}
  - **Secondary Keywords:** {{input.secondary_keywords}}
  - **Topic:** {{input.topic}}
  - **Word Count:** {{input.word_count}} words (approximately)
  - **Content Angle:** {{input.angle}}

  ## Output Format

  Return the blog post in this JSON structure:

  {
    "title": "Compelling, keyword-rich title (50-60 characters)",
    "meta_description": "SEO meta description (150-160 characters)",
    "slug": "url-friendly-slug",
    "tldr": "2-3 sentence summary for AI search engines and quick readers",
    "body": "Full blog post in Markdown format with:\n- Introduction (hook + problem + promise)\n- H2 sections with H3 subsections as needed\n- Actionable tips and examples\n- Conclusion with CTA",
    "faq": [
      {
        "question": "Common question related to the topic",
        "answer": "Concise, helpful answer (2-3 sentences)"
      },
      {
        "question": "Another relevant question",
        "answer": "Answer"
      },
      {
        "question": "Third question",
        "answer": "Answer"
      }
    ],
    "word_count": 1500,
    "primary_keyword_count": 8,
    "internal_link_suggestions": [
      "Topic that could link to another blog post"
    ],
    "cta": {
      "text": "Call-to-action text",
      "context": "Where in the post to place it"
    }
  }

  ## SEO Guidelines
  - Include primary keyword in: title, first paragraph, one H2, meta description
  - Use secondary keywords naturally throughout
  - Write for humans first, search engines second
  - Include the TL;DR at the very beginning for AEO
  - FAQ section should answer real questions the persona would ask
  """,
  
  input_schema: %{
    type: "object",
    properties: %{
      primary_keyword: %{type: "string"},
      secondary_keywords: %{type: "array", items: %{type: "string"}},
      topic: %{type: "string"},
      word_count: %{type: "integer", default: 1500},
      angle: %{type: "string", description: "Unique angle or hook for the content"}
    },
    required: ["primary_keyword", "topic"]
  },
  
  output_schema: %{
    type: "object",
    properties: %{
      title: %{type: "string"},
      meta_description: %{type: "string"},
      slug: %{type: "string"},
      tldr: %{type: "string"},
      body: %{type: "string"},
      faq: %{type: "array"},
      word_count: %{type: "integer"},
      primary_keyword_count: %{type: "integer"},
      internal_link_suggestions: %{type: "array"},
      cta: %{type: "object"}
    }
  },
  
  required_context: ["project", "persona"],
  
  llm_provider: :gemini,
  llm_model: "gemini-1.5-flash",
  llm_config: %{
    temperature: 0.7,
    max_tokens: 8192,
    response_format: :json
  }
}
```

---

### 4. Content Atomizer

```elixir
# priv/repo/seeds/skills/content_atomizer.exs
%{
  name: "content_atomizer",
  slug: "content-atomizer",
  description: "Transforms long-form content into multiple social media posts and snippets.",
  version: "1.0.0",
  category: :content,
  
  system_prompt: """
  You are a social media content expert who transforms long-form content into engaging, platform-specific posts.

  Each platform has different requirements:
  - Twitter/X: 280 chars max, punchy, can use threads
  - LinkedIn: Professional tone, can be longer, use line breaks
  - Reddit: Authentic, value-first, no obvious marketing

  Create content that feels native to each platform.
  """,
  
  prompt_template: """
  Transform the following blog post into social media content.

  ## Source Content
  **Title:** {{input.title}}
  **Content:**
  {{input.content}}

  ## Brand Voice
  {{context.project.brand_voice.tone}}

  ## Target Platforms
  {{input.platforms}}

  ## Output Format

  Return atomized content in this JSON structure:

  {
    "twitter_thread": [
      {
        "text": "Tweet 1 - Hook (max 280 chars)",
        "position": 1
      },
      {
        "text": "Tweet 2 - Key insight",
        "position": 2
      },
      {
        "text": "Tweet 3 - Example or tip",
        "position": 3
      },
      {
        "text": "Tweet 4 - CTA or conclusion",
        "position": 4
      }
    ],
    "twitter_standalone": [
      {
        "text": "Standalone tweet with key takeaway",
        "hook_type": "question/statistic/bold_claim"
      },
      {
        "text": "Another standalone tweet",
        "hook_type": "tip"
      }
    ],
    "linkedin_post": {
      "text": "Full LinkedIn post (can be 1000+ chars)\n\nUse line breaks for readability.\n\nEnd with engagement question or CTA.",
      "hashtags": ["#relevanthashtag", "#another"]
    },
    "linkedin_short": {
      "text": "Shorter LinkedIn post for quick engagement",
      "hashtags": []
    },
    "reddit_post": {
      "title": "Value-focused title (no clickbait)",
      "body": "Detailed, helpful post body. Share genuine insights.",
      "suggested_subreddits": ["relevantsubreddit", "another"]
    },
    "email_snippet": {
      "subject_line": "Email subject line",
      "preview_text": "Preview text (40-50 chars)",
      "body_snippet": "Key paragraph for newsletter"
    },
    "pull_quotes": [
      "Quotable line from the content",
      "Another memorable quote"
    ]
  }
  """,
  
  input_schema: %{
    type: "object",
    properties: %{
      title: %{type: "string"},
      content: %{type: "string"},
      platforms: %{type: "array", items: %{type: "string"}, default: ["twitter", "linkedin"]}
    },
    required: ["title", "content"]
  },
  
  output_schema: %{
    type: "object",
    properties: %{
      twitter_thread: %{type: "array"},
      twitter_standalone: %{type: "array"},
      linkedin_post: %{type: "object"},
      linkedin_short: %{type: "object"},
      reddit_post: %{type: "object"},
      email_snippet: %{type: "object"},
      pull_quotes: %{type: "array"}
    }
  },
  
  required_context: ["project"],
  
  llm_provider: :gemini,
  llm_model: "gemini-1.5-flash",
  llm_config: %{
    temperature: 0.8,
    max_tokens: 4096,
    response_format: :json
  }
}
```

---

## Seeding Script

```elixir
# priv/repo/seeds.exs

alias MarketMind.Repo
alias MarketMind.Skills.Skill

# Load all skill seed files
skill_files = Path.wildcard("priv/repo/seeds/skills/*.exs")

for file <- skill_files do
  {skill_data, _} = Code.eval_file(file)
  
  case Repo.get_by(Skill, slug: skill_data.slug) do
    nil ->
      %Skill{}
      |> Skill.changeset(skill_data)
      |> Repo.insert!()
      IO.puts("Created skill: #{skill_data.name}")
      
    existing ->
      existing
      |> Skill.changeset(skill_data)
      |> Repo.update!()
      IO.puts("Updated skill: #{skill_data.name}")
  end
end

IO.puts("\n✅ Skills seeded successfully!")
```

---

## Phase 2 Skills (Preview)

Skills to implement in Phase 2:

1. **keyword_researcher** - Research and suggest keywords for content
2. **email_sequence_writer** - Generate email sequence content
3. **competitor_analyzer** - Analyze competitor websites (uses Claude + tools)
4. **persona_simulator** - Simulate persona responses to content
5. **churn_predictor** - Analyze signals and predict churn risk

These will be documented as we approach Phase 2 implementation.
