defmodule MarketMind.PersonasTest do
  use MarketMind.DataCase

  alias MarketMind.Personas
  alias MarketMind.Personas.Persona
  alias MarketMind.Products

  describe "personas" do
    @valid_attrs %{
      name: "SaaS Founder",
      role: "Founder",
      description: "A busy founder looking for growth.",
      demographics: %{"age_range" => "25-40", "location" => "Global"},
      goals: ["Scale revenue", "Automate marketing"],
      pain_points: ["No time", "High CAC"],
      objections: ["Too expensive", "Complex setup"],
      motivations: ["Freedom", "Impact"],
      channels: ["Twitter", "LinkedIn"],
      keywords: ["growth", "automation"],
      personality_traits: %{"openness" => "High", "conscientiousness" => "High"},
      is_primary: true
    }
    @update_attrs %{
      name: "Updated Founder",
      role: "CEO"
    }
    @invalid_attrs %{name: nil, role: nil}

    def project_fixture(attrs \\ %{}) do
      user = MarketMind.Fixtures.user_fixture()

      {:ok, project} =
        attrs
        |> Enum.into(%{
          name: "Test Project",
          url: "https://test.com",
          description: "A test project"
        })
        |> then(&Products.create_project(user, &1))

      project
    end

    def persona_fixture(project, attrs \\ %{}) do
      attrs = Enum.into(attrs, @valid_attrs)
      {:ok, persona} = Personas.create_persona(project, attrs)

      persona
    end

    test "list_personas/1 returns all personas for a project" do
      project = project_fixture()
      persona = persona_fixture(project)
      assert Personas.list_personas(project) == [persona]
    end

    test "get_persona!/1 returns the persona with given id" do
      project = project_fixture()
      persona = persona_fixture(project)
      assert Personas.get_persona!(persona.id) == persona
    end

    test "create_persona/2 with valid data creates a persona" do
      project = project_fixture()
      assert {:ok, %Persona{} = persona} = Personas.create_persona(project, @valid_attrs)
      assert persona.name == "SaaS Founder"
      assert persona.role == "Founder"
      assert persona.demographics == %{"age_range" => "25-40", "location" => "Global"}
      assert persona.goals == ["Scale revenue", "Automate marketing"]
      assert persona.project_id == project.id
    end

    test "create_persona/2 with invalid data returns error changeset" do
      project = project_fixture()
      assert {:error, %Ecto.Changeset{}} = Personas.create_persona(project, @invalid_attrs)
    end

    test "update_persona/2 with valid data updates the persona" do
      project = project_fixture()
      persona = persona_fixture(project)
      assert {:ok, %Persona{} = persona} = Personas.update_persona(persona, @update_attrs)
      assert persona.name == "Updated Founder"
      assert persona.role == "CEO"
    end

    test "update_persona/2 with invalid data returns error changeset" do
      project = project_fixture()
      persona = persona_fixture(project)
      assert {:error, %Ecto.Changeset{}} = Personas.update_persona(persona, @invalid_attrs)
      assert persona == Personas.get_persona!(persona.id)
    end

    test "delete_persona/1 deletes the persona" do
      project = project_fixture()
      persona = persona_fixture(project)
      assert {:ok, %Persona{}} = Personas.delete_persona(persona)
      assert_raise Ecto.NoResultsError, fn -> Personas.get_persona!(persona.id) end
    end

    test "change_persona/1 returns a persona changeset" do
      project = project_fixture()
      persona = persona_fixture(project)
      assert %Ecto.Changeset{} = Personas.change_persona(persona)
    end
  end
end
