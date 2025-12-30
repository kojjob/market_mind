defmodule MarketMind.LeadMagnetsTest do
  use MarketMind.DataCase, async: true

  alias MarketMind.LeadMagnets
  alias MarketMind.LeadMagnets.LeadMagnet

  import MarketMind.Fixtures

  describe "list_lead_magnets/1" do
    test "returns all lead magnets for a project ordered by most recent first" do
      project = project_fixture()
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      # Use explicit timestamps with second-level differences for deterministic ordering
      lm1 = lead_magnet_fixture(project, %{
        title: "First Lead Magnet",
        inserted_at: DateTime.add(now, -2, :second)
      })
      lm2 = lead_magnet_fixture(project, %{
        title: "Second Lead Magnet",
        inserted_at: DateTime.add(now, -1, :second)
      })
      lm3 = lead_magnet_fixture(project, %{
        title: "Third Lead Magnet",
        inserted_at: now
      })

      result = LeadMagnets.list_lead_magnets(project)

      assert length(result) == 3
      assert Enum.map(result, & &1.id) == [lm3.id, lm2.id, lm1.id]
    end

    test "returns empty list when no lead magnets exist" do
      project = project_fixture()
      assert LeadMagnets.list_lead_magnets(project) == []
    end

    test "does not return lead magnets from other projects" do
      project1 = project_fixture()
      project2 = project_fixture()
      lead_magnet_fixture(project1)
      lead_magnet_fixture(project2)

      result = LeadMagnets.list_lead_magnets(project1)
      assert length(result) == 1
    end
  end

  describe "list_active_lead_magnets/1" do
    test "returns only active lead magnets" do
      project = project_fixture()
      _draft = lead_magnet_fixture(project, %{status: "draft"})
      active = active_lead_magnet_fixture(project)
      _archived = lead_magnet_fixture(project, %{status: "archived"})

      result = LeadMagnets.list_active_lead_magnets(project)

      assert length(result) == 1
      assert hd(result).id == active.id
    end

    test "returns empty list when no active lead magnets" do
      project = project_fixture()
      lead_magnet_fixture(project, %{status: "draft"})
      lead_magnet_fixture(project, %{status: "archived"})

      assert LeadMagnets.list_active_lead_magnets(project) == []
    end
  end

  describe "get_lead_magnet!/1" do
    test "returns the lead magnet with given id" do
      project = project_fixture()
      lead_magnet = lead_magnet_fixture(project)

      result = LeadMagnets.get_lead_magnet!(lead_magnet.id)
      assert result.id == lead_magnet.id
      assert result.title == lead_magnet.title
    end

    test "raises Ecto.NoResultsError for invalid id" do
      assert_raise Ecto.NoResultsError, fn ->
        LeadMagnets.get_lead_magnet!(Ecto.UUID.generate())
      end
    end
  end

  describe "get_lead_magnet_by_slug/2" do
    test "returns lead magnet by slug within project" do
      project = project_fixture()
      lead_magnet = lead_magnet_fixture(project, %{title: "My Test Lead Magnet"})

      result = LeadMagnets.get_lead_magnet_by_slug(project, lead_magnet.slug)
      assert result.id == lead_magnet.id
    end

    test "returns nil for non-existent slug" do
      project = project_fixture()
      assert LeadMagnets.get_lead_magnet_by_slug(project, "non-existent") == nil
    end

    test "returns nil for slug in different project" do
      project1 = project_fixture()
      project2 = project_fixture()
      lead_magnet = lead_magnet_fixture(project1, %{title: "Project One Lead Magnet"})

      assert LeadMagnets.get_lead_magnet_by_slug(project2, lead_magnet.slug) == nil
    end
  end

  describe "get_active_lead_magnet_by_slug!/2" do
    test "returns active lead magnet by slug" do
      project = project_fixture()
      lead_magnet = active_lead_magnet_fixture(project, %{title: "Active Lead Magnet"})

      result = LeadMagnets.get_active_lead_magnet_by_slug!(project, lead_magnet.slug)
      assert result.id == lead_magnet.id
    end

    test "raises for draft lead magnet" do
      project = project_fixture()
      lead_magnet = lead_magnet_fixture(project, %{status: "draft", title: "Draft Lead Magnet"})

      assert_raise Ecto.NoResultsError, fn ->
        LeadMagnets.get_active_lead_magnet_by_slug!(project, lead_magnet.slug)
      end
    end

    test "raises for archived lead magnet" do
      project = project_fixture()
      lead_magnet = lead_magnet_fixture(project, %{status: "archived", title: "Archived Lead Magnet"})

      assert_raise Ecto.NoResultsError, fn ->
        LeadMagnets.get_active_lead_magnet_by_slug!(project, lead_magnet.slug)
      end
    end
  end

  describe "get_active_lead_magnet_by_slugs!/2" do
    test "returns active lead magnet by project slug and lead magnet slug" do
      project = project_fixture()
      lead_magnet = active_lead_magnet_fixture(project, %{title: "Active Checklist"})

      result = LeadMagnets.get_active_lead_magnet_by_slugs!(project.slug, lead_magnet.slug)

      assert result.id == lead_magnet.id
      assert result.project.id == project.id
    end

    test "raises for non-active lead magnet" do
      project = project_fixture()
      lead_magnet = lead_magnet_fixture(project, %{status: "draft", title: "Draft Guide"})

      assert_raise Ecto.NoResultsError, fn ->
        LeadMagnets.get_active_lead_magnet_by_slugs!(project.slug, lead_magnet.slug)
      end
    end

    test "raises for non-existent project slug" do
      project = project_fixture()
      lead_magnet = active_lead_magnet_fixture(project)

      assert_raise Ecto.NoResultsError, fn ->
        LeadMagnets.get_active_lead_magnet_by_slugs!("non-existent-project", lead_magnet.slug)
      end
    end
  end

  describe "create_lead_magnet/2" do
    test "creates lead magnet with valid attributes" do
      project = project_fixture()

      attrs = %{
        title: "SEO Checklist",
        magnet_type: "checklist",
        description: "Complete SEO checklist for your website",
        headline: "Get Your Free SEO Checklist",
        content: "## Checklist\n\n- [ ] Item 1\n- [ ] Item 2"
      }

      assert {:ok, lead_magnet} = LeadMagnets.create_lead_magnet(project, attrs)
      assert lead_magnet.title == "SEO Checklist"
      assert lead_magnet.magnet_type == "checklist"
      assert lead_magnet.status == "draft"
      assert lead_magnet.slug == "seo-checklist"
      assert lead_magnet.project_id == project.id
    end

    test "auto-generates slug from title" do
      project = project_fixture()

      attrs = %{
        title: "The Ultimate Guide to Marketing",
        magnet_type: "guide"
      }

      {:ok, lead_magnet} = LeadMagnets.create_lead_magnet(project, attrs)
      assert lead_magnet.slug == "the-ultimate-guide-to-marketing"
    end

    test "creates with all optional fields" do
      project = project_fixture()

      attrs = %{
        title: "Complete Template Pack",
        magnet_type: "template",
        description: "All templates you need",
        headline: "Get Your Templates",
        subheadline: "Download now and start creating",
        cta_text: "Download Templates",
        thank_you_message: "Thanks! Check your email.",
        download_url: "https://example.com/download/templates.zip",
        meta_description: "Free marketing templates"
      }

      {:ok, lead_magnet} = LeadMagnets.create_lead_magnet(project, attrs)
      assert lead_magnet.headline == "Get Your Templates"
      assert lead_magnet.subheadline == "Download now and start creating"
      assert lead_magnet.cta_text == "Download Templates"
      assert lead_magnet.download_url == "https://example.com/download/templates.zip"
    end

    test "returns error for missing required fields" do
      project = project_fixture()

      assert {:error, changeset} = LeadMagnets.create_lead_magnet(project, %{})
      assert "can't be blank" in errors_on(changeset).title
      assert "can't be blank" in errors_on(changeset).magnet_type
    end

    test "returns error for invalid magnet_type" do
      project = project_fixture()

      attrs = %{
        title: "Test Lead Magnet",
        magnet_type: "invalid_type"
      }

      assert {:error, changeset} = LeadMagnets.create_lead_magnet(project, attrs)
      assert "must be one of: checklist, guide, cheatsheet, template, worksheet" in errors_on(changeset).magnet_type
    end

    test "validates all valid magnet types" do
      project = project_fixture()

      for type <- LeadMagnet.valid_types() do
        attrs = %{title: "Test #{type}", magnet_type: type}
        assert {:ok, _} = LeadMagnets.create_lead_magnet(project, attrs)
      end
    end

    test "enforces unique slug within project" do
      project = project_fixture()

      attrs = %{title: "Same Title", magnet_type: "checklist"}
      {:ok, _} = LeadMagnets.create_lead_magnet(project, attrs)

      assert {:error, changeset} = LeadMagnets.create_lead_magnet(project, attrs)
      assert "has already been taken" in errors_on(changeset).slug
    end

    test "allows same slug in different projects" do
      project1 = project_fixture()
      project2 = project_fixture()

      attrs = %{title: "Same Title", magnet_type: "checklist"}

      assert {:ok, lm1} = LeadMagnets.create_lead_magnet(project1, attrs)
      assert {:ok, lm2} = LeadMagnets.create_lead_magnet(project2, attrs)

      assert lm1.slug == lm2.slug
      assert lm1.project_id != lm2.project_id
    end
  end

  describe "update_lead_magnet/2" do
    test "updates lead magnet with valid attributes" do
      project = project_fixture()
      lead_magnet = lead_magnet_fixture(project)

      attrs = %{
        title: "Updated Title",
        description: "Updated description",
        headline: "New Headline"
      }

      assert {:ok, updated} = LeadMagnets.update_lead_magnet(lead_magnet, attrs)
      assert updated.title == "Updated Title"
      assert updated.description == "Updated description"
      assert updated.headline == "New Headline"
    end

    test "updates slug when title changes" do
      project = project_fixture()
      lead_magnet = lead_magnet_fixture(project, %{title: "Original Title"})

      {:ok, updated} = LeadMagnets.update_lead_magnet(lead_magnet, %{title: "Brand New Title"})
      assert updated.slug == "brand-new-title"
    end

    test "returns error for invalid status" do
      project = project_fixture()
      lead_magnet = lead_magnet_fixture(project)

      assert {:error, changeset} = LeadMagnets.update_lead_magnet(lead_magnet, %{status: "invalid"})
      assert "is invalid" in errors_on(changeset).status
    end
  end

  describe "delete_lead_magnet/1" do
    test "deletes the lead magnet" do
      project = project_fixture()
      lead_magnet = lead_magnet_fixture(project)

      assert {:ok, deleted} = LeadMagnets.delete_lead_magnet(lead_magnet)
      assert deleted.id == lead_magnet.id

      assert_raise Ecto.NoResultsError, fn ->
        LeadMagnets.get_lead_magnet!(lead_magnet.id)
      end
    end
  end

  describe "activate_lead_magnet/1" do
    test "changes status from draft to active" do
      project = project_fixture()
      lead_magnet = lead_magnet_fixture(project, %{status: "draft"})

      assert {:ok, activated} = LeadMagnets.activate_lead_magnet(lead_magnet)
      assert activated.status == "active"
    end

    test "can activate an archived lead magnet" do
      project = project_fixture()
      lead_magnet = lead_magnet_fixture(project, %{status: "archived"})

      assert {:ok, activated} = LeadMagnets.activate_lead_magnet(lead_magnet)
      assert activated.status == "active"
    end
  end

  describe "archive_lead_magnet/1" do
    test "changes status from active to archived" do
      project = project_fixture()
      lead_magnet = active_lead_magnet_fixture(project)

      assert {:ok, archived} = LeadMagnets.archive_lead_magnet(lead_magnet)
      assert archived.status == "archived"
    end

    test "can archive a draft lead magnet" do
      project = project_fixture()
      lead_magnet = lead_magnet_fixture(project, %{status: "draft"})

      assert {:ok, archived} = LeadMagnets.archive_lead_magnet(lead_magnet)
      assert archived.status == "archived"
    end
  end

  describe "increment_download_count/1" do
    test "increments download count by 1" do
      project = project_fixture()
      lead_magnet = lead_magnet_fixture(project)
      assert lead_magnet.download_count == 0

      {:ok, updated} = LeadMagnets.increment_download_count(lead_magnet)
      assert updated.download_count == 1

      {:ok, updated2} = LeadMagnets.increment_download_count(updated)
      assert updated2.download_count == 2
    end

    test "handles nil download_count gracefully" do
      project = project_fixture()
      lead_magnet = lead_magnet_fixture(project)
      # Simulate nil download_count (edge case)
      lead_magnet_with_nil = %{lead_magnet | download_count: nil}

      {:ok, updated} = LeadMagnets.increment_download_count(lead_magnet_with_nil)
      assert updated.download_count == 1
    end
  end

  describe "update_conversion_rate/2" do
    test "calculates conversion rate from page views" do
      project = project_fixture()
      lead_magnet = lead_magnet_fixture(project, %{download_count: 10})

      {:ok, updated} = LeadMagnets.update_conversion_rate(lead_magnet, 100)

      # 10 / 100 = 0.1
      assert Decimal.equal?(updated.conversion_rate, Decimal.new("0.1"))
    end

    test "returns lead magnet unchanged when page_views is 0" do
      project = project_fixture()
      lead_magnet = lead_magnet_fixture(project, %{download_count: 10})

      {:ok, result} = LeadMagnets.update_conversion_rate(lead_magnet, 0)
      assert result.id == lead_magnet.id
      # Conversion rate should not be updated
    end

    test "handles high conversion rate" do
      project = project_fixture()
      lead_magnet = lead_magnet_fixture(project, %{download_count: 50})

      {:ok, updated} = LeadMagnets.update_conversion_rate(lead_magnet, 100)

      # 50 / 100 = 0.5 (50% conversion)
      assert Decimal.equal?(updated.conversion_rate, Decimal.new("0.5"))
    end
  end

  describe "lead_magnet_count/2" do
    test "returns total count of lead magnets" do
      project = project_fixture()
      lead_magnet_fixture(project)
      lead_magnet_fixture(project)
      lead_magnet_fixture(project)

      assert LeadMagnets.lead_magnet_count(project) == 3
    end

    test "returns 0 when no lead magnets" do
      project = project_fixture()
      assert LeadMagnets.lead_magnet_count(project) == 0
    end

    test "filters by status when provided" do
      project = project_fixture()
      lead_magnet_fixture(project, %{status: "draft"})
      lead_magnet_fixture(project, %{status: "draft"})
      active_lead_magnet_fixture(project)
      lead_magnet_fixture(project, %{status: "archived"})

      assert LeadMagnets.lead_magnet_count(project, "draft") == 2
      assert LeadMagnets.lead_magnet_count(project, "active") == 1
      assert LeadMagnets.lead_magnet_count(project, "archived") == 1
    end
  end

  describe "total_downloads/1" do
    test "sums download counts across all lead magnets" do
      project = project_fixture()
      lead_magnet_fixture(project, %{download_count: 10})
      lead_magnet_fixture(project, %{download_count: 25})
      lead_magnet_fixture(project, %{download_count: 5})

      assert LeadMagnets.total_downloads(project) == 40
    end

    test "returns 0 when no lead magnets" do
      project = project_fixture()
      assert LeadMagnets.total_downloads(project) == 0
    end

    test "does not include downloads from other projects" do
      project1 = project_fixture()
      project2 = project_fixture()
      lead_magnet_fixture(project1, %{download_count: 100})
      lead_magnet_fixture(project2, %{download_count: 50})

      assert LeadMagnets.total_downloads(project1) == 100
      assert LeadMagnets.total_downloads(project2) == 50
    end
  end

  describe "lead_magnets_by_type/1" do
    test "groups lead magnets by type" do
      project = project_fixture()
      lead_magnet_fixture(project, %{magnet_type: "checklist"})
      lead_magnet_fixture(project, %{magnet_type: "checklist"})
      lead_magnet_fixture(project, %{magnet_type: "guide"})
      lead_magnet_fixture(project, %{magnet_type: "template"})

      result = LeadMagnets.lead_magnets_by_type(project)

      assert result["checklist"] == 2
      assert result["guide"] == 1
      assert result["template"] == 1
      assert result["cheatsheet"] == nil
    end

    test "returns empty map when no lead magnets" do
      project = project_fixture()
      assert LeadMagnets.lead_magnets_by_type(project) == %{}
    end
  end

  describe "top_performing_lead_magnets/2" do
    test "returns active lead magnets ordered by download count" do
      project = project_fixture()
      _lm1 = active_lead_magnet_fixture(project, %{title: "Low", download_count: 5})
      lm2 = active_lead_magnet_fixture(project, %{title: "Medium", download_count: 50})
      lm3 = active_lead_magnet_fixture(project, %{title: "High", download_count: 100})

      result = LeadMagnets.top_performing_lead_magnets(project)

      assert length(result) == 3
      assert Enum.map(result, & &1.id) == [lm3.id, lm2.id]
      |> Kernel.++([List.last(result).id])

      # Verify ordering by download count descending
      download_counts = Enum.map(result, & &1.download_count)
      assert download_counts == Enum.sort(download_counts, :desc)
    end

    test "respects limit parameter" do
      project = project_fixture()

      for i <- 1..10 do
        active_lead_magnet_fixture(project, %{title: "LM #{i}", download_count: i * 10})
      end

      result = LeadMagnets.top_performing_lead_magnets(project, 3)
      assert length(result) == 3

      # Top 3 should have highest download counts
      assert Enum.all?(result, fn lm -> lm.download_count >= 80 end)
    end

    test "excludes non-active lead magnets" do
      project = project_fixture()
      lead_magnet_fixture(project, %{status: "draft", download_count: 1000})
      lead_magnet_fixture(project, %{status: "archived", download_count: 500})
      active = active_lead_magnet_fixture(project, %{download_count: 10})

      result = LeadMagnets.top_performing_lead_magnets(project)

      assert length(result) == 1
      assert hd(result).id == active.id
    end

    test "returns empty list when no active lead magnets" do
      project = project_fixture()
      lead_magnet_fixture(project, %{status: "draft"})

      assert LeadMagnets.top_performing_lead_magnets(project) == []
    end
  end

  describe "get_lead_magnet_with_source!/1" do
    test "returns lead magnet with source content preloaded" do
      project = project_fixture()
      lead_magnet = lead_magnet_fixture(project)

      result = LeadMagnets.get_lead_magnet_with_source!(lead_magnet.id)

      assert result.id == lead_magnet.id
      # source_content is preloaded (nil since no content_id set in fixture)
      assert Map.has_key?(result, :source_content)
    end

    test "raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        LeadMagnets.get_lead_magnet_with_source!(Ecto.UUID.generate())
      end
    end
  end

  describe "list_lead_magnets_for_content/1" do
    test "returns lead magnets created from specific content" do
      project = project_fixture()
      content = content_fixture(project)

      # Create lead magnets linked to content
      lm1 = lead_magnet_fixture(project, %{content_id: Ecto.UUID.dump!(content.id)})
      lm2 = lead_magnet_fixture(project, %{content_id: Ecto.UUID.dump!(content.id)})
      _unlinked = lead_magnet_fixture(project)

      result = LeadMagnets.list_lead_magnets_for_content(content.id)

      assert length(result) == 2
      assert Enum.all?(result, fn lm -> lm.id in [lm1.id, lm2.id] end)
    end

    test "returns empty list when no lead magnets for content" do
      project = project_fixture()
      lead_magnet_fixture(project)

      result = LeadMagnets.list_lead_magnets_for_content(Ecto.UUID.generate())
      assert result == []
    end
  end

  describe "LeadMagnet schema" do
    test "valid_types/0 returns all valid magnet types" do
      types = LeadMagnet.valid_types()

      assert "checklist" in types
      assert "guide" in types
      assert "cheatsheet" in types
      assert "template" in types
      assert "worksheet" in types
      assert length(types) == 5
    end

    test "valid_statuses/0 returns all valid statuses" do
      statuses = LeadMagnet.valid_statuses()

      assert "draft" in statuses
      assert "active" in statuses
      assert "archived" in statuses
      assert length(statuses) == 3
    end

    test "default values are set correctly" do
      project = project_fixture()
      {:ok, lead_magnet} = LeadMagnets.create_lead_magnet(project, %{
        title: "Test",
        magnet_type: "checklist"
      })

      assert lead_magnet.status == "draft"
      assert lead_magnet.download_count == 0
      assert lead_magnet.cta_text == "Get Free Access"
    end
  end
end
