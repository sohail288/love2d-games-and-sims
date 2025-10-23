# Love.js Preview Plan

- **Status:** In Progress
- **Owner:** Engineering
- **Last Updated:** 2025-10-22

## High Level Overview
Create a CI-friendly packaging pipeline that bundles the tactical battle prototype as a `.love` archive, combines it with the `love.js` runtime, and emits a browser-playable preview. The preview artifact should be accessible from pull requests and nightly builds so design collaborators can review updates without installing the native Love2D runtime.

## Phases of Implementation

### Phase 1 - Pipeline Scaffolding *(Complete)*
- Author reusable Lua helpers that output the HTML shell expected by the `love.js` runtime.
- Configure GitHub Actions to run unit tests, linting, package the tactical battle project as a `.love` file, and download the `love.js` runtime.
- Upload the assembled preview bundle as a build artifact for manual download.
- *2025-10-14:* Upgraded the preview artifact upload step to `actions/upload-artifact@v4` to comply with GitHub's deprecation schedule.
- *2025-10-14:* Switched the Lua installer step to `leafo/gh-actions-lua@v11` with caching disabled after GitHub's cache service began returning HTTP 400 errors during setup.
- *2025-10-15:* Tightened the lint discovery command to only emit Lua source files after the Lua installer action started dropping a `.lua` directory into the workspace.
- *2025-10-15:* Added an explicit `-not -path './.lua/*'` guard to skip the contents of installer-created `.lua` directories entirely.
- *2025-10-16:* Introduced a `detect_luac` helper so the lint step resolves the installed Lua compiler path before invoking syntax checks.
- *2025-10-16:* Converted the helper to a POSIX shell script so CI no longer requires a Lua interpreter to locate the compiler.
- *2025-10-21:* Ensured the CI workflow installs `lua5.1` so `luac` is always available and added an override hook when custom toolchains are required.
- *2025-10-22:* Migrated the preview bundling step to the maintained `love.js` npm release for LÖVE 11.5 and now build the compatibility runtime with `npx love.js -c` to avoid stale downloads.

### Phase 2 - Automated Preview Publishing *(In Progress)*
- Publish the preview bundle to GitHub Pages or a static site bucket on every successful build.
    - *2025-10-22:* Added a GitHub Pages deployment step to the preview workflow. Builds now push the generated bundle to the `github-pages` environment and expose a browser-playable link without requiring a manual download.
    - *2025-10-23:* Updated the preview HTML shell to invoke `Love(Module)` after the runtime downloads and to surface loader status so GitHub Pages visitors no longer see a blank canvas when the script finishes downloading.
    - *2025-10-24:* Standardized the preview canvas id to `canvas` so the love.js compatibility runtime can attach pointer and mouse events without throwing `addEventListener` errors during initialization.
    - *2025-10-24:* Introduced a manifest-driven preview planner that zips each changed game, rebuilds its love.js bundle, and emits an index so reviewers can swap between projects from a single launcher.
    - *2025-10-25:* Sequenced the loader to fetch `love.js` first and then stream the compiled `game.js` bundle, updating status text for each phase so reviewers immediately see progress instead of a blank canvas.
    - *2025-10-25:* Hardened the preview builder to accept the boolean success codes returned by Lua 5.4's `os.execute`, fixing local tooling runs that previously crashed before packaging archives.
- Gate publishing on main branch builds while keeping artifact uploads for pull requests.

### Phase 3 - Scenario Matrix *(Planned)*
- Extend the packaging workflow to generate multiple `.love` archives that boot into specific scenarios for focused QA sessions.
- Offer a small HTML launcher menu that links to each scenario-specific preview.

## Acceptance Criteria
- CI runs Love2D unit tests and linting before attempting to build the preview package.
- Preview artifacts include `index.html`, `love.js` runtime files, and the packaged `game.love` archive.
- Artifact download links appear on pull request checks, allowing reviewers to manually verify tactical combat updates in the browser.
- Successful runs surface a GitHub Pages deployment URL so stakeholders can play the preview without downloading the artifact zip.
- Documentation explains how to run the preview generator locally and where CI publishes the outputs.
