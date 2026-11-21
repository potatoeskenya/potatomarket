import { createClient } from '@supabase/supabase-js';
const url=import.meta.env.VITE_SUPABASE_URL as string|undefined;
const key=import.meta.env.VITE_SUPABASE_ANON_KEY as string|undefined;
export const configured=Boolean(url&&key&&!url.includes('YOUR_PROJECT'));
export const supabase=configured?createClient(url!,key!):null;
export type Product={id:string;title:string;category:string;variety:string|null;price:number;unit:string;quantity:number;county:string;description:string|null;image_url:string|null;is_certified:boolean;seller_id:string;profiles?:{full_name:string;farm_name:string|null;county:string;rating:number|null}};
export const KENYAN_COUNTIES=['Baringo','Bomet','Bungoma','Busia','Elgeyo-Marakwet','Embu','Garissa','Homa Bay','Isiolo','Kajiado','Kakamega','Kericho','Kiambu','Kilifi','Kirinyaga','Kisii','Kisumu','Kitui','Kwale','Laikipia','Lamu','Machakos','Makueni','Mandera','Marsabit','Meru','Migori','Mombasa','Murang’a','Nairobi','Nakuru','Nandi','Narok','Nyamira','Nyandarua','Nyeri','Samburu','Siaya','Taita-Taveta','Tana River','Tharaka-Nithi','Trans Nzoia','Turkana','Uasin Gishu','Vihiga','Wajir','West Pokot'];
