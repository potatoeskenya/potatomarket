# GitHub Pages deployment

1. Upload the CONTENTS of this ZIP to the root of `potatoeskenya/potatomarket`, replacing existing files. Make sure hidden `.github` folder is included.
2. Commit to branch `main`.
3. Open repository Settings → Pages → Build and deployment → Source and select **GitHub Actions**.
4. Open Actions and confirm both Build and Deploy jobs pass in `Build and deploy Vite app to GitHub Pages`.
5. Visit https://potatoeskenya.github.io/potatomarket/ and refresh.

The Vite base path is `/potatomarket/`, matching this repository's Pages URL. GitHub Actions publishes `dist/`, not the raw TypeScript source.
