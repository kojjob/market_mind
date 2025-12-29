defmodule MarketMind.ContentTest do
  use MarketMind.DataCase

  alias MarketMind.Content
  alias MarketMind.Content.Content, as: ContentSchema
  alias MarketMind.Products
  alias MarketMind.Personas

  describe "contents" do
    @valid_attrs %{
      title: "10 Ways to Boost Your SaaS Growth",
      content_type: "blog_post",
      status: "draft",
      body: """
      Introduction to SaaS growth strategies.

      ## Strategy 1: Focus on Customer Success
      Customer success is the foundation of sustainable growth.

      ## Strategy 2: Optimize Your Onboarding
      First impressions matter. Make your onboarding seamless.

      ## Conclusion
      Implement these strategies to see measurable results.
      """,
      meta_description: "Discover 10 proven strategies to accelerate your SaaS growth.",
      target_keyword: "SaaS growth",
      secondary_keywords: ["startup growth", "B2B marketing", "customer acquisition"]
    }

    @update_attrs %{
      title: "Updated: 15 Ways to Boost Your SaaS Growth",
      status: "pending_review"
    }

    @invalid_attrs %{title: nil, project_id: nil}

    def user_fixture do
      MarketMind.Fixtures.user_fixture()
    end

    def project_fixture(attrs \\ %{}) do
      user = user_fixture()

      {:ok, project} =
        attrs
        |> Enum.into(%{
          name: "Test Project",
          url: "https://test.com",
          description: "A test project for content testing"
        })
        |> then(&Products.create_project(user, &1))

      project
    end

    def persona_fixture(project, attrs \\ %{}) do
      attrs =
        Enum.into(attrs, %{
          name: "SaaS Founder",
          role: "Founder",
          description: "A busy founder looking for growth.",
          demographics: %{"age_range" => "25-40", "location" => "Global"},
          goals: ["Scale revenue", "Automate marketing"],
          pain_points: ["No time", "High CAC"],
          is_primary: true
        })

      {:ok, persona} = Personas.create_persona(project, attrs)
      persona
    end

    def content_fixture(project, attrs \\ %{}) do
      attrs = Enum.into(attrs, @valid_attrs)
      {:ok, content} = Content.create_content(project, attrs)
      content
    end

    test "list_contents/1 returns all contents for a project" do
      project = project_fixture()
      content = content_fixture(project)

      contents = Content.list_contents(project)
      assert length(contents) == 1
      assert hd(contents).id == content.id
    end

    test "list_contents/1 does not return contents from other projects" do
      project1 = project_fixture()
      project2 = project_fixture(%{name: "Other Project", url: "https://other.com"})

      _content1 = content_fixture(project1)
      content2 = content_fixture(project2, %{title: "Other Content"})

      contents = Content.list_contents(project2)
      assert length(contents) == 1
      assert hd(contents).id == content2.id
    end

    test "get_content!/1 returns the content with given id" do
      project = project_fixture()
      content = content_fixture(project)

      fetched = Content.get_content!(content.id)
      assert fetched.id == content.id
      assert fetched.title == content.title
    end

    test "get_content!/1 raises for non-existent content" do
      assert_raise Ecto.NoResultsError, fn ->
        Content.get_content!(Ecto.UUID.generate())
      end
    end

    test "create_content/2 with valid data creates a content" do
      project = project_fixture()

      assert {:ok, %ContentSchema{} = content} = Content.create_content(project, @valid_attrs)
      assert content.title == "10 Ways to Boost Your SaaS Growth"
      assert content.content_type == "blog_post"
      assert content.status == "draft"
      assert content.meta_description == "Discover 10 proven strategies to accelerate your SaaS growth."
      assert content.target_keyword == "SaaS growth"
      assert content.secondary_keywords == ["startup growth", "B2B marketing", "customer acquisition"]
      assert content.project_id == project.id
    end

    test "create_content/2 generates a slug from the title" do
      project = project_fixture()

      {:ok, content} = Content.create_content(project, @valid_attrs)
      assert content.slug =~ ~r/^10-ways-to-boost-your-saas-growth-\d+$/
    end

    test "create_content/2 calculates word count and reading time" do
      project = project_fixture()

      {:ok, content} = Content.create_content(project, @valid_attrs)
      assert content.word_count > 0
      assert content.reading_time_minutes >= 1
    end

    test "create_content/2 with persona associates the persona" do
      project = project_fixture()
      persona = persona_fixture(project)

      attrs = Map.put(@valid_attrs, :persona_id, persona.id)
      {:ok, content} = Content.create_content(project, attrs)

      assert content.persona_id == persona.id
    end

    test "create_content/2 with invalid data returns error changeset" do
      project = project_fixture()

      assert {:error, %Ecto.Changeset{}} = Content.create_content(project, @invalid_attrs)
    end

    test "create_content/2 validates content_type inclusion" do
      project = project_fixture()
      attrs = Map.put(@valid_attrs, :content_type, "invalid_type")

      assert {:error, changeset} = Content.create_content(project, attrs)
      assert "is invalid" in errors_on(changeset).content_type
    end

    test "create_content/2 validates status inclusion" do
      project = project_fixture()
      attrs = Map.put(@valid_attrs, :status, "invalid_status")

      assert {:error, changeset} = Content.create_content(project, attrs)
      assert "is invalid" in errors_on(changeset).status
    end

    test "create_content/2 validates title length" do
      project = project_fixture()
      long_title = String.duplicate("a", 201)
      attrs = Map.put(@valid_attrs, :title, long_title)

      assert {:error, changeset} = Content.create_content(project, attrs)
      assert "should be at most 200 character(s)" in errors_on(changeset).title
    end

    test "create_content/2 validates meta_description length" do
      project = project_fixture()
      long_desc = String.duplicate("a", 161)
      attrs = Map.put(@valid_attrs, :meta_description, long_desc)

      assert {:error, changeset} = Content.create_content(project, attrs)
      assert "should be at most 160 character(s)" in errors_on(changeset).meta_description
    end

    test "update_content/2 with valid data updates the content" do
      project = project_fixture()
      content = content_fixture(project)

      assert {:ok, %ContentSchema{} = updated} = Content.update_content(content, @update_attrs)
      assert updated.title == "Updated: 15 Ways to Boost Your SaaS Growth"
      assert updated.status == "pending_review"
    end

    test "update_content/2 regenerates slug when title changes" do
      project = project_fixture()
      content = content_fixture(project)
      original_slug = content.slug

      {:ok, updated} = Content.update_content(content, %{title: "New Title Here"})
      assert updated.slug =~ ~r/^new-title-here-\d+$/
      assert updated.slug != original_slug
    end

    test "update_content/2 with invalid data returns error changeset" do
      project = project_fixture()
      content = content_fixture(project)

      assert {:error, %Ecto.Changeset{}} = Content.update_content(content, @invalid_attrs)
      assert Content.get_content!(content.id).title == content.title
    end

    test "delete_content/1 deletes the content" do
      project = project_fixture()
      content = content_fixture(project)

      assert {:ok, %ContentSchema{}} = Content.delete_content(content)
      assert_raise Ecto.NoResultsError, fn -> Content.get_content!(content.id) end
    end

    test "change_content/1 returns a content changeset" do
      project = project_fixture()
      content = content_fixture(project)

      assert %Ecto.Changeset{} = Content.change_content(content)
    end

    test "update_content_status/2 updates only the status" do
      project = project_fixture()
      content = content_fixture(project)

      assert {:ok, updated} = Content.update_content_status(content, "approved")
      assert updated.status == "approved"
      assert updated.title == content.title
    end

    test "update_content_status/2 validates status value" do
      project = project_fixture()
      content = content_fixture(project)

      assert {:error, changeset} = Content.update_content_status(content, "invalid_status")
      assert "is invalid" in errors_on(changeset).status
    end

    test "list_contents_by_persona/1 returns contents for a specific persona" do
      project = project_fixture()
      persona1 = persona_fixture(project)
      persona2 = persona_fixture(project, %{name: "Enterprise Emma", is_primary: false})

      content1 = content_fixture(project, %{persona_id: persona1.id})
      _content2 = content_fixture(project, %{title: "Other Content", persona_id: persona2.id})

      contents = Content.list_contents_by_persona(persona1)
      assert length(contents) == 1
      assert hd(contents).id == content1.id
    end

    test "list_contents_by_status/2 returns contents with specific status" do
      project = project_fixture()
      content1 = content_fixture(project)
      {:ok, content2} = Content.update_content_status(content_fixture(project, %{title: "Published Post"}), "published")

      drafts = Content.list_contents_by_status(project, "draft")
      assert length(drafts) == 1
      assert hd(drafts).id == content1.id

      published = Content.list_contents_by_status(project, "published")
      assert length(published) == 1
      assert hd(published).id == content2.id
    end
  end
end
