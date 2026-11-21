import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const read=(p)=>readFileSync(resolve(root,p),'utf8');

test('public signup cannot grant administrator role',()=>{
 const sql=read('supabase/migrations/202611210002_marketplace_operations.sql');
 assert.match(sql,/requested_role not in \('buyer','seller','both','transporter'\)/);
 assert.match(sql,/guard_profile_privileges_trigger/);
});

test('messages must pass through moderation edge function',()=>{
 const sql=read('supabase/migrations/202611210002_marketplace_operations.sql');
 const fn=read('supabase/functions/moderate-message/index.ts');
 assert.match(sql,/drop policy if exists "participants send message"/);
 assert.match(fn,/contactPatterns/);
 assert.match(fn,/message_moderation_events/);
});

test('M-Pesa callback independently verifies the STK transaction and is idempotent',()=>{
 const fn=read('supabase/functions/mpesa-callback/index.ts');
 assert.match(fn,/verifyStk\(callback.CheckoutRequestID\)/);
 assert.match(fn,/DARAJA_CALLBACK_TOKEN/);
 assert.match(fn,/\.eq\("status","pending"\)/);
});

test('seller payout requires receipt confirmation and authorized provider gate',()=>{
 const fn=read('supabase/functions/process-payout/index.ts');
 assert.match(fn,/PAYOUT_AUTHORIZED/);
 assert.match(fn,/order\?\.status!=="completed"/);
 assert.match(fn,/verified_at/);
});

test('refund reversal requires administrator approval and explicit enablement',()=>{
 const fn=read('supabase/functions/process-refund/index.ts');
 assert.match(fn,/profile\?\.role!=="admin"/);
 assert.match(fn,/REFUND_AUTHORIZED/);
 assert.match(fn,/r\.status!=="approved"/);
});

test('commission remains five percent and is calculated in the database',()=>{
 const sql=read('supabase/migrations/202611210001_initial_marketplace.sql');
 assert.match(sql,/v_fee:=round\(v_subtotal\*0\.05,2\)/);
 assert.match(sql,/commission_rate=0\.05/);
});

test('seller reputation is derived from completed-order reviews, not self-edited',()=>{
 const sql=read('supabase/migrations/202611210002_marketplace_operations.sql');
 assert.match(sql,/new\.rating is distinct from old\.rating/);
 assert.match(sql,/refresh_seller_rating_trigger/);
 assert.match(sql,/o\.seller_id=reviews\.seller_id and o\.status='completed'/);
});

test('refund and delivery requests are tied to the real order parties',()=>{
 const sql=read('supabase/migrations/202611210002_marketplace_operations.sql');
 assert.match(sql,/amount<=o\.total_amount/);
 assert.match(sql,/o\.buyer_id=deliveries\.buyer_id and o\.seller_id=deliveries\.seller_id/);
});
