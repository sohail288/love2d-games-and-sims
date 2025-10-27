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
            padding-bottom: 7rem;
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
            position: fixed;
            bottom: 1rem;
            left: 50%;
            transform: translateX(-50%);
            width: calc(100% - 2rem);
            max-width: 520px;
            display: none;
            flex-direction: column;
            gap: 0.5rem;
            z-index: 10;
        }
        #virtual-keyboard[data-enabled="true"] {
            display: flex;
        }
        .vk-row {
            display: flex;
            justify-content: center;
            gap: 0.5rem;
        }
        .vk-key {
            flex: 1;
            padding: 0.75rem 0;
            font-size: 1.1rem;
            background: rgba(30, 64, 175, 0.85);
            border-radius: 0.75rem;
            border: 1px solid rgba(148, 163, 184, 0.35);
            backdrop-filter: blur(6px);
        }
        .vk-key:hover,
        .vk-key:focus {
            background: rgba(37, 99, 235, 0.9);
        }
        .vk-key.pressed {
            background: rgba(29, 78, 216, 1);
            transform: translateY(1px);
        }
        .vk-key--wide {
            flex: 2.25;
        }
        .vk-key--spacer {
            flex: 0.5;
            visibility: hidden;
        }
    </style>
</head>
<body>
    <div id="loader">
        <p id="loading-text">]] .. loadingMessage .. [[</p>
        <button id="start-button" type="button">]] .. startButtonLabel .. [[</button>
    </div>
    <canvas id="canvas" oncontextmenu="event.preventDefault()"></canvas>
    <div id="virtual-keyboard" hidden>
        <div class="vk-row">
            <button type="button" class="vk-key vk-key--wide" data-key="ArrowUp" aria-label="Move up">▲</button>
        </div>
        <div class="vk-row">
            <button type="button" class="vk-key" data-key="ArrowLeft" aria-label="Move left">◀</button>
            <button type="button" class="vk-key" data-key="ArrowDown" aria-label="Move down">▼</button>
            <button type="button" class="vk-key" data-key="ArrowRight" aria-label="Move right">▶</button>
        </div>
        <div class="vk-row">
            <button type="button" class="vk-key" data-key="z" aria-label="Primary action">A</button>
            <button type="button" class="vk-key" data-key="x" aria-label="Secondary action">B</button>
            <div class="vk-key vk-key--spacer" aria-hidden="true"></div>
            <button type="button" class="vk-key" data-key="Enter" aria-label="Start">Start</button>
            <button type="button" class="vk-key" data-key="Escape" aria-label="Menu">Menu</button>
        </div>
    </div>
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
        var activeVirtualKeys = Object.create(null);

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

        var virtualKeyCodeMap = {
            ArrowUp: 38,
            ArrowDown: 40,
            ArrowLeft: 37,
            ArrowRight: 39,
            Enter: 13,
            Escape: 27,
            z: 90,
            x: 88
        };

        function createKeyboardEvent(type, key) {
            var keyCode = virtualKeyCodeMap[key] || key.toUpperCase().charCodeAt(0);
            var eventInit = {
                key: key,
                code: key,
                keyCode: keyCode,
                which: keyCode,
                bubbles: true,
                cancelable: true,
                composed: true
            };

            var event;

            try {
                event = new KeyboardEvent(type, eventInit);
            } catch (error) {
                var legacyEvent = document.createEvent('KeyboardEvent');
                legacyEvent.initKeyboardEvent(type, true, true, window, key, 0, '', false, key);
                event = legacyEvent;
            }

            if (!('keyCode' in event) || event.keyCode === 0) {
                Object.defineProperty(event, 'keyCode', {
                    get: function() {
                        return keyCode;
                    }
                });
            }

            if (!('which' in event) || event.which === 0) {
                Object.defineProperty(event, 'which', {
                    get: function() {
                        return keyCode;
                    }
                });
            }

            return event;
        }

        function dispatchVirtualKey(type, key) {
            var canvas = Module.canvas;
            if (!canvas) {
                return;
            }

            var keyCode = virtualKeyCodeMap[key] || key.toUpperCase().charCodeAt(0);
            var targets = [canvas, document, window];

            targets.forEach(function(target) {
                if (!target) {
                    return;
                }

                var event = createKeyboardEvent(type, key);

                if (!('keyCode' in event) || event.keyCode === 0) {
                    try {
                        event.keyCode = keyCode;
                    } catch (assignError) {
                        /* ignore assignment errors when keyCode is readonly */
                    }
                }

                target.dispatchEvent(event);
            });
        }

        function shouldEnableVirtualKeyboard() {
            return 'ontouchstart' in window || (typeof navigator !== 'undefined' && navigator.maxTouchPoints > 0);
        }

        function setupVirtualKeyboard() {
            var virtualKeyboard = document.getElementById('virtual-keyboard');
            if (!virtualKeyboard || !shouldEnableVirtualKeyboard()) {
                return;
            }

            virtualKeyboard.removeAttribute('hidden');
            virtualKeyboard.setAttribute('data-enabled', 'true');

            var canvas = Module.canvas;
            var keyButtons = virtualKeyboard.querySelectorAll('[data-key]');

            function releaseKey(key) {
                if (!activeVirtualKeys[key]) {
                    return;
                }

                delete activeVirtualKeys[key];
                dispatchVirtualKey('keyup', key);
            }

            keyButtons.forEach(function(button) {
                var key = button.getAttribute('data-key');
                if (!key) {
                    return;
                }

                button.addEventListener('pointerdown', function(event) {
                    event.preventDefault();
                    if (canvas && typeof canvas.focus === 'function') {
                        canvas.focus();
                    }

                    if (activeVirtualKeys[key]) {
                        return;
                    }

                    activeVirtualKeys[key] = true;
                    button.classList.add('pressed');
                    dispatchVirtualKey('keydown', key);
                    if (typeof button.setPointerCapture === 'function') {
                        try {
                            button.setPointerCapture(event.pointerId);
                        } catch (captureError) {
                            /* ignore capture errors on unsupported browsers */
                        }
                    }
                });

                button.addEventListener('pointerup', function(event) {
                    event.preventDefault();
                    button.classList.remove('pressed');
                    releaseKey(key);
                });

                button.addEventListener('pointercancel', function(event) {
                    event.preventDefault();
                    button.classList.remove('pressed');
                    releaseKey(key);
                });

                button.addEventListener('pointerleave', function(event) {
                    if (!button.classList.contains('pressed')) {
                        return;
                    }

                    event.preventDefault();
                    button.classList.remove('pressed');
                    releaseKey(key);
                });
            });

            window.addEventListener('blur', function() {
                Object.keys(activeVirtualKeys).forEach(function(key) {
                    var button = virtualKeyboard.querySelector('[data-key="' + key + '"]');
                    if (button) {
                        button.classList.remove('pressed');
                    }
                    releaseKey(key);
                });
            });
        }

        setupVirtualKeyboard();

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
    </script>
</body>
</html>]]

    return html
end

return html_template
