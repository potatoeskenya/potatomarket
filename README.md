# Kenya Potato Farmers Marketplace

A national potato trading and farmer-community application for all 47 counties. The repository now includes buyer/seller/admin/transporter workspaces, a product marketplace, private chat moderation, farmer groups and projects, transport and delivery workflows, certification review, payment reconciliation, payout/refund adapters and automated security regression tests.

## Product decisions
- Free registration for buyers, sellers, dual-role members and transporters.
- National coverage: all 47 Kenyan counties.
- Platform commission: 2%, calculated server-side when an order is created.
- Farmer registration: free.
- Additional revenue: buyer/seller subscriptions and paid featured listings (payment activation requires the monetization Edge Functions and M-Pesa verification workflow).
- Seller payout: queued only after the buyer confirms receipt.
- M-Pesa collection through Daraja STK Push.
- Seller disbursement through a separately approved B2C/PSP adapter.
- Private platform messaging with contact-sharing and off-platform payment detection.
- Certified seed badges are applied only after administrator verification.

## Important legal and payment boundary
This software is not itself a licensed escrow institution or a payment service provider. Safaricom Daraja STK Push does not automatically create a legally safeguarded escrow balance. Before taking real customer funds and holding them until delivery, contract a licensed bank/payment service provider that supports the intended safeguarded collection, refunds, reconciliation and seller disbursement arrangement. Obtain Kenyan legal/compliance advice. Do not describe funds held in an ordinary business till as escrow.

The included Daraja B2C payout and reversal adapters are gated. They remain disabled until the platform has the appropriate provider onboarding, credentials, safeguards and written authorization. An accepted payout request is not a completed payout; only the provider result callback changes the payout to `paid`.

## 1. Run locally

```bash
npm install
cp .env.example .env
npm run dev
```

Set `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` in `.env`. Only the Supabase URL and anon key belong in the frontend. Never put the Supabase service-role key or Daraja secrets in Vite variables.

## 2. Supabase setup

1. Create a new Supabase project dedicated to this marketplace.
2. Open SQL Editor and run the migrations in order:
   - `supabase/migration/202611210001_initial_marketplace.sql`
   - `supabase/migration/202611210002_marketplace_operations.sql`
   - `supabase/migration/202611220001_monetization.sql`
3. Deploy the private `certification-documents` storage bucket policies from the second migration.
4. Enable email verification and configure the allowed redirect URLs in Supabase Auth.
5. Add the frontend environment variables to your hosting provider.
6. Create the first administrator using the SQL instruction below.

The migrations enable RLS, prevent public admin signup and role escalation, protect seller ratings, and force message inserts through the moderation Edge Function.

## 3. Deploy Edge Functions

Install the Supabase CLI, log in, and link your project:

```bash
supabase login
supabase link --project-ref YOUR_PROJECT_REF
```

Deploy the functions:

```bash
supabase functions deploy create-payment
supabase functions deploy mpesa-callback --no-verify-jwt
supabase functions deploy release-payout
supabase functions deploy process-payout
supabase functions deploy payout-callback --no-verify-jwt
supabase functions deploy process-refund
supabase functions deploy refund-callback --no-verify-jwt
supabase functions deploy reconcile-payments
supabase functions deploy moderate-message
supabase functions deploy update-order-status
supabase functions deploy admin-resolve-dispute
```

The callback functions intentionally disable Supabase JWT verification because Safaricom does not send a user JWT. Each callback additionally checks a long random URL token, and the STK callback independently queries Daraja before changing payment state. Use HTTPS and restrict callback traffic at your hosting/network layer where supported.

## 4. Edge Function secrets

Set secrets through the Supabase CLI or Dashboard > Edge Functions > Secrets. Generate different long random values for each callback token.

### M-Pesa collection
- `DARAJA_ENV=sandbox` (use `production` only after approval)
- `PAYMENT_PROVIDER_MODE=daraja` (leave `demo` until configured)
- `DARAJA_CONSUMER_KEY`
- `DARAJA_CONSUMER_SECRET`
- `DARAJA_SHORTCODE`
- `DARAJA_PASSKEY`
- `DARAJA_CALLBACK_TOKEN`
- `DARAJA_CALLBACK_URL=https://PROJECT.supabase.co/functions/v1/mpesa-callback?token=CALLBACK_TOKEN`

### Seller payouts (B2C or approved PSP)
- `PAYOUT_AUTHORIZED=false` by default
- `PAYOUT_PROVIDER_MODE=disabled` by default; set `daraja_b2c` only after onboarding and approval
- `DARAJA_B2C_INITIATOR_NAME`
- `DARAJA_B2C_SECURITY_CREDENTIAL`
- `DARAJA_B2C_SHORTCODE`
- `PAYOUT_CALLBACK_TOKEN`
- `DARAJA_B2C_RESULT_URL=https://PROJECT.supabase.co/functions/v1/payout-callback?token=PAYOUT_TOKEN`
- `DARAJA_B2C_TIMEOUT_URL` (same callback path with token, or provider-approved timeout endpoint)

### Refund reversals
- `REFUND_AUTHORIZED=false` by default
- `DARAJA_REVERSAL_INITIATOR_NAME`
- `DARAJA_REVERSAL_SECURITY_CREDENTIAL`
- `REFUND_CALLBACK_TOKEN`
- `DARAJA_REVERSAL_RESULT_URL=https://PROJECT.supabase.co/functions/v1/refund-callback?token=REFUND_TOKEN`
- `DARAJA_REVERSAL_TIMEOUT_URL` (provider-approved timeout callback URL)

Supabase supplies `SUPABASE_URL`, `SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_ROLE_KEY` to Edge Functions. Never paste the service-role key into frontend source.

## 5. First administrator

1. Register a normal account.
2. Open Supabase Dashboard > Authentication > Users and copy that user's UUID.
3. Run in SQL Editor:

```sql
update public.profiles set role = 'admin' where id = 'PASTE-USER-UUID-HERE';
```

Do not expose administrator creation in the public signup form. The database trigger blocks self-service role escalation.

## 6. Automated checks

Run:

```bash
npm test
```

The current Node test suite checks key security invariants: no public admin signup, message moderation-only inserts, callback reconciliation/idempotency, buyer-confirmation payout gates, refund approval gates and the 2% commission rule. These are regression tests, not a substitute for full end-to-end tests against a Supabase staging project and Safaricom sandbox.

Before launch, also test: registration and email verification; RLS as buyer/seller/transporter/admin; product creation; order stock locking; duplicate STK attempts; success/failure/cancelled callbacks; provider query reconciliation; delivery state transitions; payout callback success/failure; refund reversal; certificate file access; and backup/restore.

## 7. Hosting

Build with `npm run build`. For GitHub Pages, set Vite `base` to the repository path and deploy `dist`. A production domain with SPA fallback/rewrite support is recommended for authentication redirects and deep links.

## 8. Known production prerequisites

- Real Supabase project credentials and deployed migrations/functions.
- Safaricom Daraja sandbox and production credentials.
- Approved safeguarded collection and payout provider arrangement.
- Provider approval for B2C payouts and reversal APIs.
- Verified seller payout accounts.
- Legal terms, privacy notice, refund policy, moderation appeals and seller terms.
- Independent penetration test and operational monitoring.

Demo marketplace records are illustrative only. Never treat demo product listings, certification labels or transaction states as real offers or proof of payment.
