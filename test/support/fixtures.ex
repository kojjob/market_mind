defmodule MarketMind.Fixtures do
  @moduledoc """
  Test fixtures for creating test data.

  All fixtures use direct database inserts to bypass Ecto changesets,
  then return the fetched Ecto struct for proper typing.
  """

  alias MarketMind.Repo

  @doc """
  Creates a user directly in the database for testing.
  """
  def user_fixture(attrs \\ %{}) do
    unique_id = System.unique_integer([:positive])
    uuid = Ecto.UUID.generate()

    defaults = %{
      id: Ecto.UUID.dump!(uuid),
      email: "user#{unique_id}@example.com",
      hashed_password: "hashed_password_#{unique_id}",
      inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
      updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    user_attrs = Map.merge(defaults, Enum.into(attrs, %{}))

    {1, _} = Repo.insert_all("users", [user_attrs])

    # Fetch the inserted user to get proper typed fields
    Repo.get!(MarketMind.Accounts.User, uuid)
  end

  @doc """
  Creates a project directly in the database for testing.

  If no user is provided, creates one automatically.

  ## Options

    * `:user` - The user to associate with the project
    * Other attributes are merged with defaults

  """
  def project_fixture(attrs \\ %{}) do
    unique_id = System.unique_integer([:positive])
    uuid = Ecto.UUID.generate()

    # Get or create user
    user = attrs[:user] || user_fixture()

    defaults = %{
      id: Ecto.UUID.dump!(uuid),
      name: "Test Project #{unique_id}",
      slug: "test-project-#{unique_id}-#{:rand.uniform(1000)}",
      url: "https://example#{unique_id}.com",
      analysis_status: "pending",
      user_id: Ecto.UUID.dump!(user.id),
      inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
      updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    # Remove :user from attrs before merging
    project_attrs =
      attrs
      |> Map.drop([:user])
      |> Enum.into(%{})
      |> then(&Map.merge(defaults, &1))

    {1, _} = Repo.insert_all("projects", [project_attrs])

    Repo.get!(MarketMind.Products.Project, uuid)
  end

  @doc """
  Creates a content piece directly in the database for testing.

  ## Arguments

    * `project` - The project to associate the content with
    * `attrs` - Optional attributes to override defaults

  ## Examples

      project = project_fixture()
      content = content_fixture(project)
      content = content_fixture(project, %{title: "My Blog Post"})

  """
  def content_fixture(project, attrs \\ %{}) do
    unique_id = System.unique_integer([:positive])
    uuid = Ecto.UUID.generate()
    timestamp = System.system_time(:second)

    defaults = %{
      id: Ecto.UUID.dump!(uuid),
      title: "Test Content #{unique_id}",
      slug: "test-content-#{unique_id}-#{timestamp}",
      content_type: "blog_post",
      status: "draft",
      body: "This is test content body for content #{unique_id}.",
      meta_description: "Test meta description",
      target_keyword: "test keyword",
      secondary_keywords: [],
      word_count: 10,
      reading_time_minutes: 1,
      seo_data: %{},
      project_id: Ecto.UUID.dump!(project.id),
      inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
      updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    content_attrs = Map.merge(defaults, Enum.into(attrs, %{}))

    {1, _} = Repo.insert_all("contents", [content_attrs])

    Repo.get!(MarketMind.Content.Content, uuid)
  end

  @doc """
  Creates a subscriber directly in the database for testing.

  ## Arguments

    * `project` - The project to associate the subscriber with
    * `attrs` - Optional attributes to override defaults

  ## Examples

      project = project_fixture()
      subscriber = subscriber_fixture(project)
      subscriber = subscriber_fixture(project, %{email: "custom@example.com"})

  """
  def subscriber_fixture(project, attrs \\ %{}) do
    unique_id = System.unique_integer([:positive])
    uuid = Ecto.UUID.generate()

    # Encode source_id if provided as a string UUID
    source_id = case attrs[:source_id] do
      nil -> nil
      id when is_binary(id) -> Ecto.UUID.dump!(id)
      id -> id
    end

    defaults = %{
      id: Ecto.UUID.dump!(uuid),
      email: "subscriber#{unique_id}@example.com",
      first_name: "Subscriber#{unique_id}",
      status: "pending",
      source: "lead_magnet",
      source_id: source_id,
      tags: [],
      metadata: %{},
      consent_given_at: DateTime.utc_now() |> DateTime.truncate(:second),
      consent_ip: "127.0.0.1",
      consent_user_agent: "Test Browser/1.0",
      project_id: Ecto.UUID.dump!(project.id),
      inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
      updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    # Drop source_id since we've already processed it
    subscriber_attrs =
      attrs
      |> Map.drop([:source_id])
      |> Enum.into(%{})
      |> then(&Map.merge(defaults, &1))

    {1, _} = Repo.insert_all("subscribers", [subscriber_attrs])

    Repo.get!(MarketMind.Leads.Subscriber, uuid)
  end

  @doc """
  Creates a lead magnet directly in the database for testing.

  ## Arguments

    * `project` - The project to associate the lead magnet with
    * `attrs` - Optional attributes to override defaults

  ## Examples

      project = project_fixture()
      lead_magnet = lead_magnet_fixture(project)
      lead_magnet = lead_magnet_fixture(project, %{magnet_type: "guide", status: "active"})

  """
  def lead_magnet_fixture(project, attrs \\ %{}) do
    unique_id = System.unique_integer([:positive])
    uuid = Ecto.UUID.generate()

    defaults = %{
      id: Ecto.UUID.dump!(uuid),
      title: "Test Lead Magnet #{unique_id}",
      slug: "test-lead-magnet-#{unique_id}",
      description: "A test lead magnet description",
      magnet_type: "checklist",
      status: "draft",
      content: "## Test Content\n\n- [ ] Item 1\n- [ ] Item 2\n- [ ] Item 3",
      headline: "Get Your Free Checklist",
      subheadline: "Download now and start improving today",
      cta_text: "Download Now",
      thank_you_message: "Thanks for downloading! Check your email.",
      download_count: 0,
      project_id: Ecto.UUID.dump!(project.id),
      inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
      updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    lead_magnet_attrs = Map.merge(defaults, Enum.into(attrs, %{}))

    {1, _} = Repo.insert_all("lead_magnets", [lead_magnet_attrs])

    Repo.get!(MarketMind.LeadMagnets.LeadMagnet, uuid)
  end

  @doc """
  Creates an email sequence directly in the database for testing.

  ## Arguments

    * `project` - The project to associate the sequence with
    * `attrs` - Optional attributes to override defaults

  ## Examples

      project = project_fixture()
      sequence = sequence_fixture(project)
      sequence = sequence_fixture(project, %{trigger: "subscriber_confirmed", status: "active"})

  """
  def sequence_fixture(project, attrs \\ %{}) do
    unique_id = System.unique_integer([:positive])
    uuid = Ecto.UUID.generate()

    trigger = attrs[:trigger] || "manual"

    # Encode trigger_id if provided as a string UUID
    trigger_id = case attrs[:trigger_id] do
      nil -> nil
      id when is_binary(id) -> Ecto.UUID.dump!(id)
      id -> id
    end

    defaults = %{
      id: Ecto.UUID.dump!(uuid),
      name: "Test Sequence #{unique_id}",
      description: "A test email sequence",
      trigger: trigger,
      trigger_id: trigger_id,
      status: "draft",
      project_id: Ecto.UUID.dump!(project.id),
      inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
      updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    # Drop trigger and trigger_id since we've already processed them
    sequence_attrs =
      attrs
      |> Map.drop([:trigger, :trigger_id])
      |> Enum.into(%{})
      |> then(&Map.merge(defaults, &1))

    {1, _} = Repo.insert_all("email_sequences", [sequence_attrs])

    Repo.get!(MarketMind.EmailMarketing.EmailSequence, uuid)
  end

  @doc """
  Creates a sequence email directly in the database for testing.

  ## Arguments

    * `sequence` - The email sequence to associate the email with
    * `attrs` - Optional attributes to override defaults

  ## Examples

      project = project_fixture()
      sequence = sequence_fixture(project)
      email = sequence_email_fixture(sequence)
      email = sequence_email_fixture(sequence, %{delay_days: 3, position: 2})

  """
  def sequence_email_fixture(sequence, attrs \\ %{}) do
    unique_id = System.unique_integer([:positive])
    uuid = Ecto.UUID.generate()

    defaults = %{
      id: Ecto.UUID.dump!(uuid),
      subject: "Test Email Subject #{unique_id}",
      body: "<h1>Welcome!</h1><p>Thanks for signing up, {{first_name}}!</p>",
      delay_days: 0,
      delay_hours: 0,
      position: attrs[:position] || 1,
      status: "active",
      sequence_id: Ecto.UUID.dump!(sequence.id),
      inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
      updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    email_attrs = Map.merge(defaults, Enum.into(attrs, %{}))

    {1, _} = Repo.insert_all("sequence_emails", [email_attrs])

    Repo.get!(MarketMind.EmailMarketing.SequenceEmail, uuid)
  end

  @doc """
  Creates an email delivery directly in the database for testing.

  ## Arguments

    * `subscriber` - The subscriber receiving the email
    * `sequence_email` - The sequence email being delivered
    * `attrs` - Optional attributes to override defaults

  ## Examples

      project = project_fixture()
      subscriber = subscriber_fixture(project)
      sequence = sequence_fixture(project)
      email = sequence_email_fixture(sequence)
      delivery = delivery_fixture(subscriber, email)
      delivery = delivery_fixture(subscriber, email, %{status: "sent"})

  """
  def delivery_fixture(subscriber, sequence_email, attrs \\ %{}) do
    uuid = Ecto.UUID.generate()

    defaults = %{
      id: Ecto.UUID.dump!(uuid),
      status: "scheduled",
      scheduled_for: DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second),
      sent_at: nil,
      opened_at: nil,
      clicked_at: nil,
      error_message: nil,
      attempts: 0,
      subscriber_id: Ecto.UUID.dump!(subscriber.id),
      sequence_email_id: Ecto.UUID.dump!(sequence_email.id),
      inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
      updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    delivery_attrs = Map.merge(defaults, Enum.into(attrs, %{}))

    {1, _} = Repo.insert_all("email_deliveries", [delivery_attrs])

    Repo.get!(MarketMind.EmailMarketing.EmailDelivery, uuid)
  end

  @doc """
  Creates a confirmed subscriber for testing.

  Convenience wrapper around `subscriber_fixture/2` that sets status to "confirmed"
  and adds a confirmed_at timestamp.
  """
  def confirmed_subscriber_fixture(project, attrs \\ %{}) do
    subscriber_fixture(project, Map.merge(%{
      status: "confirmed",
      confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }, attrs))
  end

  @doc """
  Creates an active lead magnet for testing.

  Convenience wrapper around `lead_magnet_fixture/2` that sets status to "active".
  """
  def active_lead_magnet_fixture(project, attrs \\ %{}) do
    lead_magnet_fixture(project, Map.merge(%{status: "active"}, attrs))
  end

  @doc """
  Creates an active email sequence for testing.

  Convenience wrapper around `sequence_fixture/2` that sets status to "active".
  """
  def active_sequence_fixture(project, attrs \\ %{}) do
    sequence_fixture(project, Map.merge(%{status: "active"}, attrs))
  end

  @doc """
  Creates a complete email sequence with emails for testing.

  Returns a map with the sequence and its emails.

  ## Options

    * `:email_count` - Number of emails to create (default: 3)
    * `:status` - Sequence status (default: "active")

  """
  def sequence_with_emails_fixture(project, opts \\ []) do
    email_count = Keyword.get(opts, :email_count, 3)
    status = Keyword.get(opts, :status, "active")

    sequence = sequence_fixture(project, %{status: status})

    emails =
      Enum.map(1..email_count, fn position ->
        sequence_email_fixture(sequence, %{
          position: position,
          delay_days: position - 1,
          subject: "Email #{position} of sequence"
        })
      end)

    %{sequence: sequence, emails: emails}
  end

  @doc """
  Creates a lead magnet with an associated email sequence for testing.

  Returns a map with the lead magnet and sequence.
  """
  def lead_magnet_with_sequence_fixture(project, opts \\ []) do
    lead_magnet = active_lead_magnet_fixture(project)

    sequence = sequence_fixture(project, %{
      trigger: "lead_magnet_download",
      trigger_id: Ecto.UUID.dump!(lead_magnet.id),
      status: Keyword.get(opts, :sequence_status, "active")
    })

    emails = Keyword.get(opts, :email_count, 3)
    |> case do
      0 -> []
      count ->
        Enum.map(1..count, fn position ->
          sequence_email_fixture(sequence, %{
            position: position,
            delay_days: position - 1
          })
        end)
    end

    %{lead_magnet: lead_magnet, sequence: sequence, emails: emails}
  end
end
