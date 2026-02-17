using System.Text.Json.Nodes;
using FlutterSkill;

/// <summary>
/// Simulated social media UI test app for the .NET FlutterSkillBridge.
/// Uses in-memory elements to test the bridge protocol without requiring MAUI.
/// </summary>
class TestElement
{
    public string Type { get; set; } = "";
    public string? Key { get; set; }
    public string? Text { get; set; }
    public bool Enabled { get; set; } = true;
    public bool Clickable { get; set; }
    public string? Screen { get; set; }
    public int X { get; set; }
    public int Y { get; set; }
    public int Width { get; set; } = 200;
    public int Height { get; set; } = 40;
    public List<TestElement> Children { get; } = new();
}

class TestBridge : FlutterSkillBridge
{
    protected readonly List<TestElement> _elements = new();
    protected string _currentPage = "home";
    protected int _counter = 0;
    protected string _inputText = "";
    protected readonly List<string> _logs = new();
    protected readonly Stack<string> _navStack = new();
    
    // Form state
    protected string _postTitle = "";
    protected string _postBody = "";
    protected string _postCategory = "";
    protected bool _allowComments = false;
    protected bool _isPublic = false;
    protected bool _isScheduled = false;
    protected string _searchQuery = "";
    protected string _activeFilter = "all";

    // Feed data
    protected static readonly string[] Users = { "Alex Kim", "Sam Rivera", "Jordan Lee", "Taylor Swift", "Morgan Chen", "Casey Jones", "Riley Park", "Drew Williams", "Avery Zhang", "Quinn Murphy", "Blake Foster", "Jamie Cruz", "Sage Thompson", "Harper Davis", "Reese Clark" };
    protected static readonly string[] Topics = { "Just shipped a new feature! 🚀", "Beautiful sunset today", "Excited about the new framework?", "Coffee is a love language ☕", "Working on something exciting", "Best debugging tool: sleep", "Latest tech trends thoughts?", "Nature walk = mood boost 🌿", "Learning Rust and loving it", "Hot take: tabs > spaces", "Finished an amazing book 📚", "Weekend project update", "The future of AI", "Cooking experiment success", "Grateful for this community ❤️", "New music discovery 🎵", "Exercise done 💪", "Simplest solution = best", "Road trip plans!", "Late night coding vibes", "Design inspiration everywhere", "Fixed the haunting bug", "Morning routine strong ☀️", "Collaboration > Competition", "Side project progress" };
    protected int[] _likeCounts = new int[25];
    protected bool[] _liked = new bool[25];
    protected int _detailIndex = -1;

    public TestBridge(int port = 18118) : base(port)
    {
        var rng = new Random(42);
        for (int i = 0; i < 25; i++) { _likeCounts[i] = rng.Next(5, 200); _liked[i] = false; }
        BuildCurrentPage();
    }

    protected void BuildCurrentPage()
    {
        switch (_currentPage)
        {
            case "home": BuildHomePage(); break;
            case "search": BuildSearchPage(); break;
            case "create": BuildCreatePage(); break;
            case "profile": BuildProfilePage(); break;
            case "detail": BuildDetailPage(); break;
            case "settings": BuildSettingsPage(); break;
        }
    }

    private void BuildHomePage()
    {
        _elements.Clear();
        int y = 0;

        // Header
        _elements.Add(new TestElement { Type = "text", Key = "header-title", Text = "SocialApp", Y = y }); y += 40;
        _elements.Add(new TestElement { Type = "text", Key = "counter", Text = $"Count: {_counter}", Y = y });
        _elements.Add(new TestElement { Type = "button", Key = "increment-btn", Text = "Increment", Clickable = true, X = 150, Y = y }); y += 40;

        // Tab bar
        _elements.Add(new TestElement { Type = "button", Key = "tab-home", Text = "Home", Clickable = true, Y = y, X = 0 });
        _elements.Add(new TestElement { Type = "button", Key = "tab-search", Text = "Search", Clickable = true, Y = y, X = 100 });
        _elements.Add(new TestElement { Type = "button", Key = "tab-create", Text = "Create", Clickable = true, Y = y, X = 200 });
        _elements.Add(new TestElement { Type = "button", Key = "tab-profile", Text = "Profile", Clickable = true, Y = y, X = 300 }); y += 50;

        // Feed items (25 cards)
        for (int i = 0; i < 25; i++)
        {
            var user = Users[i % Users.Length];
            var topic = Topics[i % Topics.Length];
            _elements.Add(new TestElement { Type = "text", Key = $"feed-item-{i}", Text = $"{user}: {topic}", Clickable = true, Y = y, Height = 80 });
            _elements.Add(new TestElement { Type = "button", Key = $"like-btn-{i}", Text = _liked[i] ? $"❤ {_likeCounts[i]}" : $"♡ {_likeCounts[i]}", Clickable = true, Y = y + 60, X = 0 });
            _elements.Add(new TestElement { Type = "button", Key = $"comment-btn-{i}", Text = $"💬 {(i * 3 + 5) % 30 + 1}", Clickable = true, Y = y + 60, X = 100 });
            y += 100;
        }

        // Additional suggested items (to reach 50+)
        for (int i = 25; i < 55; i++)
        {
            _elements.Add(new TestElement { Type = "text", Key = $"feed-item-{i}", Text = $"Suggested post #{i + 1} — {Topics[i % Topics.Length]}", Y = y });
            y += 40;
        }

        // Backward-compat elements
        _elements.Add(new TestElement { Type = "text_field", Key = "text-input", Text = _inputText, Y = y }); y += 50;
        _elements.Add(new TestElement { Type = "button", Key = "submit-btn", Text = "Submit", Clickable = true, Y = y }); y += 40;
        _elements.Add(new TestElement { Type = "checkbox", Key = "test-checkbox", Text = _allowComments ? "Checked" : "Unchecked", Clickable = true, Y = y }); y += 40;
        _elements.Add(new TestElement { Type = "button", Key = "detail-btn", Text = "Go to Detail", Clickable = true, Y = y }); y += 40;
        _elements.Add(new TestElement { Type = "button", Key = "decrement-btn", Text = "Decrement", Clickable = true, Y = y });
    }

    private void BuildSearchPage()
    {
        _elements.Clear();
        int y = 0;

        _elements.Add(new TestElement { Type = "text", Key = "header-title", Text = "Search", Y = y }); y += 40;
        _elements.Add(new TestElement { Type = "text_field", Key = "search-input", Text = _searchQuery, Y = y }); y += 50;

        // Tabs
        _elements.Add(new TestElement { Type = "button", Key = "tab-home", Text = "Home", Clickable = true, Y = y, X = 0 });
        _elements.Add(new TestElement { Type = "button", Key = "tab-search", Text = "Search", Clickable = true, Y = y, X = 100 });
        _elements.Add(new TestElement { Type = "button", Key = "tab-create", Text = "Create", Clickable = true, Y = y, X = 200 });
        _elements.Add(new TestElement { Type = "button", Key = "tab-profile", Text = "Profile", Clickable = true, Y = y, X = 300 }); y += 50;

        // Filters
        string[] filters = { "all", "people", "posts", "tags", "photos", "videos" };
        foreach (var f in filters)
        {
            _elements.Add(new TestElement { Type = "button", Key = $"filter-{f}", Text = f == _activeFilter ? $"[{f}]" : f, Clickable = true, Y = y });
            y += 35;
        }

        // Search results
        var results = string.IsNullOrEmpty(_searchQuery) ? Users : Users.Where(u => u.Contains(_searchQuery, StringComparison.OrdinalIgnoreCase)).ToArray();
        for (int i = 0; i < results.Length; i++)
        {
            _elements.Add(new TestElement { Type = "text", Key = $"search-result-{i}", Text = results[i], Clickable = true, Y = y });
            y += 40;
        }
    }

    private void BuildCreatePage()
    {
        _elements.Clear();
        int y = 0;

        _elements.Add(new TestElement { Type = "text", Key = "header-title", Text = "Create Post", Y = y }); y += 40;

        // Tabs
        _elements.Add(new TestElement { Type = "button", Key = "tab-home", Text = "Home", Clickable = true, Y = y, X = 0 });
        _elements.Add(new TestElement { Type = "button", Key = "tab-search", Text = "Search", Clickable = true, Y = y, X = 100 });
        _elements.Add(new TestElement { Type = "button", Key = "tab-create", Text = "Create", Clickable = true, Y = y, X = 200 });
        _elements.Add(new TestElement { Type = "button", Key = "tab-profile", Text = "Profile", Clickable = true, Y = y, X = 300 }); y += 50;

        _elements.Add(new TestElement { Type = "text_field", Key = "text-input", Text = _postTitle, Y = y }); y += 50;
        _elements.Add(new TestElement { Type = "text_field", Key = "post-body", Text = _postBody, Y = y, Height = 100 }); y += 110;
        _elements.Add(new TestElement { Type = "dropdown", Key = "post-category", Text = string.IsNullOrEmpty(_postCategory) ? "Select category..." : _postCategory, Clickable = true, Y = y }); y += 50;
        _elements.Add(new TestElement { Type = "checkbox", Key = "test-checkbox", Text = _allowComments ? "Checked" : "Unchecked", Clickable = true, Y = y }); y += 40;
        _elements.Add(new TestElement { Type = "checkbox", Key = "nsfw-checkbox", Text = "Mark as sensitive", Clickable = true, Y = y }); y += 40;
        _elements.Add(new TestElement { Type = "switch", Key = "toggle-switch", Text = _isPublic ? "Public" : "Private", Clickable = true, Y = y }); y += 40;
        _elements.Add(new TestElement { Type = "switch", Key = "schedule-toggle", Text = _isScheduled ? "Scheduled" : "Post now", Clickable = true, Y = y }); y += 50;
        _elements.Add(new TestElement { Type = "text", Key = "result", Text = "", Y = y }); y += 30;
        _elements.Add(new TestElement { Type = "button", Key = "submit-btn", Text = "Publish Post", Clickable = true, Y = y });
    }

    private void BuildProfilePage()
    {
        _elements.Clear();
        int y = 0;

        _elements.Add(new TestElement { Type = "text", Key = "header-title", Text = "Profile", Y = y }); y += 40;

        // Tabs
        _elements.Add(new TestElement { Type = "button", Key = "tab-home", Text = "Home", Clickable = true, Y = y, X = 0 });
        _elements.Add(new TestElement { Type = "button", Key = "tab-search", Text = "Search", Clickable = true, Y = y, X = 100 });
        _elements.Add(new TestElement { Type = "button", Key = "tab-create", Text = "Create", Clickable = true, Y = y, X = 200 });
        _elements.Add(new TestElement { Type = "button", Key = "tab-profile", Text = "Profile", Clickable = true, Y = y, X = 300 }); y += 50;

        _elements.Add(new TestElement { Type = "text", Key = "profile-avatar", Text = "👤 Jane Developer", Y = y }); y += 40;
        _elements.Add(new TestElement { Type = "text", Key = "profile-bio", Text = "Full-stack dev • Coffee enthusiast", Y = y }); y += 30;
        _elements.Add(new TestElement { Type = "text", Key = "stat-posts", Text = "1,234 Posts", Y = y, X = 0 });
        _elements.Add(new TestElement { Type = "text", Key = "stat-followers", Text = "5.6K Followers", Y = y, X = 100 });
        _elements.Add(new TestElement { Type = "text", Key = "stat-following", Text = "892 Following", Y = y, X = 200 }); y += 40;
        _elements.Add(new TestElement { Type = "button", Key = "edit-profile-btn", Text = "Edit Profile", Clickable = true, Y = y }); y += 40;
        _elements.Add(new TestElement { Type = "button", Key = "settings-btn", Text = "⚙ Settings", Clickable = true, Y = y }); y += 50;

        // Profile posts
        for (int i = 0; i < 15; i++)
        {
            _elements.Add(new TestElement { Type = "text", Key = $"profile-post-{i}", Text = $"My Post #{i + 1}: {Topics[i % Topics.Length]}", Clickable = true, Y = y });
            y += 40;
        }
    }

    protected void BuildDetailPage()
    {
        _elements.Clear();
        int y = 0;

        var idx = _detailIndex >= 0 ? _detailIndex : 0;
        var user = Users[idx % Users.Length];
        var topic = Topics[idx % Topics.Length];

        _elements.Add(new TestElement { Type = "button", Key = "back-btn", Text = "← Back", Clickable = true, Y = y }); y += 40;
        _elements.Add(new TestElement { Type = "text", Key = "detail-title", Text = "Post Detail", Y = y }); y += 40;
        _elements.Add(new TestElement { Type = "text", Key = "detail-heading", Text = $"{user}'s Post", Y = y }); y += 40;
        _elements.Add(new TestElement { Type = "text", Key = "detail-text", Text = topic, Y = y }); y += 60;
        _elements.Add(new TestElement { Type = "text", Key = "detail-counter", Text = $"Counter: {_counter}", Y = y }); y += 40;
        _elements.Add(new TestElement { Type = "button", Key = "detail-like-btn", Text = $"♡ {_likeCounts[idx % 25]}", Clickable = true, Y = y }); y += 40;

        // Comments
        for (int c = 0; c < 8; c++)
        {
            var commenter = Users[(idx + c + 1) % Users.Length];
            string[] commentTexts = { "Great post! 👏", "Love this!", "So true!", "Amazing content", "Thanks for sharing", "Couldn't agree more", "This is gold ✨", "Well said!" };
            _elements.Add(new TestElement { Type = "text", Key = $"comment-{c}", Text = $"{commenter}: {commentTexts[c]}", Y = y });
            y += 35;
        }
    }

    private void BuildSettingsPage()
    {
        _elements.Clear();
        int y = 0;

        _elements.Add(new TestElement { Type = "button", Key = "back-btn", Text = "← Back", Clickable = true, Y = y }); y += 40;
        _elements.Add(new TestElement { Type = "text", Key = "settings-title", Text = "Settings", Y = y }); y += 40;

        string[] items = { "👤 Account", "🔒 Privacy", "🔔 Notifications", "🎨 Appearance", "🌐 Language", "❓ Help & Support", "🚪 Log Out" };
        for (int i = 0; i < items.Length; i++)
        {
            _elements.Add(new TestElement { Type = "button", Key = $"settings-item-{i}", Text = items[i], Clickable = true, Y = y });
            y += 40;
        }
        _elements.Add(new TestElement { Type = "button", Key = "modal-close", Text = "Close", Clickable = true, Y = y });
    }

    protected override string GetPlatformName() => "dotnet";

    protected override Task<JsonObject> HandleInspect(JsonObject parms)
    {
        var elements = new JsonArray();
        foreach (var el in _elements)
        {
            elements.Add(new JsonObject
            {
                ["type"] = el.Type,
                ["key"] = el.Key,
                ["text"] = el.Text,
                ["enabled"] = el.Enabled,
                ["clickable"] = el.Clickable,
                ["visible"] = true,
                ["bounds"] = new JsonObject { ["x"] = el.X, ["y"] = el.Y, ["width"] = el.Width, ["height"] = el.Height }
            });
        }
        return Task.FromResult(new JsonObject { ["elements"] = elements });
    }

    protected override Task<JsonObject> HandleInspectInteractive(JsonObject parms)
    {
        var elements = new JsonArray();
        var refCounts = new Dictionary<string, int>();

        foreach (var el in _elements)
        {
            if (!IsInteractive(el.Type)) continue;

            var role = MapRole(el.Type);
            var content = (el.Text ?? el.Key ?? "").Replace(" ", "_");
            if (content.Length > 30) content = content[..27] + "...";

            var baseRef = string.IsNullOrEmpty(content) ? role : $"{role}:{content}";
            refCounts.TryGetValue(baseRef, out var count);
            refCounts[baseRef] = count + 1;
            var refId = count == 0 ? baseRef : $"{baseRef}[{count}]";

            var actions = new JsonArray();
            if (el.Type is "button") actions.Add("tap");
            else if (el.Type is "text_field") { actions.Add("tap"); actions.Add("enter_text"); }
            else if (el.Type is "checkbox" or "switch") { actions.Add("tap"); actions.Add("toggle"); }
            else if (el.Type is "slider") { actions.Add("set_value"); }
            else if (el.Type is "dropdown") { actions.Add("tap"); actions.Add("select"); }
            else actions.Add("tap");

            elements.Add(new JsonObject
            {
                ["ref"] = refId,
                ["type"] = el.Type,
                ["text"] = el.Text,
                ["enabled"] = el.Enabled,
                ["actions"] = actions,
                ["bounds"] = new JsonObject { ["x"] = el.X, ["y"] = el.Y, ["width"] = el.Width, ["height"] = el.Height }
            });
        }

        return Task.FromResult(new JsonObject
        {
            ["elements"] = elements,
            ["summary"] = $"{elements.Count} interactive elements on {_currentPage} page"
        });
    }

    private static bool IsInteractive(string type) =>
        type is "button" or "text_field" or "checkbox" or "switch" or "slider" or "dropdown" or "link";

    private static string MapRole(string type) => type switch
    {
        "button" => "button",
        "text_field" => "input",
        "checkbox" or "switch" => "toggle",
        "slider" => "slider",
        "dropdown" => "select",
        "link" => "link",
        _ => "element"
    };

    private TestElement? FindByKey(string key) => _elements.FirstOrDefault(e => e.Key == key);
    private TestElement? FindByText(string text) => _elements.FirstOrDefault(e => e.Text?.Contains(text) == true);

    protected override Task<JsonObject> HandleTap(string selector, JsonObject parms)
    {
        var key = parms["key"]?.GetValue<string>() ?? selector;
        var textMatch = parms["text"]?.GetValue<string>();
        
        var el = !string.IsNullOrEmpty(key) ? FindByKey(key) : null;
        el ??= textMatch != null ? FindByText(textMatch) : null;
        
        if (el == null) return Task.FromResult(new JsonObject { ["success"] = false, ["message"] = "Element not found" });

        _logs.Add($"Tapped: {el.Key}");

        // Tab navigation
        if (el.Key == "tab-home") { NavigateTo("home"); }
        else if (el.Key == "tab-search") { NavigateTo("search"); }
        else if (el.Key == "tab-create") { NavigateTo("create"); }
        else if (el.Key == "tab-profile") { NavigateTo("profile"); }
        // Actions
        else if (el.Key == "increment-btn") { _counter++; BuildCurrentPage(); }
        else if (el.Key == "decrement-btn") { _counter--; BuildCurrentPage(); }
        else if (el.Key == "detail-btn") { _detailIndex = 0; NavigateTo("detail"); }
        else if (el.Key == "back-btn") { GoBack(); }
        else if (el.Key == "submit-btn") { _logs.Add($"Submitted: {_postTitle}"); }
        else if (el.Key == "settings-btn") { NavigateTo("settings"); }
        else if (el.Key == "modal-close") { GoBack(); }
        else if (el.Key == "test-checkbox") { _allowComments = !_allowComments; BuildCurrentPage(); }
        else if (el.Key == "toggle-switch") { _isPublic = !_isPublic; BuildCurrentPage(); }
        else if (el.Key == "schedule-toggle") { _isScheduled = !_isScheduled; BuildCurrentPage(); }
        else if (el.Key?.StartsWith("feed-item-") == true)
        {
            if (int.TryParse(el.Key.Replace("feed-item-", ""), out var idx)) { _detailIndex = idx; NavigateTo("detail"); }
        }
        else if (el.Key?.StartsWith("like-btn-") == true)
        {
            if (int.TryParse(el.Key.Replace("like-btn-", ""), out var idx) && idx < 25)
            {
                _liked[idx] = !_liked[idx];
                _likeCounts[idx] += _liked[idx] ? 1 : -1;
                BuildCurrentPage();
            }
        }
        else if (el.Key?.StartsWith("filter-") == true)
        {
            _activeFilter = el.Key.Replace("filter-", "");
            BuildCurrentPage();
        }

        return Task.FromResult(new JsonObject { ["success"] = true });
    }

    private void NavigateTo(string page)
    {
        _navStack.Push(_currentPage);
        _currentPage = page;
        BuildCurrentPage();
    }

    private void GoBack()
    {
        if (_navStack.Count > 0) _currentPage = _navStack.Pop();
        else _currentPage = "home";
        BuildCurrentPage();
    }

    protected override Task<JsonObject> HandleEnterText(string selector, string text, JsonObject parms)
    {
        var key = parms["key"]?.GetValue<string>() ?? selector;
        var el = FindByKey(key);
        if (el == null) return Task.FromResult(new JsonObject { ["success"] = false, ["message"] = "Not found" });
        el.Text = text;
        if (key == "text-input") { _inputText = text; _postTitle = text; }
        else if (key == "post-body") _postBody = text;
        else if (key == "search-input") { _searchQuery = text; BuildCurrentPage(); }
        return Task.FromResult(new JsonObject { ["success"] = true });
    }

    protected override Task<JsonObject> HandleGetText(string selector, JsonObject parms)
    {
        var key = parms["key"]?.GetValue<string>() ?? selector;
        var el = FindByKey(key);
        return Task.FromResult(new JsonObject { ["text"] = el?.Text });
    }

    protected override Task<JsonObject> HandleFindElement(string? selector, string? text, JsonObject parms)
    {
        var key = parms["key"]?.GetValue<string>() ?? selector;
        TestElement? el = null;
        if (!string.IsNullOrEmpty(key)) el = FindByKey(key!);
        if (el == null && !string.IsNullOrEmpty(text)) el = FindByText(text!);
        
        if (el != null)
            return Task.FromResult(new JsonObject
            {
                ["found"] = true,
                ["element"] = new JsonObject { ["type"] = el.Type, ["key"] = el.Key, ["text"] = el.Text },
                ["bounds"] = new JsonObject { ["x"] = el.X, ["y"] = el.Y, ["width"] = el.Width, ["height"] = el.Height }
            });
        return Task.FromResult(new JsonObject { ["found"] = false });
    }

    protected override async Task<JsonObject> HandleWaitForElement(string selector, int timeout, JsonObject parms)
    {
        var key = parms["key"]?.GetValue<string>() ?? selector;
        var textMatch = parms["text"]?.GetValue<string>();
        var start = Environment.TickCount64;
        while (Environment.TickCount64 - start < timeout)
        {
            var el = !string.IsNullOrEmpty(key) ? FindByKey(key) : null;
            el ??= textMatch != null ? FindByText(textMatch) : null;
            if (el != null) return new JsonObject { ["found"] = true };
            await Task.Delay(100);
        }
        return new JsonObject { ["found"] = false };
    }

    protected override Task<JsonObject> HandleScroll(int dx, int dy, JsonObject parms)
    {
        var direction = parms["direction"]?.GetValue<string>() ?? "down";
        _logs.Add($"Scrolled: {direction}");
        return Task.FromResult(new JsonObject { ["success"] = true });
    }

    protected override Task<JsonObject> HandleScreenshot(JsonObject parms)
    {
        var fakePng = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAIAAAAC64paAAAAG0lEQVR4nGP4z8BANiJf56jmUc2jmkc1U0UzADHNjoAymaoJAAAAAElFTkSuQmCC";
        return Task.FromResult(new JsonObject
        {
            ["success"] = true,
            ["image"] = fakePng,
            ["format"] = "png",
            ["encoding"] = "base64"
        });
    }

    protected override Task<JsonObject> HandleGoBack(JsonObject parms)
    {
        GoBack();
        return Task.FromResult(new JsonObject { ["success"] = true });
    }
}

class Program
{
    static async Task Main(string[] args)
    {
        var port = args.Length > 0 ? int.Parse(args[0]) : 18118;
        var bridge = new TestBridge(port);
        bridge.Start();
        Console.WriteLine($"[flutter-skill-dotnet] Test bridge on port {port}. Press Enter to stop.");
        System.Threading.Thread.Sleep(System.Threading.Timeout.Infinite);
        bridge.Stop();
    }
}
