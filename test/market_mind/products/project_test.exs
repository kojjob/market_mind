defmodule MarketMind.Products.ProjectTest do
  use MarketMind.DataCase, async: true

  alias MarketMind.Products.Project

  describe "changeset/2" do
    @valid_attrs %{
      name: "My Product",
      url: "https://example.com",
      description: "A great product",
      user_id: Ecto.UUID.generate()
    }

    test "valid changeset with required fields" do
      changeset = Project.changeset(%Project{}, @valid_attrs)
      assert changeset.valid?
    end

    test "invalid changeset without name" do
      attrs = Map.delete(@valid_attrs, :name)
      changeset = Project.changeset(%Project{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).name
    end

    test "invalid changeset without url" do
      attrs = Map.delete(@valid_attrs, :url)
      changeset = Project.changeset(%Project{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).url
    end

    test "invalid changeset without user_id" do
      attrs = Map.delete(@valid_attrs, :user_id)
      changeset = Project.changeset(%Project{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).user_id
    end

    test "validates url format - must start with http:// or https://" do
      invalid_urls = ["not-a-url", "ftp://example.com", "example.com", "http//missing-colon.com"]

      for url <- invalid_urls do
        attrs = %{@valid_attrs | url: url}
        changeset = Project.changeset(%Project{}, attrs)
        refute changeset.valid?, "Expected #{url} to be invalid"
        assert "must be a valid URL" in errors_on(changeset).url
      end
    end

    test "accepts valid urls" do
      valid_urls = [
        "https://example.com",
        "http://example.com",
        "https://subdomain.example.com",
        "https://example.com/path",
        "https://example.com/path?query=1"
      ]

      for url <- valid_urls do
        attrs = %{@valid_attrs | url: url}
        changeset = Project.changeset(%Project{}, attrs)
        assert changeset.valid?, "Expected #{url} to be valid, got errors: #{inspect(errors_on(changeset))}"
      end
    end

    test "generates slug from name" do
      changeset = Project.changeset(%Project{}, @valid_attrs)
      assert get_change(changeset, :slug) =~ "my-product"
    end

    test "generates unique slug with random suffix" do
      changeset1 = Project.changeset(%Project{}, @valid_attrs)
      changeset2 = Project.changeset(%Project{}, @valid_attrs)

      slug1 = get_change(changeset1, :slug)
      slug2 = get_change(changeset2, :slug)

      # Both should have the base slug
      assert slug1 =~ "my-product"
      assert slug2 =~ "my-product"

      # They should be different due to random suffix
      refute slug1 == slug2
    end

    test "handles special characters in name when generating slug" do
      attrs = %{@valid_attrs | name: "My Product! @#$% 123"}
      changeset = Project.changeset(%Project{}, attrs)
      slug = get_change(changeset, :slug)

      assert slug =~ "my-product-123"
      refute slug =~ "@"
      refute slug =~ "#"
    end

    test "sets default analysis_status to pending" do
      changeset = Project.changeset(%Project{}, @valid_attrs)
      assert get_field(changeset, :analysis_status) == "pending"
    end
  end

  describe "update_changeset/2" do
    setup do
      project = %Project{
        id: Ecto.UUID.generate(),
        name: "Original Name",
        url: "https://original.com",
        slug: "original-name-abc123",
        user_id: Ecto.UUID.generate(),
        analysis_status: "pending"
      }

      {:ok, project: project}
    end

    test "allows updating name and description", %{project: project} do
      changeset = Project.update_changeset(project, %{name: "New Name", description: "New desc"})
      assert changeset.valid?
      assert get_change(changeset, :name) == "New Name"
      assert get_change(changeset, :description) == "New desc"
    end

    test "does not allow changing slug on update", %{project: project} do
      changeset = Project.update_changeset(project, %{slug: "hacked-slug"})
      # Slug should not be in changes
      refute get_change(changeset, :slug)
    end

    test "does not allow changing user_id on update", %{project: project} do
      changeset = Project.update_changeset(project, %{user_id: Ecto.UUID.generate()})
      # user_id should not be in changes
      refute get_change(changeset, :user_id)
    end
  end

  describe "analysis_changeset/2" do
    setup do
      project = %Project{
        id: Ecto.UUID.generate(),
        name: "Test Product",
        url: "https://test.com",
        slug: "test-product-abc123",
        user_id: Ecto.UUID.generate(),
        analysis_status: "queued"
      }

      {:ok, project: project}
    end

    test "allows updating analysis_status", %{project: project} do
      changeset = Project.analysis_changeset(project, %{analysis_status: "analyzing"})
      assert changeset.valid?
      assert get_change(changeset, :analysis_status) == "analyzing"
    end

    test "validates analysis_status values", %{project: project} do
      valid_statuses = ["pending", "queued", "analyzing", "completed", "failed"]

      for status <- valid_statuses do
        changeset = Project.analysis_changeset(project, %{analysis_status: status})
        assert changeset.valid?, "Expected status '#{status}' to be valid"
      end
    end

    test "rejects invalid analysis_status", %{project: project} do
      changeset = Project.analysis_changeset(project, %{analysis_status: "invalid_status"})
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).analysis_status
    end

    test "allows setting analysis_data", %{project: project} do
      analysis_data = %{
        "product_name" => "Test",
        "tagline" => "Great product"
      }

      changeset = Project.analysis_changeset(project, %{
        analysis_status: "completed",
        analysis_data: analysis_data
      })

      assert changeset.valid?
      assert get_change(changeset, :analysis_data) == analysis_data
    end

    test "sets analyzed_at when status is completed", %{project: project} do
      changeset = Project.analysis_changeset(project, %{analysis_status: "completed"})
      assert get_change(changeset, :analyzed_at) != nil
    end

    test "does not set analyzed_at for non-completed status", %{project: project} do
      changeset = Project.analysis_changeset(project, %{analysis_status: "analyzing"})
      refute get_change(changeset, :analyzed_at)
    end
  end
end
