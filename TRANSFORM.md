## Goal
Modify the existing Psychosims game repository to produce a fully offline-capable, static Flutter web Progressive Web App (PWA) hosted via GitHub Pages at https://psychosim.com, with the domain registered at Namecheap. The app must preserve core gameplay, content, visual style, and mechanics, removing all backend dependencies and server services, while supporting offline operation, deep linking, and responsiveness across devices. The AI-driven patient simulation should function with online API requests for new responses, but all game state, transcripts, and assets must be available offline after initial caching.

## Context and Details
- The current repository is hosted on GitHub; deployment will use GitHub Actions for Pages publishing.
- The domain https://psychosim.com is registered at Namecheap; DNS settings, custom domain configuration, HTTPS, and redirect rules must be verified and documented according to official GitHub and Namecheap documentation.
- The app must be configured for static hosting, with correct base paths, asset paths, manifest start_url/scope, and service worker scope, ensuring deep link and reload support without server rewrite rules.
- The existing Flutter codebase must be modified to:
  - Remove all backend, server, or database dependencies; only static assets, fonts, and audio bundled within the build.
  - Use the OpenRouter APIs for AI patient simulation, adapting logic from:
    - https://github.com/consciontologic/worthhit/blob/main/docs/ARCHITECTURE.md (favoring Worthhit’s memory-only user key lifecycle, validated catalog, static-only cache, and privacy defaults)
    - https://github.com/consciontologic/wfform/blob/main/lib/features/chat/chat_api.dart and https://github.com/consciontologic/wfform/blob/main/docs/chat.md (for chat lifecycle, SSE handling, timeouts, retries, partial output preservation, and no silent replays)
  - Ensure AI requests are made only when online; offline mode preserves game state, transcripts, and local mechanics, pausing AI actions as needed.
- The app must cache all resources after initial load, support offline operation, and prevent caching of sensitive API keys or tokens.
- The design must be responsive, optimized for mobile (safe areas, touch controls), tablet (balanced space), and desktop (pointer, keyboard, hover). Core widgets and game state management should be reused; UI must be accessible, with high contrast, focus outlines, reduced motion, and clear touch targets.
- The game’s existing patient scenarios, dialogue, and progression must be maintained coherently, with model output validated before applying to game state.
- The implementation must include:
  - A GitHub Actions workflow for deployment
  - Instructions for domain verification, DNS setup, HTTPS, and custom domain configuration
  - Documentation on build, offline behavior, caching strategy, and hosting considerations
- Testing must verify:
  - Offline reload and persistence of saved data
  - Deep linking and navigation
  - Responsiveness at widths 360px, 768px, 1440px, and intermediate sizes
  - Installability and offline caching
  - Deterministic AI interactions with mocked responses for testing
- No code or secrets should be committed or pushed before review; all changes are staged and documented for approval.
- The final deliverable includes a production Flutter web build, comprehensive documentation, and a report on implementation outcomes, with no backend or secrets bundled.

## Response Format
Implement the changes end to end. Do not stop at a plan, snippets, or recommendations. Preparation, code edits, testing, documentation, required tracking, and staging are authorized. Only live publication or external DNS/account changes require a separate decision; prepare them fully first. Follow AGENTS.md; NEVER git commit or push. Finish with evidence of implemented changes and tests, plus any external setup still needed.

- Modify the existing repository to produce a tested, working, offline-capable Flutter web PWA hosted on GitHub Pages at https://psychosim.com.
- Include code snippets for configuration files, deployment workflows, and domain setup.
- Verify DNS, HTTPS, and custom domain setup, providing detailed instructions.
- Adapt AI integration logic from:
  - https://github.com/consciontologic/worthhit (favoring memory-only user key, validated catalog, static cache, privacy defaults)
  - https://github.com/consciontologic/wfform (chat lifecycle, SSE, retries, partial output)
- Ensure the app caches all resources after initial load, supports offline operation, and does not cache sensitive API keys.
- Maintain original visual design, responsiveness, and accessibility features, including UI at 360px, 768px, 1440px, and during resizing.
- Validate that patient scenarios, dialogue, and progression are preserved, with model output validated before application.
- Prepare deployment workflows, DNS instructions, and domain verification steps.
- Document the build process, offline support, caching strategy, and hosting considerations.
- Conduct and document tests for offline reload, save persistence, deep linking, responsiveness, and installability.
- Do not commit or push code or secrets before review; stage all changes and provide evidence of implementation and testing.
- Include any remaining manual steps for domain verification and deployment approval.
