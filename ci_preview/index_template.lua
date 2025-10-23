local index_template = {}

local function escapeHtml(value)
    return (value:gsub("[&<>]", {
        ["&"] = "&amp;",
        ["<"] = "&lt;",
        [">"] = "&gt;",
    }))
end

local function escapeAttribute(value)
    return (value:gsub("[&\"'<>]", {
        ["&"] = "&amp;",
        ['"'] = "&quot;",
        ["'"] = "&#39;",
        ["<"] = "&lt;",
        [">"] = "&gt;",
    }))
end

local function renderGameOptions(games)
    local rows = {}
    for _, game in ipairs(games) do
        local optionLabel = escapeHtml(game.name)
        local previewPath = escapeAttribute(game.previewPath or ("./" .. game.id .. "/index.html"))
        local description = escapeAttribute(game.description or "")
        local optionValue = escapeAttribute(game.id)
        table.insert(rows, string.format(
            "            <option value=\"%s\" data-preview=\"%s\" data-description=\"%s\">%s</option>",
            optionValue,
            previewPath,
            description,
            optionLabel
        ))
    end
    return table.concat(rows, "\n")
end

local function renderGameList(games)
    local items = {}
    for _, game in ipairs(games) do
        local label = escapeHtml(game.name)
        local previewPath = escapeAttribute(game.previewPath or ("./" .. game.id .. "/index.html"))
        local description = escapeHtml(game.description or "")
        table.insert(items, string.format(
            "            <li><a href=\"%s\">%s</a><span class=\"game-note\">%s</span></li>",
            previewPath,
            label,
            description
        ))
    end
    return table.concat(items, "\n")
end

---Render an index landing page that allows selecting from multiple preview builds.
---@param options table
---@return string
function index_template.render(options)
    options = options or {}
    local games = options.games or {}
    local title = escapeHtml(options.title or "Love2D Preview Launcher")
    local heading = escapeHtml(options.heading or "Preview Builds")
    local instructions = escapeHtml(options.instructions or "Choose a game to launch the browser preview.")

    if #games == 0 then
        return [[<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>]] .. title .. [[</title>
    <style>
        body {
            font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
            background-color: #0f172a;
            color: #e2e8f0;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            margin: 0;
            text-align: center;
        }
        a { color: #38bdf8; }
    </style>
</head>
<body>
    <div>
        <h1>]] .. heading .. [[</h1>
        <p>No preview builds were generated for this run.</p>
    </div>
</body>
</html>]]
    end

    local optionMarkup = renderGameOptions(games)
    local listMarkup = renderGameList(games)

    local html = [[<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>]] .. title .. [[</title>
    <style>
        :root { color-scheme: dark; }
        body {
            font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
            background-color: #0f172a;
            color: #e2e8f0;
            margin: 0;
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
        }
        main {
            width: min(90vw, 1200px);
            margin: 2rem auto;
            display: grid;
            gap: 1.5rem;
        }
        header h1 {
            margin: 0 0 0.5rem 0;
        }
        header p {
            margin: 0;
            color: #94a3b8;
        }
        #controls {
            display: flex;
            flex-wrap: wrap;
            gap: 1rem;
            align-items: center;
            background: rgba(15, 23, 42, 0.65);
            border: 1px solid rgba(148, 163, 184, 0.2);
            padding: 1rem;
            border-radius: 0.75rem;
        }
        select {
            background-color: #1f2937;
            color: #e2e8f0;
            border: 1px solid rgba(148, 163, 184, 0.4);
            border-radius: 0.5rem;
            padding: 0.5rem 0.75rem;
            font-size: 1rem;
        }
        button, a.launch-link {
            background-color: #1d4ed8;
            border: none;
            color: white;
            padding: 0.65rem 1.1rem;
            border-radius: 0.6rem;
            cursor: pointer;
            font-size: 1rem;
            text-decoration: none;
        }
        button:hover, a.launch-link:hover {
            background-color: #2563eb;
        }
        #game-description {
            margin: 0;
            color: #cbd5f5;
        }
        #preview-frame {
            width: 100%;
            min-height: 70vh;
            border: 1px solid rgba(148, 163, 184, 0.35);
            border-radius: 0.75rem;
            background: #111827;
        }
        ul.game-links {
            list-style: none;
            margin: 0;
            padding: 0;
            display: flex;
            flex-wrap: wrap;
            gap: 0.75rem 1.5rem;
        }
        ul.game-links li {
            display: flex;
            gap: 0.5rem;
            align-items: baseline;
        }
        ul.game-links a {
            color: #38bdf8;
        }
        .game-note {
            color: #94a3b8;
            font-size: 0.85rem;
        }
    </style>
</head>
<body>
    <main>
        <header>
            <h1>]] .. heading .. [[</h1>
            <p>]] .. instructions .. [[</p>
        </header>
        <section id="controls">
            <label for="game-select">Preview:</label>
            <select id="game-select">
]] .. optionMarkup .. [[
            </select>
            <button id="launch-preview" type="button">Load in page</button>
            <a id="open-in-tab" class="launch-link" href="#" target="_blank" rel="noopener">Open in new tab</a>
        </section>
        <p id="game-description"></p>
        <iframe id="preview-frame" title="Love2D preview" src="about:blank" allowfullscreen></iframe>
        <section>
            <h2>Direct links</h2>
            <ul class="game-links">
]] .. listMarkup .. [[
            </ul>
        </section>
    </main>
    <script>
        const select = document.getElementById('game-select');
        const frame = document.getElementById('preview-frame');
        const launchButton = document.getElementById('launch-preview');
        const link = document.getElementById('open-in-tab');
        const description = document.getElementById('game-description');

        function applySelection() {
            if (!select || select.options.length === 0) {
                return;
            }
            const option = select.options[select.selectedIndex];
            const preview = option.getAttribute('data-preview');
            const text = option.textContent || option.value;
            const note = option.getAttribute('data-description') || '';
            if (frame) {
                frame.src = preview;
                frame.focus();
            }
            if (link) {
                link.href = preview;
                link.textContent = `Open ${text} in new tab`;
            }
            if (description) {
                description.textContent = note;
            }
        }

        if (launchButton) {
            launchButton.addEventListener('click', applySelection);
        }
        if (select) {
            select.addEventListener('change', applySelection);
        }

        document.addEventListener('DOMContentLoaded', function() {
            if (select && select.options.length > 0) {
                applySelection();
            }
        });
    </script>
</body>
</html>]]

    return html
end

return index_template
