defmodule MarketMind.LeadsTest do
  use MarketMind.DataCase, async: true

  alias MarketMind.Leads
  import MarketMind.Fixtures

  describe "list_subscribers/1" do
    test "returns all subscribers for a project ordered by most recent first" do
      project = project_fixture()
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      # Use explicit timestamps for deterministic ordering
      sub1 = subscriber_fixture(project, %{
        email: "first@example.com",
        inserted_at: DateTime.add(now, -2, :second)
      })
      _sub2 = subscriber_fixture(project, %{
        email: "second@example.com",
        inserted_at: DateTime.add(now, -1, :second)
      })
      sub3 = subscriber_fixture(project, %{
        email: "third@example.com",
        inserted_at: now
      })

      result = Leads.list_subscribers(project)

      assert length(result) == 3
      # Most recent first
      assert hd(result).id == sub3.id
      assert List.last(result).id == sub1.id
    end

    test "returns empty list when project has no subscribers" do
      project = project_fixture()

      assert Leads.list_subscribers(project) == []
    end

    test "only returns subscribers for the specified project" do
      project1 = project_fixture()
      project2 = project_fixture()

      subscriber_fixture(project1, %{email: "project1@example.com"})
      subscriber_fixture(project2, %{email: "project2@example.com"})

      result = Leads.list_subscribers(project1)

      assert length(result) == 1
      assert hd(result).email == "project1@example.com"
    end
  end

  describe "list_confirmed_subscribers/1" do
    test "returns only confirmed subscribers" do
      project = project_fixture()

      _pending = subscriber_fixture(project, %{email: "pending@example.com", status: "pending"})
      confirmed = confirmed_subscriber_fixture(project, %{email: "confirmed@example.com"})
      _unsubscribed = subscriber_fixture(project, %{email: "unsub@example.com", status: "unsubscribed"})

      result = Leads.list_confirmed_subscribers(project)

      assert length(result) == 1
      assert hd(result).id == confirmed.id
    end

    test "returns empty list when no confirmed subscribers" do
      project = project_fixture()
      subscriber_fixture(project, %{status: "pending"})

      assert Leads.list_confirmed_subscribers(project) == []
    end
  end

  describe "list_subscribers_by_tag/2" do
    test "returns confirmed subscribers with the specified tag" do
      project = project_fixture()

      sub1 = confirmed_subscriber_fixture(project, %{email: "tagged1@example.com", tags: ["vip", "early-adopter"]})
      _sub2 = confirmed_subscriber_fixture(project, %{email: "tagged2@example.com", tags: ["regular"]})
      sub3 = confirmed_subscriber_fixture(project, %{email: "tagged3@example.com", tags: ["vip"]})

      result = Leads.list_subscribers_by_tag(project, "vip")

      assert length(result) == 2
      result_ids = Enum.map(result, & &1.id)
      assert sub1.id in result_ids
      assert sub3.id in result_ids
    end

    test "excludes pending and unsubscribed subscribers even with matching tags" do
      project = project_fixture()

      _pending = subscriber_fixture(project, %{email: "pending@example.com", status: "pending", tags: ["vip"]})
      confirmed = confirmed_subscriber_fixture(project, %{email: "confirmed@example.com", tags: ["vip"]})

      result = Leads.list_subscribers_by_tag(project, "vip")

      assert length(result) == 1
      assert hd(result).id == confirmed.id
    end
  end

  describe "get_subscriber!/1" do
    test "returns subscriber by id" do
      project = project_fixture()
      subscriber = subscriber_fixture(project)

      result = Leads.get_subscriber!(subscriber.id)

      assert result.id == subscriber.id
      assert result.email == subscriber.email
    end

    test "raises when subscriber not found" do
      assert_raise Ecto.NoResultsError, fn ->
        Leads.get_subscriber!(Ecto.UUID.generate())
      end
    end
  end

  describe "get_subscriber/1" do
    test "returns subscriber by id" do
      project = project_fixture()
      subscriber = subscriber_fixture(project)

      assert {:ok, result} = {:ok, Leads.get_subscriber(subscriber.id)}
      assert result.id == subscriber.id
    end

    test "returns nil when subscriber not found" do
      assert Leads.get_subscriber(Ecto.UUID.generate()) == nil
    end
  end

  describe "get_subscriber_by_email/2" do
    test "returns subscriber by email for project" do
      project = project_fixture()
      subscriber = subscriber_fixture(project, %{email: "test@example.com"})

      result = Leads.get_subscriber_by_email(project, "test@example.com")

      assert result.id == subscriber.id
    end

    test "normalizes email for lookup (case insensitive)" do
      project = project_fixture()
      subscriber = subscriber_fixture(project, %{email: "test@example.com"})

      result = Leads.get_subscriber_by_email(project, "  TEST@EXAMPLE.COM  ")

      assert result.id == subscriber.id
    end

    test "returns nil when email not found in project" do
      project = project_fixture()
      subscriber_fixture(project, %{email: "exists@example.com"})

      assert Leads.get_subscriber_by_email(project, "notexists@example.com") == nil
    end

    test "does not return subscriber from different project" do
      project1 = project_fixture()
      project2 = project_fixture()
      subscriber_fixture(project1, %{email: "test@example.com"})

      assert Leads.get_subscriber_by_email(project2, "test@example.com") == nil
    end
  end

  describe "create_subscriber/3" do
    test "creates subscriber with valid attributes" do
      project = project_fixture()
      attrs = %{email: "new@example.com", first_name: "John", source: "lead_magnet"}

      assert {:ok, subscriber} = Leads.create_subscriber(project, attrs)
      assert subscriber.email == "new@example.com"
      assert subscriber.first_name == "John"
      assert subscriber.source == "lead_magnet"
      assert subscriber.status == "pending"
      assert subscriber.project_id == project.id
    end

    test "normalizes email to lowercase" do
      project = project_fixture()
      attrs = %{email: "  UPPER@EXAMPLE.COM  ", source: "manual"}

      assert {:ok, subscriber} = Leads.create_subscriber(project, attrs)
      assert subscriber.email == "upper@example.com"
    end

    test "records GDPR consent information" do
      project = project_fixture()
      attrs = %{email: "consent@example.com", source: "lead_magnet"}
      consent_info = %{ip: "192.168.1.1", user_agent: "Mozilla/5.0"}

      assert {:ok, subscriber} = Leads.create_subscriber(project, attrs, consent_info)
      assert subscriber.consent_ip == "192.168.1.1"
      assert subscriber.consent_user_agent == "Mozilla/5.0"
      assert subscriber.consent_given_at != nil
    end

    test "fails with invalid email format" do
      project = project_fixture()
      attrs = %{email: "invalid-email", source: "manual"}

      assert {:error, changeset} = Leads.create_subscriber(project, attrs)
      assert "must be a valid email" in errors_on(changeset).email
    end

    test "fails with missing email" do
      project = project_fixture()
      attrs = %{first_name: "John", source: "manual"}

      assert {:error, changeset} = Leads.create_subscriber(project, attrs)
      assert "can't be blank" in errors_on(changeset).email
    end

    test "fails with invalid source" do
      project = project_fixture()
      attrs = %{email: "test@example.com", source: "invalid_source"}

      assert {:error, changeset} = Leads.create_subscriber(project, attrs)
      assert errors_on(changeset).source != []
    end

    test "fails with duplicate email in same project" do
      project = project_fixture()
      subscriber_fixture(project, %{email: "duplicate@example.com"})

      attrs = %{email: "duplicate@example.com", source: "manual"}

      assert {:error, changeset} = Leads.create_subscriber(project, attrs)
      assert "is already subscribed" in errors_on(changeset).email
    end

    test "allows same email in different projects" do
      project1 = project_fixture()
      project2 = project_fixture()
      subscriber_fixture(project1, %{email: "shared@example.com"})

      attrs = %{email: "shared@example.com", source: "manual"}

      assert {:ok, subscriber} = Leads.create_subscriber(project2, attrs)
      assert subscriber.email == "shared@example.com"
      assert subscriber.project_id == project2.id
    end
  end

  describe "update_subscriber/2" do
    test "updates subscriber with valid attributes" do
      project = project_fixture()
      subscriber = subscriber_fixture(project, %{first_name: "Original"})

      assert {:ok, updated} = Leads.update_subscriber(subscriber, %{first_name: "Updated"})
      assert updated.first_name == "Updated"
    end

    test "updates metadata" do
      project = project_fixture()
      subscriber = subscriber_fixture(project, %{metadata: %{}})

      new_metadata = %{"company" => "Acme", "role" => "Developer"}
      assert {:ok, updated} = Leads.update_subscriber(subscriber, %{metadata: new_metadata})
      assert updated.metadata == new_metadata
    end

    test "fails with invalid email" do
      project = project_fixture()
      subscriber = subscriber_fixture(project)

      assert {:error, changeset} = Leads.update_subscriber(subscriber, %{email: "invalid"})
      assert "must be a valid email" in errors_on(changeset).email
    end
  end

  describe "delete_subscriber/1" do
    test "deletes subscriber" do
      project = project_fixture()
      subscriber = subscriber_fixture(project)

      assert {:ok, deleted} = Leads.delete_subscriber(subscriber)
      assert deleted.id == subscriber.id
      assert Leads.get_subscriber(subscriber.id) == nil
    end
  end

  describe "confirm_subscriber/1" do
    test "confirms pending subscriber" do
      project = project_fixture()
      subscriber = subscriber_fixture(project, %{status: "pending"})

      assert {:ok, confirmed} = Leads.confirm_subscriber(subscriber)
      assert confirmed.status == "confirmed"
      assert confirmed.confirmed_at != nil
    end

    test "can re-confirm already confirmed subscriber" do
      project = project_fixture()
      subscriber = confirmed_subscriber_fixture(project)
      original_confirmed_at = subscriber.confirmed_at

      Process.sleep(1000)
      assert {:ok, reconfirmed} = Leads.confirm_subscriber(subscriber)
      assert reconfirmed.status == "confirmed"
      # Timestamp should be updated
      assert reconfirmed.confirmed_at != original_confirmed_at
    end
  end

  describe "unsubscribe/1" do
    test "unsubscribes confirmed subscriber" do
      project = project_fixture()
      subscriber = confirmed_subscriber_fixture(project)

      assert {:ok, unsubscribed} = Leads.unsubscribe(subscriber)
      assert unsubscribed.status == "unsubscribed"
      assert unsubscribed.unsubscribed_at != nil
    end

    test "unsubscribes pending subscriber" do
      project = project_fixture()
      subscriber = subscriber_fixture(project, %{status: "pending"})

      assert {:ok, unsubscribed} = Leads.unsubscribe(subscriber)
      assert unsubscribed.status == "unsubscribed"
    end
  end

  describe "add_tags/2" do
    test "adds tags to subscriber" do
      project = project_fixture()
      subscriber = subscriber_fixture(project, %{tags: []})

      assert {:ok, tagged} = Leads.add_tags(subscriber, ["vip", "beta-tester"])
      assert "vip" in tagged.tags
      assert "beta-tester" in tagged.tags
    end

    test "merges with existing tags" do
      project = project_fixture()
      subscriber = subscriber_fixture(project, %{tags: ["existing"]})

      assert {:ok, tagged} = Leads.add_tags(subscriber, ["new"])
      assert "existing" in tagged.tags
      assert "new" in tagged.tags
    end

    test "removes duplicate tags" do
      project = project_fixture()
      subscriber = subscriber_fixture(project, %{tags: ["vip"]})

      assert {:ok, tagged} = Leads.add_tags(subscriber, ["vip", "new"])
      assert tagged.tags == ["vip", "new"]
    end
  end

  describe "remove_tags/2" do
    test "removes specified tags" do
      project = project_fixture()
      subscriber = subscriber_fixture(project, %{tags: ["vip", "beta", "early"]})

      assert {:ok, updated} = Leads.remove_tags(subscriber, ["beta", "early"])
      assert updated.tags == ["vip"]
    end

    test "handles removing non-existent tags gracefully" do
      project = project_fixture()
      subscriber = subscriber_fixture(project, %{tags: ["existing"]})

      assert {:ok, updated} = Leads.remove_tags(subscriber, ["nonexistent"])
      assert updated.tags == ["existing"]
    end

    test "can remove all tags" do
      project = project_fixture()
      subscriber = subscriber_fixture(project, %{tags: ["one", "two"]})

      assert {:ok, updated} = Leads.remove_tags(subscriber, ["one", "two"])
      assert updated.tags == []
    end
  end

  describe "subscriber_count/2" do
    test "returns total subscriber count" do
      project = project_fixture()
      subscriber_fixture(project, %{status: "pending"})
      confirmed_subscriber_fixture(project)
      subscriber_fixture(project, %{status: "unsubscribed"})

      assert Leads.subscriber_count(project) == 3
    end

    test "returns count filtered by status" do
      project = project_fixture()
      subscriber_fixture(project, %{status: "pending"})
      confirmed_subscriber_fixture(project)
      confirmed_subscriber_fixture(project, %{email: "confirmed2@example.com"})

      assert Leads.subscriber_count(project, "confirmed") == 2
      assert Leads.subscriber_count(project, "pending") == 1
    end

    test "returns 0 for project with no subscribers" do
      project = project_fixture()

      assert Leads.subscriber_count(project) == 0
    end
  end

  describe "subscriber_stats/1" do
    test "returns counts grouped by status" do
      project = project_fixture()
      subscriber_fixture(project, %{status: "pending"})
      subscriber_fixture(project, %{status: "pending", email: "pending2@example.com"})
      confirmed_subscriber_fixture(project)
      subscriber_fixture(project, %{status: "unsubscribed"})

      stats = Leads.subscriber_stats(project)

      assert stats["pending"] == 2
      assert stats["confirmed"] == 1
      assert stats["unsubscribed"] == 1
    end

    test "returns empty map for project with no subscribers" do
      project = project_fixture()

      assert Leads.subscriber_stats(project) == %{}
    end
  end

  describe "subscribers_by_source/1" do
    test "returns counts grouped by source" do
      project = project_fixture()
      subscriber_fixture(project, %{source: "lead_magnet"})
      subscriber_fixture(project, %{source: "lead_magnet", email: "lm2@example.com"})
      subscriber_fixture(project, %{source: "blog"})
      subscriber_fixture(project, %{source: "manual"})

      by_source = Leads.subscribers_by_source(project)

      assert by_source["lead_magnet"] == 2
      assert by_source["blog"] == 1
      assert by_source["manual"] == 1
    end
  end

  describe "recent_subscribers/2" do
    test "returns most recent subscribers with default limit" do
      project = project_fixture()
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      # Create 15 subscribers with explicit timestamps for deterministic ordering
      subscribers =
        for i <- 1..15 do
          subscriber_fixture(project, %{
            email: "sub#{i}@example.com",
            inserted_at: DateTime.add(now, i - 15, :second)
          })
        end

      recent = Leads.recent_subscribers(project)

      # Default limit is 10
      assert length(recent) == 10
      # Most recent first (sub15 should be first)
      assert hd(recent).id == List.last(subscribers).id
    end

    test "respects custom limit" do
      project = project_fixture()
      for i <- 1..10, do: subscriber_fixture(project, %{email: "sub#{i}@example.com"})

      assert length(Leads.recent_subscribers(project, 3)) == 3
    end
  end

  describe "import_subscribers/3" do
    test "imports valid subscribers in bulk" do
      project = project_fixture()

      data = [
        %{email: "import1@example.com", first_name: "Import1"},
        %{email: "import2@example.com", first_name: "Import2"},
        %{email: "import3@example.com", first_name: "Import3"}
      ]

      assert {:ok, count} = Leads.import_subscribers(project, data)
      assert count == 3
      assert Leads.subscriber_count(project) == 3
    end

    test "normalizes emails during import" do
      project = project_fixture()
      data = [%{email: "  UPPER@EXAMPLE.COM  ", first_name: "Test"}]

      assert {:ok, 1} = Leads.import_subscribers(project, data)
      assert Leads.get_subscriber_by_email(project, "upper@example.com") != nil
    end

    test "records consent information during import" do
      project = project_fixture()
      data = [%{email: "consent@example.com", first_name: "Test"}]
      consent = %{ip: "10.0.0.1", user_agent: "Import Script"}

      assert {:ok, 1} = Leads.import_subscribers(project, data, consent)

      subscriber = Leads.get_subscriber_by_email(project, "consent@example.com")
      assert subscriber.consent_ip == "10.0.0.1"
      assert subscriber.consent_user_agent == "Import Script"
    end

    test "skips invalid emails" do
      project = project_fixture()

      data = [
        %{email: "valid@example.com", first_name: "Valid"},
        %{email: "invalid", first_name: "Invalid"},
        %{email: "", first_name: "Empty"},
        %{email: "another@valid.com", first_name: "Another"}
      ]

      assert {:ok, count} = Leads.import_subscribers(project, data)
      # Only 2 valid emails
      assert count == 2
    end

    test "handles duplicate emails on conflict" do
      project = project_fixture()
      subscriber_fixture(project, %{email: "existing@example.com"})

      data = [
        %{email: "existing@example.com", first_name: "Duplicate"},
        %{email: "new@example.com", first_name: "New"}
      ]

      assert {:ok, count} = Leads.import_subscribers(project, data)
      # Only new one inserted, duplicate skipped
      assert count == 1
      assert Leads.subscriber_count(project) == 2
    end

    test "sets imported subscribers as pending status" do
      project = project_fixture()
      data = [%{email: "import@example.com"}]

      assert {:ok, 1} = Leads.import_subscribers(project, data)

      subscriber = Leads.get_subscriber_by_email(project, "import@example.com")
      assert subscriber.status == "pending"
      assert subscriber.source == "manual"
    end

    test "handles string keys in import data" do
      project = project_fixture()
      data = [%{"email" => "stringkey@example.com", "first_name" => "String"}]

      assert {:ok, 1} = Leads.import_subscribers(project, data)
      assert Leads.get_subscriber_by_email(project, "stringkey@example.com") != nil
    end
  end
end
