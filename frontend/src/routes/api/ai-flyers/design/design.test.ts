import { beforeEach, describe, expect, it, vi } from 'vitest';
const mocks=vi.hoisted(()=>({from:vi.fn(),rpc:vi.fn(),products:[] as any[]}));
vi.mock('@supabase/supabase-js',()=>({createClient:()=>mocks}));
vi.mock('$env/dynamic/private',()=>({env:{VITE_SUPABASE_URL:'https://example.test',SUPABASE_SERVICE_ROLE_KEY:'test-only'}}));
import { POST } from './+server';
const offerId='a6eac951-857b-403d-a5ed-21c39c28de87';
const product={id:'row-1',product_barcode:'000123',product_name_ar:'منتج',product_name_en:'Original product',image_url:'https://example.test/product.png',total_sales_price:12.5,total_offer_price:0,offer_qty:2,free_qty:1,page_number:1,page_order:1};
const design={primary:'#174c2c',paper:'#fff8e8',motif:'botanical',accent:'#123456',shadowDepth:5,shadowBlur:10,shadowOpacity:.2,bevelOpacity:.3};
const call=(fetch:any,body:any={offerId,offerName:'Week 2',pageNumber:1})=>POST({request:new Request('http://localhost/api/ai-flyers/design',{method:'POST',headers:{'Content-Type':'application/json',origin:'http://localhost'},body:JSON.stringify(body)}),url:new URL('http://localhost/api/ai-flyers/design'),fetch} as any);
const ai=(output:any={...design,columns:3})=>vi.fn().mockResolvedValue(Response.json({choices:[{message:{content:JSON.stringify(output)}}]}));
beforeEach(()=>{
 mocks.products=[product];
 mocks.rpc.mockResolvedValue({data:{products:[product]}});
 mocks.from.mockImplementation((table:string)=>{
   if(table==='flyer_templates') throw new Error('Templates must never be queried');
   const data:any={flyer_offers:{id:offerId,template_name:'Offer',start_date:'2026-09-12',end_date:'2026-09-18'},system_api_keys:{api_key:'test-only'},brand_colors:[],login_layout:{topbar:{}},flyer_offer_products:mocks.products.map(p=>({id:p.id,page_number:p.page_number,page_order:p.page_order}))};
   const chain:any={then:(resolve:any)=>Promise.resolve({data:data[table],error:null}).then(resolve)};
   for(const k of ['select','eq','limit','single','maybeSingle','order'])chain[k]=()=>chain;
   return chain;
 });
});
describe('compact offer-only generation',()=>{
 it('requires an offer name, not a template',async()=>{
   const fetch=ai();expect((await call(fetch,{offerId,pageNumber:1})).status).toBe(400);expect(fetch).not.toHaveBeenCalled();
   expect((await call(fetch)).status).toBe(200);
 });
 it('sends only current-page text and never sends template data or image bytes to AI',async()=>{
   const second={...product,id:'row-2',page_number:2,product_name_en:'Second page only'};
   mocks.products=[product,second];mocks.rpc.mockResolvedValue({data:{products:mocks.products}});
   const fetch=ai(),response=await call(fetch);const result=await response.json();
   expect(response.status).toBe(200);expect(result.products).toEqual([product]);expect(result.pageCount).toBe(2);
   expect(result.offerName).toBe('Week 2');expect(result.products[0].total_offer_price).toBe(0);
   const body=fetch.mock.calls[0][1].body;
   expect(body).not.toContain('Second page only');expect(body).not.toContain('data:image');expect(body).not.toContain('inlineData');expect(body).not.toContain('product.png');
   expect(fetch.mock.calls[0][0]).toBe('https://api.openai.com/v1/chat/completions');
   expect(JSON.parse(body).model).toBe('gpt-4o-mini');
   expect(JSON.parse(body).response_format.json_schema.strict).toBe(true);
   expect(result.requestBytes).toBeLessThan(6000);
   expect(mocks.from.mock.calls.map(c=>c[0])).not.toContain('flyer_templates');
 });
 it('reuses the same style and preserves empty intermediate pages',async()=>{
   mocks.products=[product,{...product,id:'row-3',page_number:3}];mocks.rpc.mockResolvedValue({data:{products:mocks.products}});
   const first=await(await call(ai())).json();
   const fetch=ai({columns:2});
   const response=await call(fetch,{offerId,offerName:'Week 2',pageNumber:2,design:first.design,revision:first.revision});
   const second=await response.json();
   expect(response.status).toBe(200);expect(second.design).toEqual(first.design);expect(second.page.slots).toEqual([]);expect(second.page.pageNumber).toBe(2);expect(second.pageCount).toBe(3);
 });
 it('rejects changed offers between pages',async()=>{
   expect((await call(ai(),{offerId,offerName:'Week 2',pageNumber:1,revision:'outdated'})).status).toBe(409);
 });
 it('shows provider diagnostics without leaking the key',async()=>{
   const fetch=vi.fn().mockResolvedValue(Response.json({error:{message:'Invalid schema test-only'}},{status:400}));
   const response=await call(fetch),result=await response.json();
   expect(response.status).toBe(502);expect(result.error).toContain('Invalid schema');expect(result.error).not.toContain('test-only');expect(result.requestBytes).toBeGreaterThan(0);
 });
 it('rejects missing source images before AI',async()=>{
   mocks.rpc.mockResolvedValue({data:{products:[{...product,image_url:null}]}});
   const fetch=ai();expect((await call(fetch)).status).toBe(400);expect(fetch).not.toHaveBeenCalled();
 });
});
