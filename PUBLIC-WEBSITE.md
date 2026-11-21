# Public website and assets

The public-facing homepage is rendered by `src/App.tsx` whenever a visitor is not signed in. It includes the marketplace search and filters, public product listings, buyer/seller sign-up and login, how-it-works, farmer community, buyer-protection information and footer. Signed-in users are routed to the authenticated dashboard.

The `public/` directory contains files copied directly into the production build:

- `images/marketplace-hero.svg` — public hero artwork
- `images/seed-potatoes.svg` — seed listing image
- `images/ware-potatoes.svg` — ware potato listing image
- `images/farmer-community.svg` — farmer community artwork
- `icons/icon.svg` — site icon
- `site.webmanifest` — installable web-app metadata
- `robots.txt` — search crawler instructions
- `.nojekyll` — prevents GitHub Pages Jekyll processing

All app images use Vite's configured `/potatomarket/` base path so they resolve on this GitHub Pages repository URL.
