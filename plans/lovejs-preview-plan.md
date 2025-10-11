# Love.js Preview Plan

- **Status:** In Progress
- **Owner:** Engineering
- **Last Updated:** 2025-10-15

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

### Phase 2 - Automated Preview Publishing *(Planned)*
- Publish the preview bundle to GitHub Pages or a static site bucket on every successful build.
- Gate publishing on main branch builds while keeping artifact uploads for pull requests.

### Phase 3 - Scenario Matrix *(Planned)*
- Extend the packaging workflow to generate multiple `.love` archives that boot into specific scenarios for focused QA sessions.
- Offer a small HTML launcher menu that links to each scenario-specific preview.

## Acceptance Criteria
- CI runs Love2D unit tests and linting before attempting to build the preview package.
- Preview artifacts include `index.html`, `love.js` runtime files, and the packaged `game.love` archive.
- Artifact download links appear on pull request checks, allowing reviewers to manually verify tactical combat updates in the browser.
- Documentation explains how to run the preview generator locally and where CI publishes the outputs.
