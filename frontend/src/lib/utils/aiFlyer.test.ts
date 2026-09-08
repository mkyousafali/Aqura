import { describe, expect, it } from 'vitest';
import { planTemplatePages, priceText, flyerDesignSchema, safeOfferBadges, flyerFieldText, offerPageCount, buildOfferPage, type FlyerProduct, type FlyerTemplate, type FlyerSnapshot } from './aiFlyer';

export const design = { primary: '#174c2c', paper: '#fff8e8', motif: 'botanical' as const, accent: '#177c32', shadowDepth: 5, shadowBlur: 12, shadowOpacity: .18, bevelOpacity: .3, offerBadges: [] };
export function template(): FlyerTemplate {
  const field = (id: string, pageNumber: number, pageOrder: number, x: number) => ({ id, pageNumber, pageOrder, x, y: 450, width: 230, height: 260, fields: [{ label: 'product_name_ar', x: 8, y: 120, width: 210, height: 30, fontSize: 18 }] });
  return { id: 'template-1', name: 'Wooden market', first_page_image_url: 'first.png', sub_page_image_urls: ['second.png', 'third.png'],
    first_page_configuration: [field('second-slot', 1, 2, 270), field('first-slot', 1, 1, 20)],
    sub_page_configurations: [[field('empty-slot', 2, 3, 20)], [field('last-slot', 3, 4, 20)]],
    metadata: { first_page_width: 794, first_page_height: 1123, sub_page_width: 900, sub_page_height: 1300 } };
}
export function product(id: string, page_number: number, page_order: number): FlyerProduct {
  return { id, page_number, page_order, product_barcode: '000' + id, product_name_en: 'Product ' + id, product_name_ar: 'منتج', unit_name: 'قطعة', image_url: 'photo.png',
    total_sales_price: 12.5, total_offer_price: 0, sales_price: 5, offer_price: 3, offer_qty: 1, free_qty: 0, limit_qty: null };
}

describe('template-based AI flyer', () => {
  it('builds pages directly from offer assignments without templates, preserving gaps and order', () => {
    const rows = [product('c',3,18),product('b',1,2),product('a',1,1)];
    expect(offerPageCount(rows)).toBe(3);
    expect(buildOfferPage(rows,1,3).slots.map(s=>s.products[0].id)).toEqual(['a','b']);
    expect(buildOfferPage(rows,2,3).slots).toEqual([]);
    expect(buildOfferPage(rows,3,3).slots[0].field.pageOrder).toBe(18);
    expect(buildOfferPage(rows,3,3).backgroundUrl).toBe('');
  });
  it('rejects conflicting assignments without packing them into new pages', () => {
    expect(()=>buildOfferPage([product('a',1,1),product('b',1,1)],1,3)).toThrow('Conflicting');
    expect(()=>offerPageCount([product('a',0,1)])).toThrow('Correct');
  });
  it('preserves source totals and zero without recalculation', () => {
    expect(priceText(0, 10)).toBe('0.00');
    expect(priceText(12.5, 5)).toBe('12.50');
    expect(priceText(null, 4.25)).toBe('4.25');
    expect(priceText(null, null)).toBe('');
  });
  it('matches exact page/order regardless of product and template array order; preserves empty pages and sizes', () => {
    const source = template();
    const before = JSON.stringify(source);
    const pages = planTemplatePages(source, [product('c', 3, 4), product('a', 1, 1), product('b', 1, 2)]);
    expect(pages.map(p => p.pageNumber)).toEqual([1, 2, 3]);
    expect(pages.map(p => p.backgroundUrl)).toEqual(['first.png', 'second.png', 'third.png']);
    expect(pages[0].slots.map(s => [s.field.x, s.products[0]?.id])).toEqual([[270, 'b'], [20, 'a']]);
    expect(pages[1].slots[0].products).toEqual([]);
    expect(pages[2].slots[0].products[0].id).toBe('c');
    expect([pages[2].width, pages[2].height]).toEqual([900, 1300]);
    expect(JSON.stringify(source)).toBe(before);
  });
  it('rejects unmatched and missing assignments instead of moving products to other slots', () => {
    expect(() => planTemplatePages(template(), [product('a', 1, 9)])).toThrow('No matching template slots');
    expect(() => planTemplatePages(template(), [product('a', null as any, null as any)])).toThrow('needs a page number');
  });
  it('does not merge unrelated products or different variation prices in one slot', () => {
    const first = { ...product('a', 1, 1), is_variation: true, parent_product_barcode: 'group' };
    const second = { ...product('b', 1, 1), is_variation: true, parent_product_barcode: 'group' };
    expect(planTemplatePages(template(), [first, second])[0].slots[1].products).toHaveLength(2);
    expect(() => planTemplatePages(template(), [first, { ...second, total_offer_price: 2 }])).toThrow('different details');
    expect(() => planTemplatePages(template(), [product('a', 1, 1), product('b', 1, 1)])).toThrow('different details');
  });
  it('rejects duplicate template assignments', () => {
    const source = template(); source.first_page_configuration[0].pageOrder = 1;
    expect(() => planTemplatePages(source, [product('a', 1, 1)])).toThrow('repeated');
  });
  it('uses original group names, exact barcodes and actual template page numbering', () => {
    const source = template();
    const p = { ...product('a', 3, 4), variation_group_name_ar: 'مجموعة' };
    const pages = planTemplatePages(source, [p]);
    const snapshot = { offer: { start_date: '2026-09-12', end_date: '2026-09-18', offer_names: { name_ar: 'الأسبوع 2', name_en: 'Week 2' } }, template: source, pages, products: [p], design, model: 'test' } as FlyerSnapshot;
    const slot = pages[2].slots[0];
    expect(flyerFieldText('barcode', slot, snapshot, pages[2])).toBe('000a');
    expect(flyerFieldText('offer_price', slot, snapshot, pages[2])).toBe('0.00');
    expect(flyerFieldText('page_number', slot, snapshot, pages[2])).toBe('03');
    expect(flyerFieldText('offer_name_ar', slot, snapshot, pages[2])).toBe('الأسبوع 2');
    expect(flyerFieldText('expiry_date_label', slot, snapshot, pages[2])).toContain('12-09-2026');
  });
  it('does not allow AI to create a new grid, replace the background or overwrite offer data', () => {
    expect(flyerDesignSchema.safeParse(design).success).toBe(true);
    for (const override of [{ rows: 3 }, { columns: 2 }, { background: '#ffffff' }, { products: [] }]) {
      expect(flyerDesignSchema.safeParse({ ...design, ...override }).success).toBe(false);
    }
  });
  it('rejects offer-name decorations overlapping a slot, outside a page, or duplicated', () => {
    const pages = planTemplatePages(template(), [product('a', 1, 1)]);
    const badge = { pageNumber: 1, x: 20, y: 20, width: 200, height: 60, fontSize: 24, color: '#ffffff' };
    const result = safeOfferBadges({ ...design, offerBadges: [{ ...badge, y: 460 }, { ...badge, x: 790 }, badge, badge] }, pages);
    expect(result.offerBadges).toEqual([badge]);
  });
});
