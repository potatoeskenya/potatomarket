# White-screen and filename compatibility fix

This project is a Vite + React + TypeScript application. Its actual app entry is `src/App.tsx` and its actual stylesheet is `src/styles.css` (lowercase). Those are valid source files; Vite compiles them into browser-ready assets. To accommodate workflows/editors expecting the names mentioned by the project owner, this package also includes `src/App.js` and `src/Style.css` compatibility files.

The application entrypoint `src/main.tsx` explicitly imports `App.tsx` and `styles.css` so there is no ambiguity or case-sensitive filename mismatch.

## GitHub Pages
- Keep `vite.config.ts` base set to `/potatomarket/`.
- In Settings > Pages, choose GitHub Actions.
- Ensure `.github/workflows/deploy.yml` exists at repository root.
- The workflow must run `npm install`, `npm run build`, and publish `dist/`.
- In Actions, inspect BOTH build and deploy jobs. A successful deployment alone does not prove the browser app has no runtime errors.

If the page is still white after this package is deployed, send the failed build log or browser console error; the next correction must be based on that exact error.
