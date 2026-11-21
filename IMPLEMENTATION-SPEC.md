# Implementation Specification — Kenya Potato Farmers Marketplace

## Product configuration
- Name: Kenya Potato Farmers Marketplace
- Scope: all 47 counties in Kenya
- Commission: 5% per successful sale, calculated in PostgreSQL
- Registration: buyer, seller, buyer-and-seller, transporter
- Administrator: provisioned manually by a trusted owner
- Payout trigger: buyer receipt confirmation after dispatch/delivery

## User workspaces

### Buyer
- Browse active national listings and seller profiles.
- Create orders and initiate M-Pesa STK Push.
- Track payment/order status.
- Start private seller conversations.
- Request transport/delivery.
- Confirm receipt.
- Open a dispute or refund request.
- Review sellers after a completed order (database ties review to the correct seller).

### Seller
- Publish and manage seed/ware/farm-input listings.
- Submit seed certification evidence to private storage.
- View orders and mark dispatch through a server-validated state transition.
- Chat with buyers through the moderation function.
- Save a seller M-Pesa payout number for administrator verification.
- View payout status and net proceeds after the 5% commission.

### Transporter
- Register vehicle, load capacity, county, route and indicative price.
- View delivery assignments where assigned.
- Update delivery through the supported delivery statuses.

### Administrator
- Review users and roles.
- Review seed certification evidence and approve/reject certificates.
- Verify seller payout numbers.
- Review all disputes/refund requests.
- Process only approved and eligible payout/refund requests after provider configuration.
- Reconcile pending M-Pesa STK payments with Daraja.
- Inspect audit and moderation events.

## Community
- Public farmer groups and membership.
- Farming project posts.
- Scheduled farmer meetings.
- Community content is subject to moderation and RLS.

## Database

The first migration creates core identities, products, seed certifications, orders, order items, payments, payouts, reviews, conversations, messages, notifications, disputes, sanctions, groups, projects, opportunities, meetings, audit logs and the server-side order creation function.

The second migration adds transporters, deliveries, refund requests, moderation events and payout-provider events. It hardens public signup and profile role changes, prevents reputation self-editing, restricts message inserts to the moderation Edge Function, ties reviews and certification submissions to the correct order/listing, and constrains refund and delivery inserts.

## Transaction lifecycle
1. `create_marketplace_order` locks stock, snapshots price and computes the 5% commission.
2. Buyer calls `create-payment`; duplicate pending payment prompts are rejected.
3. Daraja callback is authenticated with a separate random callback token and independently queried through STK Push Query.
4. Only reconciled payment success changes payment to `succeeded` and order to `paid`.
5. Seller moves the order to `processing`/`dispatched` using `update-order-status`.
6. Buyer confirms receipt using `release-payout`; open disputes block payout queueing.
7. A payout record is queued with gross, commission and net amounts.
8. Administrator invokes `process-payout` only after provider onboarding, verified seller payout account and `PAYOUT_AUTHORIZED=true`.
9. Provider callback alone marks payout `paid` or `failed`.

## Messaging and contact moderation
All message writes must pass through `moderate-message`. Direct participant inserts are removed from RLS. The function validates the conversation participant, blocks likely Kenyan phone/email/contact exchange and off-platform payment requests, and writes an admin-only moderation event. It deliberately uses warning/block-and-review rather than automatic permanent bans based only on digit patterns, to reduce false positives and preserve an appeal path.

## Refund and dispute lifecycle
- A buyer can open a dispute or request a refund up to the order amount.
- Administrator reviews the request.
- `process-refund` requires admin identity, approved request, matching successful M-Pesa payment and `REFUND_AUTHORIZED=true`.
- Daraja reversal result callback records final status; a request submission is not treated as a completed refund.

## Security boundaries
- Supabase service-role and provider secrets exist only in Edge Function environment.
- Public signup cannot set admin role.
- Users cannot self-edit role, verified state, rating or rating count.
- Products cannot self-assert certification.
- Order/payment/payout state transitions are server-side.
- Private certification documents are stored in a non-public bucket.
- Callback endpoints disable JWT only because providers cannot present user JWTs; they require separate random URL tokens and payment callback independently verifies STK status.
- Financial actions require audit events.

## Test status
`npm test` runs six Node regression checks over the critical database/function security invariants. Production readiness additionally requires a staged Supabase integration suite, Safaricom sandbox tests, provider-specific reconciliation tests, privacy/terms review and independent penetration testing.

## External dependencies still required
This repository cannot activate live payments without the user's own Supabase project, Safaricom credentials, callback deployment, provider-approved safeguarded funds flow, B2C/reversal approval and verified merchant onboarding. Those account-specific secrets must be supplied by the platform owner and must not be embedded in the ZIP.
