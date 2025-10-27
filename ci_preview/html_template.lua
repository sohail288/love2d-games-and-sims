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

local function renderVirtualKeyboard()
    return [[
        <div id="virtual-keyboard">
            <div class="keyboard-row">
                <button class="key-button" data-key="ArrowUp" data-code="ArrowUp">↑</button>
            </div>
            <div class="keyboard-row">
                <button class="key-button" data-key="ArrowLeft" data-code="ArrowLeft">←</button>
                <button class="key-button" data-key="ArrowDown" data-code="ArrowDown">↓</button>
                <button class="key-button" data-key="ArrowRight" data-code="ArrowRight">→</button>
            </div>
            <div class="keyboard-row">
                <button class="key-button" data-key=" " data-code="Space">Space</button>
                <button class="key-button" data-key="Enter" data-code="Enter">Enter</button>
                <button class="key-button" data-key="Tab" data-code="Tab">Tab</button>
            </div>
        </div>
    ]]
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
    local includeVirtualKeyboard = resolveOption(options, "includeVirtualKeyboard", false)

    local virtualKeyboardHtml = includeVirtualKeyboard and renderVirtualKeyboard() or ""

    local html = [[<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-f-8" />
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
            gap: 1.5rem;
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
        #virtual-keyboard {
            display: none;
            flex-direction: column;
            gap: 0.5rem;
            background: rgba(30, 41, 59, 0.6);
            padding: 1rem;
            border-radius: 0.75rem;
        }
        .keyboard-row {
            display: flex;
            justify-content: center;
            gap: 0.5rem;
        }
        .key-button {
            background-color: #374151;
            padding: 0.75rem;
            min-width: 3rem;
            text-align: center;
        }
        .key-button:active {
            background-color: #4b5563;
        }
    </style>
</head>
<body>
    <div id="loader">
        <p id="loading-text">]] .. loadingMessage .. [[</p>
        <button id="start-button" type="button">]] .. startButtonLabel .. [[</button>
    </div>
    <canvas id="canvas" oncontextmenu="event.preventDefault()"></canvas>
    ]] .. virtualKeyboardHtml .. [[
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
        var gameScriptPath = ']] .. gameScriptPath .. [[';
        var virtualKeyboard = document.getElementById('virtual-keyboard');

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
            runtimeAttached = false;
            startButton.disabled = false;
            startButton.textContent = defaultButtonLabel;
            updateLoadingState(message, true);
        }

        function loadGameScript() {
            updateLoadingState('Downloading game bundle...', false);
            var gameScript = document.createElement('script');
            gameScript.src = gameScriptPath;
            gameScript.async = true;
            gameScript.addEventListener('load', function() {
                if (typeof Love === 'function') {
                    loaderElement.style.display = 'none';
                    if (virtualKeyboard) {
                        virtualKeyboard.style.display = 'flex';
                    }
                    Love(Module);
                } else {
                    handleRuntimeError('love.js runtime failed to expose Love(Module).');
                }
            });
            gameScript.addEventListener('error', function(event) {
                handleRuntimeError('Unable to load compiled game script.', event);
            });
            document.body.appendChild(gameScript);
        }

        function attachRuntime() {
            var runtimeScript = document.createElement('script');
            runtimeScript.src = ']] .. loveJsPath .. [[';
            runtimeScript.async = true;
            runtimeScript.addEventListener('load', function() {
                loadGameScript();
            });
            runtimeScript.addEventListener('error', function(event) {
                handleRuntimeError('Unable to load love.js runtime.', event);
            });
            document.body.appendChild(runtimeScript);
        }

        startButton.addEventListener('click', function() {
            if (runtimeAttached) {
                return;
            }

            runtimeAttached = true;
            startButton.disabled = true;
            startButton.textContent = 'Launching...';
            updateLoadingState('Downloading love.js runtime...', false);
            attachRuntime();
        });

        if (virtualKeyboard) {
            virtualKeyboard.addEventListener('click', function(event) {
                var target = event.target;
                if (!target.classList.contains('key-button')) {
                    return;
                }
                var key = target.getAttribute('data-key');
                var code = target.getAttribute('data-code');
                if (!key || !code) {
                    return;
                }
                var keyboardEvent = new KeyboardEvent('keydown', { key: key, code: code });
                Module.canvas.dispatchEvent(keyboardEvent);
                setTimeout(function() {
                    var upEvent = new KeyboardEvent('keyup', { key: key, code: code });
                    Module.canvas.dispatchEvent(upEvent);
                }, 100);
            });
        }
    </script>
</body>
</html>]]

    return html
end

return html_template
