# Trade Tracker

A trading journal hosted on GitHub Pages with Supabase email/password accounts and private per-account journal data.

## Configure Supabase

1. Create a Supabase project.
2. In the Supabase SQL Editor, run [`supabase/schema.sql`](./supabase/schema.sql). This creates the journal table and row-level security policies that restrict each account to its own data.
3. In [`supabase-config.js`](./supabase-config.js), set `supabaseUrl` and `supabaseAnonKey` using the project's URL and public anon/publishable key. These browser values are public; **never** put a service-role key in this file.
4. In Supabase Authentication settings, enable email/password sign-in and configure the site URL and redirect URLs to include `https://mihir038.github.io/trade-tracker/`.
5. Push the changes to `main`. GitHub Actions deploys the site.

Email confirmation may be required before a new account can sign in. Passwords are handled by Supabase Auth and are never stored in the repository or journal table.

## Data and privacy

Each account's trades, strategies, notes, settings, and chart images are stored in the Supabase database. Row-level security restricts access to the signed-in account. The site source and public Supabase key are visible because this is a public GitHub Pages site; database privacy depends on applying the included SQL policies. Keep regular backups using the app's export feature.

Existing browser-only data is not copied automatically between profiles. Sign in to the intended account and use **Import old browser data** in Settings if you want to move the data from that browser into that account.

## Deployment

Every push to `main` deploys the site through GitHub Actions. GitHub Pages must use **GitHub Actions** as its source.
