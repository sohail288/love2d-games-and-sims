# Love.js Preview Plan

- **Status:** In Progress
- **Owner:** Engineering
- **Last Updated:** 2025-10-13

## High Level Overview
Create a CI-friendly packaging pipeline that bundles the tactical battle prototype as a `.love` archive, combines it with the `love.js` runtime, and emits a browser-playable preview. The preview artifact should be accessible from pull requests and nightly builds so design collaborators can review updates without installing the native Love2D runtime.

## Phases of Implementation

### Phase 1 - Pipeline Scaffolding *(Complete)*
- Author reusable Lua helpers that output the HTML shell expected by the `love.js` runtime.
- Configure GitHub Actions to run unit tests, linting, package the tactical battle project as a `.love` file, and download the `love.js` runtime.
- Upload the assembled preview bundle as a build artifact for manual download.

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
