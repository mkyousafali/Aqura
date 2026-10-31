import { describe, expect, it } from 'vitest';
import { schedulerVendorFields, loadSchedulerVendors } from './schedulerVendor';
const vendor = { branch_id: 3, erp_vendor_id: 1508, vendor_name: ' Vendor A ' };
describe('scheduler vendor recipients', () => {
 it('retains general expense compatibility', () => expect(schedulerVendorFields(null,3)).toEqual({vendor_id:null,vendor_name:null}));
 it('saves the canonical ERP identity instead of a display label', () => expect(schedulerVendorFields(vendor,'3')).toEqual({vendor_id:1508,vendor_name:'Vendor A'}));
 it.each([{...vendor,branch_id:1},{...vendor,erp_vendor_id:null},{...vendor,vendor_name:''}])('rejects invalid or stale branch selection', row => expect(()=>schedulerVendorFields(row,3)).toThrow());
 it('blocks vendor mode until a vendor is selected',()=>expect(()=>schedulerVendorFields(null,3,false)).toThrow());
 it('loads all pages scoped to the selected branch', async()=>{
  const branches: unknown[]=[];
  const client={from:()=>{const q:any={select:()=>q,eq:(_key:string,b:unknown)=>{branches.push(b);return q;},order:()=>q,range:async(start:number)=>({data:start===0?Array.from({length:1000},()=>vendor):[vendor],error:null})};return q;}};
  expect(await loadSchedulerVendors(client,3)).toHaveLength(1001);
  expect(branches).toEqual([3,3]);
 });
 it('does not treat a failed vendor query as an empty list',async()=>{
  const q:any={select:()=>q,eq:()=>q,order:()=>q,range:async()=>({data:null,error:new Error('Denied')})};
  await expect(loadSchedulerVendors({from:()=>q},3)).rejects.toThrow('Denied');
 });
});
