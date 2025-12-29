defmodule MarketMind.Agents.LeadMagnetAgent do
  @moduledoc """
  AI agent that transforms blog content into downloadable lead magnets.

  Supports multiple magnet types:
  - checklist: 10-15 actionable items grouped into sections
  - guide: 5-7 key sections with detailed explanations
  - cheatsheet: Quick-reference format with tables/bullet lists
  - template: Fill-in-the-blank templates
  - worksheet: Interactive exercises and worksheets
  """

  alias MarketMind.LLM.Gemini
  alias MarketMind.Content.Content
  alias MarketMind.Products.Project

  @lead_magnet_schema %{
    title: :string,
    description: :string,
    headline: :string,
    subheadline: :string,
    content: :string,
    cta_text: :string,
    thank_you_message: :string,
    meta_description: :string
  }

  @valid_types ~w(checklist guide cheatsheet template worksheet)

  @doc """
  Generates a lead magnet from blog content.

  ## Parameters

  - `project` - The project context for brand voice
  - `content` - The source blog content to transform
  - `magnet_type` - Type of lead magnet (checklist, guide, cheatsheet, template, worksheet)

  ## Returns

  - `{:ok, lead_magnet_attrs}` - Map with lead magnet attributes ready for creation
  - `{:error, reason}` - Error tuple on failure
  """
  def generate(%Project{} = project, %Content{} = content, magnet_type \\ "checklist") do
    with :ok <- validate_type(magnet_type),
         prompt <- build_prompt(project, content, magnet_type),
         {:ok, result} <- Gemini.complete_json(prompt, @lead_magnet_schema, max_tokens: 8192) do
      {:ok, normalize_result(result, content, magnet_type)}
    end
  end

  @doc """
  Returns the list of valid lead magnet types.
  """
  def valid_types, do: @valid_types

  # Private functions

  defp validate_type(type) when type in @valid_types, do: :ok
  defp validate_type(type), do: {:error, {:invalid_type, type}}

  defp build_prompt(project, content, magnet_type) do
    """
    You are an expert content marketer specializing in lead magnet creation.
    Your task is to transform a blog post into a highly valuable #{magnet_type} that readers will happily exchange their email for.

    ## Context

    **Product:** #{project.name}
    **Product Description:** #{project.description || "N/A"}
    **Brand Voice:** #{project.brand_voice || "professional and helpful"}
    **Tone:** #{project.tone || "informative"}

    ## Source Blog Post

    **Title:** #{content.title}
    **Target Keyword:** #{content.target_keyword || "N/A"}

    **Content:**
    #{content.body}

    ## Lead Magnet Type: #{String.upcase(magnet_type)}

    #{type_instructions(magnet_type)}

    ## Requirements

    Generate the following (respond with valid JSON only):

    1. **title**: Compelling, benefit-focused title (max 60 characters)
       - Include the primary value proposition
       - Use power words that create urgency or exclusivity

    2. **description**: 2-3 sentence description of what they'll receive
       - Focus on transformation/outcome
       - Be specific about deliverables

    3. **headline**: Landing page headline (max 80 characters)
       - Lead with the biggest benefit
       - Address the reader directly

    4. **subheadline**: Supporting text (1-2 sentences)
       - Expand on the headline
       - Add social proof or specificity

    5. **content**: The actual #{magnet_type} content in markdown format
       - Follow the type-specific instructions above
       - Make it actionable and immediately useful
       - Include all necessary context

    6. **cta_text**: Button text (max 25 characters)
       - Action-oriented
       - Create urgency without being pushy

    7. **thank_you_message**: Message shown after signup (2-3 sentences)
       - Confirm what they'll receive
       - Set expectations for delivery
       - Include a quick win or next step

    8. **meta_description**: SEO meta description (max 160 characters)
       - Include primary keyword if applicable
       - Compelling call to action

    Respond with valid JSON only. No markdown code blocks, no explanations.
    """
  end

  defp type_instructions("checklist") do
    """
    **CHECKLIST FORMAT REQUIREMENTS:**
    - Create 10-15 actionable checklist items
    - Group items into 3-4 logical sections with headers
    - Use markdown checkbox format: - [ ] Item description
    - Each item should be specific, actionable, and completable
    - Include brief context where helpful (2-3 words max)
    - Order items in logical sequence (chronological or priority)
    - End each section with a "quick win" item that's easy to complete

    **Example structure:**
    ## Section 1: Getting Started
    - [ ] First actionable item
    - [ ] Second actionable item

    ## Section 2: Core Tasks
    - [ ] Third actionable item
    ...
    """
  end

  defp type_instructions("guide") do
    """
    **MINI-GUIDE FORMAT REQUIREMENTS:**
    - Create 5-7 key sections with clear headers
    - Each section: H2 heading + 2-3 paragraphs of content
    - Include at least one practical example per section
    - Use bullet points for key takeaways
    - Include a "Quick Action Steps" box in each section
    - End with a clear summary and next steps
    - Total length: 1500-2500 words

    **Example structure:**
    ## Introduction
    Brief overview of what they'll learn...

    ## Section 1: [Topic]
    Detailed explanation...
    **Quick Action:** [Specific step to take]

    ## Conclusion
    Summary and next steps...
    """
  end

  defp type_instructions("cheatsheet") do
    """
    **CHEATSHEET FORMAT REQUIREMENTS:**
    - Design for quick reference (should fit on 1-2 printed pages)
    - Use tables for comparisons or reference data
    - Include bullet lists for easy scanning
    - Group related items with clear headers
    - Add "Pro Tips" callouts for advanced insights
    - Include formulas, shortcuts, or quick-reference values where applicable
    - Use bold for key terms and important values

    **Example structure:**
    ## Quick Reference: [Topic]

    | Term | Definition | Example |
    |------|------------|---------|
    | ... | ... | ... |

    ### Key Formulas
    - **Formula 1:** description
    - **Formula 2:** description

    ### Pro Tips
    > Tip 1: ...
    > Tip 2: ...
    """
  end

  defp type_instructions("template") do
    """
    **TEMPLATE FORMAT REQUIREMENTS:**
    - Create a fill-in-the-blank template
    - Use [PLACEHOLDER] format for fillable sections
    - Include example text in italics for each placeholder
    - Provide brief instructions before each section
    - Make it immediately usable after filling in
    - Include 5-10 customizable sections
    - Add a "Customization Tips" section at the end

    **Example structure:**
    ## [Template Name] Template

    ### Instructions
    Fill in each bracketed section with your specific information...

    ### Section 1: [Section Name]
    [YOUR TITLE HERE]
    *Example: "10 Ways to Improve Your Morning Routine"*

    ### Section 2: [Section Name]
    [YOUR DESCRIPTION HERE]
    *Example: "A step-by-step guide for busy professionals..."*

    ### Customization Tips
    - Tip 1: How to adapt this template
    - Tip 2: Common variations
    """
  end

  defp type_instructions("worksheet") do
    """
    **WORKSHEET FORMAT REQUIREMENTS:**
    - Create interactive exercises with clear instructions
    - Include 5-8 exercises or reflection questions
    - Provide space/prompts for written responses
    - Include scoring or self-assessment where applicable
    - Add progress tracking elements
    - Include a "Next Steps" section based on their answers
    - Make exercises progressive (build on each other)

    **Example structure:**
    ## [Worksheet Name] Worksheet

    ### Exercise 1: [Exercise Name]
    **Instructions:** Describe what to do...

    **Your Response:**
    _________________________________
    _________________________________

    **Reflection:** What did you learn from this exercise?
    _________________________________

    ### Exercise 2: [Exercise Name]
    ...

    ### Score Your Progress
    - Exercise 1: ⬜ Complete
    - Exercise 2: ⬜ Complete
    ...

    ### Next Steps Based on Your Answers
    - If you answered X: Try...
    - If you answered Y: Consider...
    """
  end

  defp type_instructions(_), do: "Create valuable, actionable content in the appropriate format."

  defp normalize_result(result, content, magnet_type) when is_map(result) do
    %{
      title: Map.get(result, "title", ""),
      description: Map.get(result, "description", ""),
      magnet_type: magnet_type,
      headline: Map.get(result, "headline", ""),
      subheadline: Map.get(result, "subheadline", ""),
      content: Map.get(result, "content", ""),
      cta_text: Map.get(result, "cta_text", "Get Free Access"),
      thank_you_message: Map.get(result, "thank_you_message", ""),
      meta_description: Map.get(result, "meta_description", ""),
      content_id: content.id
    }
  end
end
