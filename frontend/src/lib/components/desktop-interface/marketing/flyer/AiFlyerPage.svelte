<script lang="ts">
  import { flyerFieldText, type FlyerSnapshot, type FlyerPage, type FlyerSlot } from '$lib/utils/aiFlyer';
  import { iconUrlMap } from '$lib/stores/iconStore';
  export let snapshot: FlyerSnapshot;
  export let page: FlyerPage;
  export let artworkUrl = '';
  $: design = snapshot.design;
  const typeOf = (field: any) => field.label || field.type || '';
  function fieldsFor(slot: FlyerSlot) {
    // Configured fields retain their exact geometry; only unconfigured cards get an internal layout.
    if (slot.field.fields?.length) return slot.field.fields.filter(f => typeOf(f) !== 'barcode');
    const w = slot.field.width, h = slot.field.height;
    const p = slot.products[0];
    // Only lay out the meta chips this product actually has data for, evenly centered.
    // The unit name is never its own chip: it only shows up folded into offer_qty's own
    // circular badge below ("٣ حبه") when there's a multi-buy quantity; otherwise hidden.
    const metaLabels = [
      { label: 'limit_qty', show: Number(p?.limit_qty) > 0 },
      { label: 'free_qty', show: Number(p?.free_qty) > 0 }
    ].filter(f => f.show);
    const metaGap = w * .02;
    const metaWidth = (w * .94 - metaGap * Math.max(metaLabels.length - 1, 0)) / Math.max(metaLabels.length, 1);
    const meta = metaLabels.map((f, i) => ({
      label: f.label, x: w * .03 + i * (metaWidth + metaGap), y: h * .905, width: metaWidth, height: h * .065,
      fontSize: f.label === 'free_qty' ? 11 : 13, bold: true, color: '#6b4a1e', alignment: 'center'
    }));
    // A multi-buy quantity gets its own small seal-style badge (ring + "N unit") pinned to the
    // card's top-right corner, instead of a flat pill buried in the meta row.
    const badgeSize = Math.min(w, h) * .22;
    const qtyBadge = Number(p?.offer_qty) > 1
      ? [{ label: 'offer_qty_badge', x: w * .97 - badgeSize, y: h * .02, width: badgeSize, height: badgeSize }]
      : [];
    return [
      // Height (not width) is what usually caps how big a tall, narrow product photo (a
      // bottle, a box) can render under object-fit:contain — so the image gets most of the
      // card's height, with the text zone below compressed to make room for it.
      { label: 'image', x: w * .02, y: h * .02, width: w * .96, height: h * .7 },
      { label: 'product_name_ar', x: w * .045, y: h * .735, width: w * .91, height: h * .09, fontSize: 19, color: '#e60024', bold: true, alignment: 'center' },
      { label: 'product_name_en', x: w * .045, y: h * .825, width: w * .91, height: h * .075, fontSize: 13, alignment: 'center' },
      ...qtyBadge,
      { label: 'price', x: w * .64, y: h * .48, width: w * .31, height: h * .075, fontSize: 20, bold: true, alignment: 'center' },
      { label: 'offer_price', x: w * .59, y: h * .55, width: w * .38, height: h * .14, fontSize: 40, color: '#ffffff', bold: true, alignment: 'center' },
      ...meta
    ];
  }
  function imagesFor(slot: FlyerSlot, config: any) {
    const variant = slot.products.length > 1;
    const images = variant ? slot.products.map(p => p.image_url).filter(Boolean) : Array(Math.min(Number(slot.products[0]?.offer_qty) || 1, 5)).fill(slot.products[0]?.image_url);
    const positions = variant ? config.variantImagePositions : config.offerQtyImagePositions;
    const sizes = variant ? config.variantImageSizes : config.offerQtyImageSizes;
    if (variant && images.length > 1) {
      // One hero product stays large and fully in front; the rest are smaller and tucked
      // behind it along the top edge, peeking out — like a real product-family photo, rather
      // than an equal-size grid (too rigid) or an even cascade (crops earlier images to slivers).
      const restCount = images.length - 1;
      const restSize = restCount === 1 ? 46 : restCount === 2 ? 40 : 34;
      const restStep = restCount > 1 ? (100 - restSize) / (restCount - 1) : 0;
      const heroSize = 62;
      return images.map((url, index) => {
        if (index === 0) return {
          url, x: positions?.[0]?.x ?? 3 * config.width / 100, y: positions?.[0]?.y ?? 34 * config.height / 100,
          width: sizes?.[0]?.width ?? heroSize, height: sizes?.[0]?.height ?? heroSize, z: 50
        };
        const restIndex = index - 1;
        return {
          url, x: positions?.[index]?.x ?? (restIndex * restStep) * config.width / 100, y: positions?.[index]?.y ?? 0,
          width: sizes?.[index]?.width ?? restSize, height: sizes?.[index]?.height ?? restSize, z: restIndex + 1
        };
      });
    }
    // The same product repeated for a multi-buy quantity reads fine as a diagonal cascade —
    // it's one item shown as a stack, not several distinct items competing to stay visible.
    const overlap = .4;
    const scale = images.length === 1 ? 100 : 100 / (1 + (images.length - 1) * (1 - overlap));
    const step = scale * (1 - overlap);
    return images.map((url, index) => ({ url, x: positions?.[index]?.x ?? (images.length === 1 ? 0 : index * step * config.width / 100), y: positions?.[index]?.y ?? (images.length === 1 ? 0 : index * 5),
      width: sizes?.[index]?.width ?? scale,
      height: sizes?.[index]?.height ?? (images.length === 1 ? 100 : 88) }));
  }
  function box(field: any) {
    return `left:${field.x ?? 0}px;top:${field.y ?? 0}px;width:${field.width ?? 100}px;height:${field.height ?? 20}px;transform:rotate(${field.rotation || 0}deg);`;
  }
  function textStyle(field: any) {
    return `font-size:${field.fontSize ?? 14}px;font-family:${JSON.stringify(field.fontFamily || 'Arial')},Tahoma,sans-serif;color:${field.color || '#000000'};font-weight:${field.bold ? 700 : 400};font-style:${field.italic ? 'italic' : 'normal'};text-align:${field.alignment || 'left'};justify-content:${field.alignment === 'right' ? 'flex-end' : field.alignment === 'center' ? 'center' : 'flex-start'};text-decoration:${typeOf(field) === 'price' || field.strikethrough ? 'line-through' : 'none'};`;
  }
</script>

<article class="ai-flyer-page" data-page-number={page.pageNumber} style="width:{page.width}px;height:{page.height}px;--depth:{design.shadowDepth}px;--blur:{design.shadowBlur}px;--shadow:rgba(0,0,0,{design.shadowOpacity});--bevel:rgba(255,255,255,{design.bevelOpacity});--accent:{design.accent};">
  {#if artworkUrl}
    <img class="template-background" src={artworkUrl} alt="AI-generated market artwork" />
    {#if snapshot.logoUrl}<img class="brand-logo" src={snapshot.logoUrl} crossorigin="anonymous" alt="Brand logo" />{/if}
    <!-- The offer name is baked into the artwork itself as 3D typography (see /api/ai-flyers/artwork) — no HTML headline overlay here. -->
    <div class="artwork-footer">
      <div class="date-plaque"><span dir="rtl">من {snapshot.offer.start_date}</span><span dir="rtl">إلى {snapshot.offer.end_date}</span><small dir="rtl">أو حتى نفاد الكمية</small></div>
      <span class="page-counter">{String(page.pageNumber).padStart(2, '0')} / {snapshot.pageCount}</span>
    </div>
  {:else if page.backgroundUrl}
    <img class="template-background" src={page.backgroundUrl} crossorigin="anonymous" alt={`Background, page ${page.pageNumber}`} />
  {:else}
    <div class="offer-art {design.motif}" style="--primary:{design.primary};--paper:{design.paper};--accent:{design.accent};">
      <div class="art-light"></div><div class="ornament one"></div><div class="ornament two"></div><div class="ornament three"></div>
      {#if snapshot.logoUrl}<img class="brand-logo" src={snapshot.logoUrl} crossorigin="anonymous" alt="Brand logo" />{/if}
      <div class="headline-board"><div class="headline" data-fit-text data-field-label="offer_name"><span dir="auto">{snapshot.offerName}</span></div><div class="offer-period">{snapshot.offer.start_date} — {snapshot.offer.end_date}</div></div>
      <div class="footer-band"><span dir="rtl">من {snapshot.offer.start_date} إلى {snapshot.offer.end_date} أو حتى نفاد الكمية</span><span>{String(page.pageNumber).padStart(2,'0')} / {snapshot.pageCount}</span></div>
    </div>
  {/if}
  {#each page.slots as slot (slot.field.id)}
    <section class="template-slot" class:product-panel={slot.products.length > 0} class:standalone-card={!page.backgroundUrl} style={box(slot.field)} data-slot={`${slot.field.pageNumber ?? page.pageNumber}:${slot.field.pageOrder ?? ''}`}>
      {#each fieldsFor(slot) as field}
        {@const type = typeOf(field)}
        {@const text = flyerFieldText(type, slot, snapshot, page)}
        {#if type === 'image' && slot.products.length}
          <div class="configured-field image-field" style={box(field)}>
            <div class="image-ground" aria-hidden="true"></div>
            {#each imagesFor(slot, field) as image, i}
              <img class="product-image" class:variant-image={slot.products.length > 1} src={image.url} crossorigin="anonymous" alt={slot.products[i]?.product_name_en || slot.products[0].product_name_ar} style="left:{image.x}px;top:{image.y}px;width:{image.width}%;height:{image.height}%;z-index:{image.z ?? i + 1};" />
            {/each}
            {#if field.variantIconUrl && slot.products.length > 1}
              <img class="asset" src={field.variantIconUrl} crossorigin="anonymous" alt="Varieties" style="left:{field.variantIconX || 0}px;top:{field.variantIconY || 0}px;width:{field.variantIconWidth || 50}px;height:{field.variantIconHeight || 50}px;z-index:20;" />
            {:else if slot.products.length > 1}
              <span class="assorted-badge" aria-hidden="true">متنوع</span>
            {/if}
          </div>
        {:else if type === 'special_symbol' && field.symbolUrl}
          <div class="configured-field" style={box(field)}><img class="asset" src={field.symbolUrl} crossorigin="anonymous" alt="Template decoration" style="left:{field.symbolX || 0}px;top:{field.symbolY || 0}px;width:{field.symbolWidth || 30}px;height:{field.symbolHeight || 30}px;" /></div>
        {:else if type === 'variant_icon' && field.variantIconUrl && slot.products.length > 1}
          <div class="configured-field" style={box(field)}><img class="asset" src={field.variantIconUrl} crossorigin="anonymous" alt="Varieties" style="width:100%;height:100%;" /></div>
        {:else if type === 'offer_qty_badge'}
          {@const qtyText = flyerFieldText('offer_qty', slot, snapshot, page)}
          {#if qtyText}
            <div class="qty-badge" data-fit-text data-field-label="offer_qty" style="{box(field)}font-size:{field.width * .3}px;"><span dir="rtl">{qtyText}</span></div>
          {/if}
        {:else if text}
          <div class="configured-field" class:price-panel={type === 'offer_price'} class:old-price-panel={type === 'price'} class:offer-title={type.startsWith('offer_name')} style={box(field)}>
            {#if field.iconUrl}<img class="asset" src={field.iconUrl} crossorigin="anonymous" alt="Template label background" style="left:{field.iconX || 0}px;top:{field.iconY || 0}px;width:{field.iconWidth || 20}px;height:{field.iconHeight || 20}px;" />{/if}
            <div class="template-text" data-fit-text data-field-label={type} style={textStyle(field)} dir={['product_name_ar', 'offer_name_ar', 'expiry_date_label', 'offer_qty', 'unit_name', 'limit_qty', 'free_qty', 'variation_text_ar'].includes(type) ? 'rtl' : 'ltr'}>
              <span>
                {#if type === 'offer_price'}
                  {@const parts = text.split('.')}
                  <img class="currency" src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} crossorigin="anonymous" alt="SAR" />{parts[0]}<small>.{parts[1]}</small>
                {:else}{text}{/if}
              </span>
            </div>
          </div>
        {/if}
      {/each}
    </section>
  {/each}
  {#each design.offerBadges.filter(b => b.pageNumber === page.pageNumber) as badge}
    <div class="offer-badge offer-title" style="left:{badge.x}px;top:{badge.y}px;width:{badge.width}px;height:{badge.height}px;color:{badge.color};font-size:{badge.fontSize}px;" data-fit-text data-field-label="offer_name">
      <span>{#if snapshot.offer.offer_names?.name_ar}<strong dir="rtl">{snapshot.offer.offer_names.name_ar}</strong>{/if}{#if snapshot.offer.offer_names?.name_en}<strong>{snapshot.offer.offer_names.name_en}</strong>{/if}{#if !snapshot.offer.offer_names?.name_ar && !snapshot.offer.offer_names?.name_en}<strong>{snapshot.offer.template_name}</strong>{/if}</span>
    </div>
  {/each}
</article>

<style>
  .artwork-footer{position:absolute;left:35px;right:30px;top:1380px;height:135px;display:flex;align-items:center;justify-content:space-between;gap:28px;color:white;font-family:Tahoma,Arial,sans-serif;}
  .date-plaque{display:flex;flex-direction:column;gap:5px;padding:12px 24px;border:3px solid #ad763d;border-radius:13px;background:linear-gradient(125deg,#fff6da,#efd09b);color:#211508;font-weight:700;font-size:22px;box-shadow:0 5px 10px #0005;}.date-plaque small{font-size:16px;}.page-counter{align-self:flex-end;font-size:16px;padding-bottom:9px;}
  .old-price-panel{z-index:9;background:#ffe000;border-radius:7px 7px 0 0;}
  .offer-art{position:absolute;inset:0;z-index:-1;background:linear-gradient(140deg,var(--paper),#fff 60%,var(--paper));overflow:hidden;}
  .art-light{position:absolute;inset:0 0 auto;height:435px;background:radial-gradient(ellipse at 65% 20%,#ffffff50,transparent 50%),linear-gradient(120deg,var(--primary),#172015);border-bottom:12px solid var(--accent);box-shadow:0 12px 25px #0003;}
  .brand-logo{position:absolute;top:22px;left:24px;width:135px;height:105px;object-fit:contain;padding:10px;background:white;border-radius:0 0 20px 20px;box-shadow:0 10px 16px #0004;}
  .headline-board{position:absolute;top:115px;left:180px;right:65px;height:265px;border-radius:22px;background:linear-gradient(160deg,#925d32,#4a2818);border:4px solid #c08b4f;box-shadow:0 16px 0 #321a12,0 28px 30px #0006,inset 0 3px 0 #ffdf9480;transform:rotate(-2deg);}
  .headline{position:absolute;inset:22px 24px 66px;display:flex;align-items:center;justify-content:center;font:bold 68px/1.2 Tahoma,Arial,sans-serif;text-align:center;color:#ffe074;text-shadow:0 2px #fff1b0,0 4px #bd7a1f,0 6px #915519,0 9px #613414,0 14px 12px #0008;}.headline span{max-width:100%;}
  .offer-period{position:absolute;bottom:15px;left:0;right:0;text-align:center;font:bold 21px Arial;color:white;}
  .ornament{position:absolute;width:180px;height:80px;border-radius:100% 0 100% 0;background:linear-gradient(25deg,#123e16,#67a736);box-shadow:inset 0 3px 0 #ffffff40,0 8px 10px #0003;transform:rotate(-25deg);}.one{top:285px;left:-40px;}.two{top:28px;right:-20px;transform:rotate(130deg);}.three{bottom:40px;right:-55px;transform:rotate(-45deg);}.geometric .ornament{border-radius:14px;background:var(--accent);}.festive .ornament{border-radius:50%;background:linear-gradient(35deg,var(--accent),#ffe692);}
  .footer-band{position:absolute;left:0;right:0;bottom:0;min-height:90px;background:var(--primary);color:white;border-top:8px solid var(--accent);display:flex;align-items:center;justify-content:space-between;gap:20px;padding:20px 35px;font:18px Tahoma,Arial,sans-serif;}
  .standalone-card{border-radius:17px;background:linear-gradient(150deg,#fff 55%,#fff8e9);border:2px solid #fff;box-shadow:0 4px 8px #65411e20,inset 0 2px 1px #fff;}
  .ai-flyer-page{position:relative;overflow:hidden;background:white;flex-shrink:0;box-sizing:border-box;isolation:isolate;}
  .template-background{position:absolute;inset:0;width:100%;height:100%;z-index:-1;}
  .template-slot{position:absolute;transform-origin:center;box-sizing:border-box;}
  .product-panel::before{content:'';position:absolute;inset:0;pointer-events:none;border-radius:8px;box-shadow:0 var(--depth) var(--blur) var(--shadow),inset 0 2px 2px var(--bevel),inset 0 -2px 3px rgba(0,0,0,.08);background:linear-gradient(145deg,rgba(255,255,255,.035),transparent 40%);}
  .configured-field{position:absolute;transform-origin:center;box-sizing:border-box;}
  .template-text{position:absolute;inset:0;display:flex;align-items:center;line-height:1;white-space:pre-line;overflow-wrap:anywhere;}
  .template-text>span{position:relative;max-width:100%;}.template-text small{font-size:.55em;}
  /* Names sit in generously tall boxes so long text can still wrap; hug the shared boundary
     between them instead of centering independently, so a short name doesn't leave a gap. */
  /* field.color/bold are always set inline by textStyle(), so only non-color layout tweaks
     belong in these attribute-selector rules — an inline style always wins over a CSS rule. */
  .template-text[data-field-label="product_name_ar"]{align-items:flex-end;padding-bottom:1px;}
  .template-text[data-field-label="product_name_en"]{align-items:flex-start;padding-top:3px;margin-top:1px;border-top:1px solid #f0d9a8;letter-spacing:.2px;}
  /* Meta chips (unit / limit / bonus) render as small pills so a lone chip reads as a
     deliberate label instead of stray text floating in its quadrant. */
  .template-text[data-field-label="unit_name"],
  .template-text[data-field-label="offer_qty"],
  .template-text[data-field-label="limit_qty"],
  .template-text[data-field-label="free_qty"]{background:linear-gradient(180deg,#fef6e4,#f7e8c4);border:1px solid #e3c98a;border-radius:6px;box-shadow:inset 0 1px 0 #fffdf5;}
  .price-panel{z-index:10;border-radius:7px;background:linear-gradient(135deg,#fa092c,#e40022);box-shadow:0 3px 5px rgba(120,0,0,.2),inset 0 1px 1px #ffffff40;}
  .asset{position:absolute;object-fit:contain;}.product-image{position:absolute;object-fit:contain;object-position:center bottom;width:auto;height:auto;filter:drop-shadow(2px 4px 3px rgba(0,0,0,.2));}
  /* A fanned variant photo already sits in a short, roughly-centered band (see imagesFor) —
     bottom-anchoring it there (right for a single tall bottle filling its full-height box)
     just re-creates a gap at the other end, so let it center in its own box instead. */
  .product-image.variant-image{object-position:center;}
  .image-ground{position:absolute;left:18%;right:18%;bottom:4%;height:9%;border-radius:50%;background:radial-gradient(ellipse,rgba(0,0,0,.16),transparent 70%);}
  /* Default "Assorted" flag for a variant group with no template-supplied variant icon. */
  .assorted-badge{position:absolute;left:4%;bottom:5%;z-index:21;background:linear-gradient(160deg,#ff8a2b,#e2530a);color:#fff;font:700 13px Tahoma,Arial,sans-serif;padding:.4em 1em;border-radius:999px;box-shadow:0 3px 6px rgba(0,0,0,.3),inset 0 1px 0 rgba(255,255,255,.35);}
  /* Multi-buy quantity seal: one ringed circular badge holding all three lines ("on offer" /
     quantity / unit) — font-size is set inline (proportional to badge size) so every
     measurement below can just use em and scale with it. */
  .qty-badge{position:absolute;box-sizing:border-box;border-radius:50%;background:radial-gradient(circle at 35% 30%,#ff8a4a,#e2530a 65%,#c23f05);border:.14em solid #fff;box-shadow:0 0 0 .08em #e2530a,0 .3em .5em rgba(0,0,0,.35);display:flex;align-items:center;justify-content:center;z-index:12;}
  .qty-badge span{color:#fff;font:700 1em/1.15 Tahoma,Arial,sans-serif;text-align:center;white-space:pre-line;text-shadow:0 1px 1px rgba(0,0,0,.35);}
  .currency{height:.6em;max-width:1em;display:inline-block;vertical-align:baseline;margin-right:.12em;filter:brightness(0) invert(1);}
  .offer-title{text-shadow:0 1px 0 rgba(255,255,255,.4),0 2px 0 rgba(0,0,0,.15),0 3px 0 rgba(0,0,0,.12),0 5px 5px rgba(0,0,0,.2);}
  .offer-badge{position:absolute;display:flex;align-items:center;justify-content:center;text-align:center;font-family:Tahoma,Arial,sans-serif;line-height:1.1;}.offer-badge strong{display:block;font-size:1em;}.offer-badge span{max-width:100%;}
</style>
