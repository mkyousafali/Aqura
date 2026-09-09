import { z } from 'zod';

export const flyerDesignSchema = z.object({
  primary: z.string().regex(/^#[0-9a-fA-F]{6}$/).default('#174c2c'),
  paper: z.string().regex(/^#[0-9a-fA-F]{6}$/).default('#fff8e8'),
  motif: z.enum(['botanical', 'geometric', 'festive']).default('botanical'),
  accent: z.string().regex(/^#[0-9a-fA-F]{6}$/),
  shadowDepth: z.number().min(2).max(10),
  shadowBlur: z.number().min(4).max(20),
  shadowOpacity: z.number().min(0.08).max(0.3),
  bevelOpacity: z.number().min(0.15).max(0.6),
  // AI may place the exact offer name only in unused header space. Never receives layout authority.
  offerBadges: z.array(z.object({
    pageNumber: z.number().int().positive(), x: z.number().nonnegative(), y: z.number().nonnegative(),
    width: z.number().positive(), height: z.number().positive(), fontSize: z.number().min(12).max(48),
    color: z.string().regex(/^#[0-9a-fA-F]{6}$/)
  }).strict())
}).strict();
export type FlyerDesign = z.infer<typeof flyerDesignSchema>;
export interface FlyerProduct {
  id: string;
  product_barcode: string;
  product_name_en: string;
  product_name_ar: string;
  image_url: string | null;
  unit_name: string;
  sales_price: number | null;
  total_sales_price: number | null;
  offer_price: number | null;
  total_offer_price: number | null;
  offer_qty: number;
  limit_qty: number | null;
  free_qty: number;
  page_number?: number;
  page_order?: number;
  variation_group_name_en?: string;
  variation_group_name_ar?: string;
  [key: string]: unknown;
}
export interface FlyerSnapshot {
  offer: { id: string; start_date: string; end_date: string; template_name: string;
    offer_names: { name_en: string; name_ar: string } | null };
  products: FlyerProduct[];
  design: FlyerDesign;
  template?: FlyerTemplate;
  offerName?: string;
  // Internal AI visual-direction guidance ("General Supermarket Offer", "Fruit & Vegetable
  // Offer", ...) selected in the Generate Flyer window — never printed on the flyer itself.
  // Carried in the snapshot so it survives into Save and is available again from the library
  // (openPreview/improveFlyer) without a second lookup, per offer_context_ai_flyer_spec.md.
  context?: { id: string; name: string; description: string } | null;
  logoUrl?: string;
  pageCount?: number;
  revision?: string;
  pages: FlyerPage[];
  model: string;
}

export interface TemplateField {
  id: string; x: number; y: number; width: number; height: number;
  pageNumber?: number; pageOrder?: number; number?: number; rotation?: number;
  fields: any[];
}
export interface FlyerTemplate {
  id: string; name: string; description?: string;
  first_page_image_url: string; sub_page_image_urls: string[];
  first_page_configuration: TemplateField[]; sub_page_configurations: TemplateField[][];
  metadata?: { first_page_width?: number; first_page_height?: number; sub_page_width?: number; sub_page_height?: number };
}
export interface FlyerSlot { field: TemplateField; products: FlyerProduct[] }
export interface FlyerPage { pageNumber: number; width: number; height: number; backgroundUrl: string; slots: FlyerSlot[] }

/** Offer page/order is authoritative. Gaps in page numbers remain actual blank pages. */
export function offerPageCount(products: FlyerProduct[]): number {
  if (!products.length) throw new Error('This offer has no products.');
  for (const p of products) {
    if (!Number.isInteger(p.page_number) || p.page_number! < 1 || p.page_number! > 100 || !Number.isInteger(p.page_order) || p.page_order! < 1)
      throw new Error(`Correct the page number and page order for ${p.product_barcode}.`);
  }
  return Math.max(...products.map(p => p.page_number!));
}

export function buildOfferPage(products: FlyerProduct[], pageNumber: number, columns: number): FlyerPage {
  const count = offerPageCount(products);
  if (pageNumber < 1 || pageNumber > count) throw new Error('Invalid offer page.');
  const ordered = products.filter(p => p.page_number === pageNumber).sort((a,b) => a.page_order! - b.page_order! || Number(a.variation_order || 0) - Number(b.variation_order || 0) || a.id.localeCompare(b.id));
  const groups: FlyerProduct[][] = [];
  for (const p of ordered) {
    const previous = groups.at(-1);
    if (previous?.[0].page_order === p.page_order) {
      const terms = (p: FlyerProduct) => JSON.stringify([priceText(p.total_sales_price,p.sales_price),priceText(p.total_offer_price,p.offer_price),p.offer_qty,p.limit_qty,p.free_qty,p.unit_name]);
      if (!p.is_variation || !p.parent_product_barcode || previous[0].parent_product_barcode !== p.parent_product_barcode || terms(previous[0]) !== terms(p))
        throw new Error(`Conflicting products at page ${pageNumber}, order ${p.page_order}. Correct the offer assignment.`);
      previous.push(p);
    } else groups.push([p]);
  }
  const cols = Math.min(Math.max(1, Math.round(columns)), 4, Math.max(1,groups.length));
  const rows = Math.max(1, Math.ceil(groups.length / cols));
  const width = (984 - (cols-1)*12)/cols, height = (790 - (rows-1)*12)/rows;
  if (height < 185) throw new Error(`Page ${pageNumber} has too many products for a readable flyer. Adjust its assignments; products will not be moved automatically.`);
  return { pageNumber, width:1024, height:1536, backgroundUrl:'', slots:groups.map((group,i)=>({products:group,field:{id:group[0].id,pageNumber,pageOrder:group[0].page_order,x:20+(i%cols)*(width+12),y:550+Math.floor(i/cols)*(height+12),width,height,fields:[]}})) };
}
const decorationTypes = new Set(['special_symbol', 'expiry_date_label', 'page_number', 'offer_name', 'offer_name_ar', 'offer_name_en']);
export function isProductField(field: TemplateField) {
  return !field.fields?.length || field.fields.some(f => !decorationTypes.has(f.label || f.type));
}

// Keep zero prices, individual variants, and every offer row. AI never supplies these values.
export function priceText(total: unknown, single: unknown): string {
  const value = total ?? single;
  if (value === null || value === undefined || value === '') return '';
  const number = Number(value);
  return Number.isFinite(number) && number >= 0 ? number.toFixed(2) : '';
}

export function planTemplatePages(template: FlyerTemplate, products: FlyerProduct[]): FlyerPage[] {
  const backgrounds = [template.first_page_image_url, ...(template.sub_page_image_urls || [])];
  const configs = [template.first_page_configuration || [], ...(template.sub_page_configurations || [])];
  if (configs.length > backgrounds.length) throw new Error('The template has a page configuration without a background. Fix it in Flyer Template.');
  const assignments = new Map<string, FlyerProduct[]>();
  for (const p of products) {
    if (!Number.isInteger(p.page_number) || p.page_number! < 1 || !Number.isInteger(p.page_order) || p.page_order! < 1)
      throw new Error(`Product ${p.product_barcode} needs a page number and page order in the offer. No products have been moved.`);
    const key = `${p.page_number}:${p.page_order}`;
    assignments.set(key, [...(assignments.get(key) || []), p]);
  }
  const used = new Set<string>();
  let fallbackOrder = 0;
  const pages = backgrounds.map((backgroundUrl, index): FlyerPage => {
    if (!backgroundUrl) throw new Error(`Template page ${index + 1} has no background.`);
    const width = (index ? template.metadata?.sub_page_width : template.metadata?.first_page_width) ?? 794;
    const height = (index ? template.metadata?.sub_page_height : template.metadata?.first_page_height) ?? 1123;
    if (![width, height].every(n => Number.isFinite(n) && n > 0 && n <= 10000)) throw new Error('Invalid template page dimensions.');
    const slots = (configs[index] || []).map(field => {
      if (![field.x, field.y, field.width, field.height].every(Number.isFinite) || field.width <= 0 || field.height <= 0)
        throw new Error(`Invalid field dimensions on template page ${index + 1}.`);
      if (!isProductField(field)) return { field, products: [] };
      const key = `${field.pageNumber ?? index + 1}:${field.pageOrder ?? fallbackOrder + 1}`;
      const matches = assignments.get(key) || [];
      if (matches.length) {
        if (used.has(key)) throw new Error(`Template slot ${key} is repeated. Fix its page/order before generating.`);
        if (matches.length > 1) {
          const parent = matches[0].parent_product_barcode;
          const terms = (p: FlyerProduct) => JSON.stringify([priceText(p.total_sales_price, p.sales_price), priceText(p.total_offer_price, p.offer_price), p.offer_qty, p.limit_qty, p.free_qty, p.unit_name]);
          if (!parent || !matches.every(p => p.is_variation && p.parent_product_barcode === parent && terms(p) === terms(matches[0])))
            throw new Error(`Multiple products with different details occupy ${key}: ${matches.map(p => p.product_barcode).join(', ')}. Correct the offer page/order.`);
        }
        used.add(key);
        fallbackOrder++;
      }
      return { field, products: [...matches].sort((a, b) => Number(a.variation_order || 0) - Number(b.variation_order || 0)) };
    });
    return { pageNumber: index + 1, width, height, backgroundUrl, slots };
  });
  const unmatched = [...assignments].filter(([key]) => !used.has(key));
  if (unmatched.length) throw new Error(`No matching template slots for ${unmatched.map(([key, rows]) => `${key} (${rows.map(p => p.product_barcode).join(', ')})`).join('; ')}. Correct the template or offer page/order. No pages have been rearranged.`);
  return pages;
}

export function safeOfferBadges(design: FlyerDesign, pages: FlyerPage[]): FlyerDesign {
  const seen = new Set<number>();
  return { ...design, offerBadges: design.offerBadges.filter(badge => {
    const page = pages.find(p => p.pageNumber === badge.pageNumber);
    if (!page || seen.has(badge.pageNumber) || badge.x + badge.width > page.width || badge.y + badge.height > page.height * 0.48) return false;
    if (page.slots.some(s => s.field.fields?.some(f => (f.label || f.type || '').startsWith('offer_name')))) return false;
    if (page.slots.some(({ field: f }) => badge.x < f.x + f.width + 6 && badge.x + badge.width > f.x - 6 && badge.y < f.y + f.height + 6 && badge.y + badge.height > f.y - 6)) return false;
    seen.add(badge.pageNumber); return true;
  }) };
}

export function flyerFieldText(type: string, slot: FlyerSlot, snapshot: FlyerSnapshot, page: FlyerPage): string {
  const p = slot.products[0];
  const arabic = (v: unknown) => String(v).replace(/\d/g, d => '٠١٢٣٤٥٦٧٨٩'[Number(d)]);
  const date = (v: string) => v.slice(0, 10).split('-').reverse().join('-');
  if (type === 'page_number') return String(page.pageNumber).padStart(2, '0');
  if (type === 'expiry_date_label') return `من ${date(snapshot.offer.start_date)} إلى ${date(snapshot.offer.end_date)} أو حتى نفاد الكمية`;
  if (type === 'offer_name_ar') return snapshot.offer.offer_names?.name_ar || '';
  if (type === 'offer_name_en') return snapshot.offer.offer_names?.name_en || '';
  if (type === 'offer_name') return snapshot.offer.offer_names?.name_ar || snapshot.offer.offer_names?.name_en || snapshot.offer.template_name;
  if (!p) return '';
  const group = slot.products.length > 1;
  switch (type) {
    case 'product_name_en': return (group ? p.variation_group_name_en : '') || p.product_name_en || '';
    case 'product_name_ar': return (group ? p.variation_group_name_ar : '') || p.product_name_ar || '';
    case 'barcode': return slot.products.map(p => p.product_barcode).join('\n');
    case 'price': return priceText(p.total_sales_price, p.sales_price);
    case 'offer_price': return priceText(p.total_offer_price, p.offer_price);
    case 'unit_name': return p.unit_name || '';
    case 'offer_qty': return p.offer_qty > 1 ? `${arabic(p.offer_qty)}\n${p.unit_name || 'قطعة'}` : '';
    case 'limit_qty': return Number(p.limit_qty) > 0 ? `${arabic(p.limit_qty)} ${p.unit_name || 'قطعة'}` : '';
    case 'free_qty': return p.free_qty > 0 ? `اشتري ${arabic(p.offer_qty || 1)} ${p.unit_name || 'قطعة'}\nواحصل على ${arabic(p.free_qty)} ${p.unit_name || 'قطعة'} مجاناً` : '';
    case 'variation_text_en': return group ? 'Multiple varieties available' : '';
    case 'variation_text_ar': return group ? 'أصناف متعددة متوفرة' : '';
    case 'expire_date': case 'serial_number': return String(p[type] || '');
    default: return '';
  }
}

export function contrastInk(hex: string): string {
  const c = [1, 3, 5].map(i => parseInt(hex.slice(i, i + 2), 16) / 255)
    .map(v => v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4);
  return c[0] * 0.2126 + c[1] * 0.7152 + c[2] * 0.0722 > 0.179 ? '#000000' : '#ffffff';
}
