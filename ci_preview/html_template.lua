local html_template = {}

local function escapeHtmlAttribute(value)
    return (value:gsub("[&\"'<>]", {
        ["&"] = "&amp;",
        ['"'] = "&quot;",
        ["'"] = "&#39;",
        ["<"] = "&lt;",
        [">"] = "&gt;"
    }))
end

local function resolveOption(options, key, default)
    local value = options[key]
    if value == nil then
        return default
    end
    return value
end

---Render the HTML scaffold used by CI to host a love.js preview build.
---@param options table
---@return string
function html_template.renderPreviewHtml(options)
    assert(type(options) == "table", "options table is required")

    local title = escapeHtmlAttribute(resolveOption(options, "title", "Love2D Preview"))
    local backgroundColor = escapeHtmlAttribute(resolveOption(options, "backgroundColor", "#0f172a"))
    local loadingMessage = escapeHtmlAttribute(resolveOption(options, "loadingMessage", "Loading tactical battle preview..."))
    local startButtonLabel = escapeHtmlAttribute(resolveOption(options, "startButtonLabel", "Launch Preview"))
    local gameArchive = escapeHtmlAttribute(resolveOption(options, "gameArchive", "game.love"))
    local loveJsPath = escapeHtmlAttribute(resolveOption(options, "loveJsPath", "love.js"))
    local gameScriptPath = escapeHtmlAttribute(resolveOption(options, "gameScriptPath", "game.js"))

    local html = [[<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>]] .. title .. [[</title>
    <style>
        :root {
            color-scheme: dark;
        }
        body {
            margin: 0;
            font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
            background-color: ]] .. backgroundColor .. [[;
            color: #e2e8f0;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
        }
        #loader {
            text-align: center;
            padding: 1.5rem;
        }
        canvas {
            border: 1px solid rgba(148, 163, 184, 0.35);
            max-width: 90vw;
            max-height: 80vh;
        }
        button {
            background-color: #1d4ed8;
            border: none;
            color: white;
            padding: 0.75rem 1rem;
            border-radius: 0.5rem;
            cursor: pointer;
            font-size: 1rem;
        }
        button:hover {
            background-color: #2563eb;
        }
    </style>
</head>
<body>
    <div id="loader">
        <p id="loading-text">]] .. loadingMessage .. [[</p>
        <button id="start-button" type="button">]] .. startButtonLabel .. [[</button>
    </div>
    <canvas id="canvas" oncontextmenu="event.preventDefault()"></canvas>
    <script>
        var Module = {
            canvas: (function() {
                var canvas = document.getElementById('canvas');
                canvas.tabIndex = 0;
                return canvas;
            })(),
            arguments: [']] .. gameArchive .. [[']
        };
        var loaderElement = document.getElementById('loader');
        var loadingTextElement = document.getElementById('loading-text');
        var startButton = document.getElementById('start-button');
        var defaultButtonLabel = startButton.textContent;
        var runtimeAttached = false;

        function updateLoadingState(message, isError) {
            if (loadingTextElement) {
                loadingTextElement.textContent = message;
            }
            loaderElement.style.display = 'block';
            if (isError) {
                loaderElement.setAttribute('data-error', 'true');
            } else {
                loaderElement.removeAttribute('data-error');
            }
        }

        function handleRuntimeError(message, event) {
            console.error(message, event || '');
            startButton.disabled = false;
            startButton.textContent = defaultButtonLabel;
            updateLoadingState(message, true);
        }

        startButton.addEventListener('click', function() {
            if (runtimeAttached) {
                return;
            }

            runtimeAttached = true;
            startButton.disabled = true;
            startButton.textContent = 'Launching...';
            updateLoadingState('Downloading love.js runtime...', false);

            var script = document.createElement('script');
            script.src = ']] .. loveJsPath .. [[';
            script.async = true;
            script.addEventListener('load', function() {
                if (typeof Love === 'function') {
                    loaderElement.style.display = 'none';
                    Love(Module);
                } else {
                    runtimeAttached = false;
                    handleRuntimeError('love.js runtime failed to expose Love(Module).');
                }
            });
            script.addEventListener('error', function(event) {
                runtimeAttached = false;
                handleRuntimeError('Unable to load love.js runtime.', event);
            });
            document.body.appendChild(script);
        });
    </script>
    <script type="text/javascript" src="]] .. gameScriptPath .. [["></script>
</body>
</html>]]

    return html
end

return html_template
