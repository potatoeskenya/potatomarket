# Security Review and Launch Gate

## Controls implemented in this codebase
- Public signup is restricted to buyer, seller, dual-role and transporter. Administrator role is assigned manually by trusted SQL only.
- Profile trigger blocks self-service role, verification and reputation changes.
- Seller ratings are derived from transaction-linked reviews; seller leaderboard uses these aggregates and completed-order metrics.
- Product certification fields are reset for non-admin writes; certification evidence is stored in a private bucket.
- Orders are created by a server-side RPC that locks product stock and calculates the fixed 5% commission.
- Clients cannot directly update order/payment/payout financial states.
- STK Push callback requires a separate callback token and independent provider query before payment success is recorded.
- Pending STK payment retries are blocked to prevent duplicate prompts.
- Buyer confirmation requires a dispatched/delivered order and verified payment; open disputes hold payout.
- Payout processing requires admin identity, completed order, buyer confirmation, verified seller payout account, provider mode and explicit authorization flag.
- Refund processing requires admin identity, approved request, successful payment and explicit provider authorization.
- Provider callbacks use separate random tokens and only provider callbacks set final payout/refund states.
- All message inserts are routed through the contact moderation Edge Function; direct authenticated table inserts are removed.
- Delivery IDs are checked against the actual order participants; transporter role is required to register transport capacity.
- Admin financial/moderation actions are audit logged where implemented.

## Known limitations / required external controls
1. **Funds safeguarding:** The app is not an escrow license or safeguarded account. Contract a licensed Kenyan PSP/bank for collection, custody, refund and disbursement before live customer funds are accepted.
2. **Daraja approvals:** STK Push, B2C and reversal products require the merchant's own Safaricom onboarding, credentials and provider configuration. B2C and reversals remain disabled by default.
3. **Callback protection:** Random URL tokens and STK query verification are included. Confirm Safaricom's current callback security/network requirements and add provider IP/network allowlisting where supported.
4. **Human moderation:** Contact patterns are blocked and queued for admin review. Do not auto-ban or confiscate funds based on a digit-pattern match. Provide notice, appeal and manual review.
5. **Identity and payout ownership:** Seller payout phone ownership needs a real verification step/OTP or provider account validation before an administrator marks it verified.
6. **Rate limiting:** Add edge/API rate limits for authentication, chat, order creation, certificate uploads and payment requests.
7. **File safety:** Add malware scanning and strict file-content validation for uploaded certificates and delivery proof.
8. **Privacy/legal:** Publish terms, privacy notice, data retention, refund/dispute, seller and transporter agreements, and moderation appeal policy. Obtain Kenyan data-protection and payments advice.
9. **Operations:** Enable Supabase backups, point-in-time recovery where available, error monitoring, alerting, reconciliation schedules and incident response procedures.
10. **Independent testing:** Run end-to-end tests in a staging Supabase project and Safaricom sandbox, then commission an independent penetration test before production launch.

## Automated tests
Run `npm test`. Eight Node regression tests currently verify selected security invariants. They do not prove runtime correctness of Supabase policies or external provider behavior; integration tests and staging verification remain mandatory.
