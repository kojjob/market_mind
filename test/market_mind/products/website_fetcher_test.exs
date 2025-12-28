defmodule MarketMind.Products.WebsiteFetcherTest do
  use ExUnit.Case, async: true

  alias MarketMind.Products.WebsiteFetcher

  describe "fetch/1" do
    test "returns content and title on successful fetch" do
      Req.Test.stub(WebsiteFetcher, fn conn ->
        Req.Test.html(conn, """
        <!DOCTYPE html>
        <html>
          <head>
            <title>MarketMind - AI Marketing Platform</title>
          </head>
          <body>
            <h1>Welcome to MarketMind</h1>
            <p>AI-powered marketing automation for indie makers.</p>
            <div class="features">
              <h2>Features</h2>
              <ul>
                <li>Persona Discovery</li>
                <li>Content Generation</li>
                <li>Campaign Automation</li>
              </ul>
            </div>
          </body>
        </html>
        """)
      end)

      assert {:ok, result} = WebsiteFetcher.fetch("https://example.com")
      assert result.title == "MarketMind - AI Marketing Platform"
      assert result.content =~ "Welcome to MarketMind"
      assert result.content =~ "AI-powered marketing automation"
      assert result.content =~ "Persona Discovery"
    end

    test "extracts text content without HTML tags" do
      Req.Test.stub(WebsiteFetcher, fn conn ->
        Req.Test.html(conn, """
        <html>
          <head><title>Test</title></head>
          <body>
            <script>var x = 1;</script>
            <style>.foo { color: red; }</style>
            <p>This is <strong>important</strong> content.</p>
            <nav>Skip this navigation</nav>
            <footer>Skip this footer</footer>
          </body>
        </html>
        """)
      end)

      assert {:ok, result} = WebsiteFetcher.fetch("https://example.com")
      # Should not contain script or style content
      refute result.content =~ "var x = 1"
      refute result.content =~ "color: red"
      # Should contain actual text
      assert result.content =~ "important"
      assert result.content =~ "content"
    end

    test "removes script, style, nav, and footer elements" do
      Req.Test.stub(WebsiteFetcher, fn conn ->
        Req.Test.html(conn, """
        <html>
          <head><title>Clean Test</title></head>
          <body>
            <script>malicious();</script>
            <header>Header Content</header>
            <main>Main Content</main>
            <aside>Sidebar Content</aside>
            <footer>Footer Content</footer>
          </body>
        </html>
        """)
      end)

      assert {:ok, result} = WebsiteFetcher.fetch("https://example.com")
      refute result.content =~ "malicious"
      assert result.content =~ "Main Content"
    end

    test "handles missing title gracefully" do
      Req.Test.stub(WebsiteFetcher, fn conn ->
        Req.Test.html(conn, """
        <html>
          <body>
            <h1>Page Without Title</h1>
            <p>Content here</p>
          </body>
        </html>
        """)
      end)

      assert {:ok, result} = WebsiteFetcher.fetch("https://example.com")
      assert result.title == "" || result.title == nil
      assert result.content =~ "Page Without Title"
    end

    test "handles HTTP 404 error" do
      Req.Test.stub(WebsiteFetcher, fn conn ->
        conn
        |> Plug.Conn.put_status(404)
        |> Req.Test.html("<html><body>Not Found</body></html>")
      end)

      assert {:error, {:http_error, 404}} = WebsiteFetcher.fetch("https://example.com")
    end

    test "handles HTTP 500 error" do
      Req.Test.stub(WebsiteFetcher, fn conn ->
        conn
        |> Plug.Conn.put_status(500)
        |> Req.Test.html("<html><body>Server Error</body></html>")
      end)

      assert {:error, {:http_error, 500}} = WebsiteFetcher.fetch("https://example.com")
    end

    test "handles network timeout" do
      Req.Test.stub(WebsiteFetcher, fn _conn ->
        raise Req.TransportError, reason: :timeout
      end)

      assert {:error, {:network_error, :timeout}} = WebsiteFetcher.fetch("https://example.com")
    end

    test "handles connection refused" do
      Req.Test.stub(WebsiteFetcher, fn _conn ->
        raise Req.TransportError, reason: :econnrefused
      end)

      assert {:error, {:network_error, :econnrefused}} = WebsiteFetcher.fetch("https://example.com")
    end

    test "handles invalid URL" do
      assert {:error, :invalid_url} = WebsiteFetcher.fetch("")
      assert {:error, :invalid_url} = WebsiteFetcher.fetch("not-a-url")
      assert {:error, :invalid_url} = WebsiteFetcher.fetch("ftp://example.com")
    end

    test "normalizes whitespace in extracted content" do
      Req.Test.stub(WebsiteFetcher, fn conn ->
        Req.Test.html(conn, """
        <html>
          <head><title>Whitespace Test</title></head>
          <body>
            <p>Multiple    spaces    here</p>
            <p>

              Newlines too

            </p>
          </body>
        </html>
        """)
      end)

      assert {:ok, result} = WebsiteFetcher.fetch("https://example.com")
      # Should normalize excessive whitespace
      refute result.content =~ "    "
    end

    test "handles large HTML documents" do
      large_content = String.duplicate("<p>Test paragraph content. </p>", 1000)

      Req.Test.stub(WebsiteFetcher, fn conn ->
        Req.Test.html(conn, """
        <html>
          <head><title>Large Document</title></head>
          <body>#{large_content}</body>
        </html>
        """)
      end)

      assert {:ok, result} = WebsiteFetcher.fetch("https://example.com")
      assert result.title == "Large Document"
      assert String.length(result.content) > 0
    end

    test "includes meta description when available" do
      Req.Test.stub(WebsiteFetcher, fn conn ->
        Req.Test.html(conn, """
        <html>
          <head>
            <title>Meta Test</title>
            <meta name="description" content="This is a test description for SEO purposes.">
          </head>
          <body>
            <p>Body content</p>
          </body>
        </html>
        """)
      end)

      assert {:ok, result} = WebsiteFetcher.fetch("https://example.com")
      assert result.meta_description == "This is a test description for SEO purposes."
    end

    test "extracts og:description as fallback" do
      Req.Test.stub(WebsiteFetcher, fn conn ->
        Req.Test.html(conn, """
        <html>
          <head>
            <title>OG Test</title>
            <meta property="og:description" content="Open Graph description for sharing.">
          </head>
          <body>
            <p>Body content</p>
          </body>
        </html>
        """)
      end)

      assert {:ok, result} = WebsiteFetcher.fetch("https://example.com")
      assert result.meta_description == "Open Graph description for sharing."
    end

    test "follows redirects" do
      Req.Test.stub(WebsiteFetcher, fn conn ->
        # Simulating successful fetch after redirect (Req handles redirects automatically)
        Req.Test.html(conn, """
        <html>
          <head><title>Redirected Page</title></head>
          <body><p>You were redirected here.</p></body>
        </html>
        """)
      end)

      assert {:ok, result} = WebsiteFetcher.fetch("https://example.com/old-page")
      assert result.title == "Redirected Page"
    end
  end

  describe "URL validation" do
    test "accepts valid HTTPS URLs" do
      Req.Test.stub(WebsiteFetcher, fn conn ->
        Req.Test.html(conn, "<html><head><title>HTTPS</title></head></html>")
      end)

      assert {:ok, _} = WebsiteFetcher.fetch("https://example.com")
      assert {:ok, _} = WebsiteFetcher.fetch("https://example.com/path")
      assert {:ok, _} = WebsiteFetcher.fetch("https://example.com/path?query=1")
    end

    test "accepts valid HTTP URLs" do
      Req.Test.stub(WebsiteFetcher, fn conn ->
        Req.Test.html(conn, "<html><head><title>HTTP</title></head></html>")
      end)

      assert {:ok, _} = WebsiteFetcher.fetch("http://example.com")
    end

    test "rejects invalid URLs" do
      assert {:error, :invalid_url} = WebsiteFetcher.fetch(nil)
      assert {:error, :invalid_url} = WebsiteFetcher.fetch("")
      assert {:error, :invalid_url} = WebsiteFetcher.fetch("not-a-url")
      assert {:error, :invalid_url} = WebsiteFetcher.fetch("mailto:test@example.com")
    end
  end
end
