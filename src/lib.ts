import { createClient } from '@supabase/supabase-js';

// Public browser configuration for the Kenya Potato Farmers Marketplace.
// Supabase publishable keys are designed for use in browser applications.
// Database access must still be protected by Row Level Security (RLS).
const DEFAULT_SUPABASE_URL = 'https://yeublkfrssgvidsaiobo.supabase.co';
const DEFAULT_SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_opmiRBjQWb8cF9_VFZ3Olw_k8i7kO3U';

const url = (import.meta.env.VITE_SUPABASE_URL as string | undefined) || DEFAULT_SUPABASE_URL;
const key = (import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined) || DEFAULT_SUPABASE_PUBLISHABLE_KEY;

export const configured = Boolean(url && key && url.startsWith('https://'));
export const supabase = configured
  ? createClient(url, key, {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: true,
      },
      realtime: {
        params: { eventsPerSecond: 10 },
      },
    })
  : null;
export type Product={id:string;title:string;category:string;variety:string|null;price:number;unit:string;quantity:number;county:string;description:string|null;image_url:string|null;is_certified:boolean;seller_id:string;profiles?:{full_name:string;farm_name:string|null;county:string;rating:number|null}};
export const KENYAN_COUNTIES=['Baringo','Bomet','Bungoma','Busia','Elgeyo-Marakwet','Embu','Garissa','Homa Bay','Isiolo','Kajiado','Kakamega','Kericho','Kiambu','Kilifi','Kirinyaga','Kisii','Kisumu','Kitui','Kwale','Laikipia','Lamu','Machakos','Makueni','Mandera','Marsabit','Meru','Migori','Mombasa','Murang’a','Nairobi','Nakuru','Nandi','Narok','Nyamira','Nyandarua','Nyeri','Samburu','Siaya','Taita-Taveta','Tana River','Tharaka-Nithi','Trans Nzoia','Turkana','Uasin Gishu','Vihiga','Wajir','West Pokot'];
