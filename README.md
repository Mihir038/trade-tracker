# Trade Tracker

A trading journal hosted on GitHub Pages with Supabase email/password accounts and private per-account journal data.

## Configure Supabase

1. Create a Supabase project.
2. In the Supabase SQL Editor, run [`supabase/schema.sql`](./supabase/schema.sql). This creates the journal table and row-level security policies that restrict each account to its own data.
3. To enable the administrator panel, also run [`supabase/admin.sql`](./supabase/admin.sql) once in the SQL Editor. It grants administrator rights only to a confirmed Supabase account whose email is `admin@jaymaharaj.in`. Sign out and back in after running the script.
4. In [`supabase-config.js`](./supabase-config.js), set `supabaseUrl` and `supabaseAnonKey` using the project's URL and public anon/publishable key. These browser values are public; **never** put a service-role key in this file.
5. In Supabase Authentication settings, enable email/password sign-in and configure the site URL and redirect URLs to include `https://mihir038.github.io/trade-tracker/`.
6. Push the changes to `main`. GitHub Actions deploys the site.

Email confirmation may be required before a new account can sign in. Passwords are handled by Supabase Auth and are never stored in the repository or journal table.

## Data and privacy

Each account's trades, strategies, notes, settings, and chart images are stored in the Supabase database. Row-level security restricts access to the signed-in account. If you apply `supabase/admin.sql`, the designated administrator can also view, edit, and delete every journal, list accounts, and permanently delete accounts. Only run this script if that level of access is intended. Keep regular backups using the app's export feature.

The Admin page is available after signing in with `admin@jaymaharaj.in`. It can add, edit, and delete videos, Reference Library topics, and Chart Tools Guide entries. The first time, choose **Restore built-in library** to publish the current learning material to the shared database; later edits are published to all signed-in users. The administrator is checked by Supabase database policies and functions, not by the visible Admin link.

Existing browser-only data is not copied automatically between profiles. Sign in to the intended account and use **Import old browser data** in Settings if you want to move the data from that browser into that account.

## Deployment

Every push to `main` deploys the site through GitHub Actions. GitHub Pages must use **GitHub Actions** as its source.
