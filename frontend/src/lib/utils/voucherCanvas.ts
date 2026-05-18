/**
 * Urban Market Surprise Box – Voucher Canvas Generator
 * Matches the official branded design: white left panel + green right panel.
 */

export interface VoucherOptions {
	voucherCode: string;
	voucherValue: number;
	/** Localised reward label (e.g. "قسيمة مشتريات" or "50 SAR Voucher") */
	rewardLabel: string;
	expiresAt?: string;
	billNumber?: string;
}

/** Render the voucher and trigger a PNG download. */
export async function downloadVoucherPNG(opts: VoucherOptions, filename?: string): Promise<void> {
	const url = await buildVoucherCanvas(opts);
	const a = document.createElement('a');
	a.download = filename || `voucher-${opts.voucherCode}.png`;
	a.href = url;
	a.click();
}

/** Build the canvas and return a data-URL PNG. */
async function buildVoucherCanvas(opts: VoucherOptions): Promise<string> {
	const W = 1160, H = 760;
	const SPLIT = 572;           // approx x where wave centreline sits
	const RCX = Math.round(SPLIT + (W - SPLIT) / 2); // right-panel centre ≈ 866

	const C_GREEN      = '#1A6B35';
	const C_DARK_GREEN = '#155229';
	const C_GOLD       = '#C9961A';
	const C_GOLD_LT    = '#F0C842';
	const C_CREAM      = '#F6F5EE';

	const canvas = document.createElement('canvas');
	canvas.width = W;
	canvas.height = H;
	const ctx = canvas.getContext('2d')!;

	// ── Clip everything to the rounded card ──────────────────
	ctx.save();
	ctx.beginPath();
	ctx.roundRect(0, 0, W, H, 24);
	ctx.clip();

	// ── LEFT PANEL – cream background ────────────────────────
	ctx.fillStyle = C_CREAM;
	ctx.fillRect(0, 0, W, H);

	// ── RIGHT PANEL – green with wave left edge ───────────────
	ctx.fillStyle = C_GREEN;
	ctx.beginPath();
	ctx.moveTo(SPLIT, 0);
	ctx.bezierCurveTo(SPLIT - 82, H * 0.25, SPLIT - 82, H * 0.75, SPLIT, H);
	ctx.lineTo(W, H);
	ctx.lineTo(W, 0);
	ctx.closePath();
	ctx.fill();

	// ── LOGO ─────────────────────────────────────────────────
	const logo = await loadImg('/icons/logo.png');
	if (logo) {
		const lH = 86;
		const lW = Math.round(lH * (logo.naturalWidth / logo.naturalHeight));
		ctx.drawImage(logo, 40, 26, lW, lH);
	} else {
		// Text fallback
		ctx.fillStyle = '#F97316';
		ctx.font = 'bold 34px Tahoma, Arial';
		ctx.textAlign = 'left';
		ctx.fillText('أوربان', 40, 76);
		ctx.fillStyle = C_GREEN;
		ctx.font = 'bold 24px Tahoma, Arial';
		ctx.fillText('ماركت', 40, 110);
	}

	// Thin gold separator line below logo
	ctx.fillStyle = C_GOLD + '55';
	ctx.fillRect(38, 140, SPLIT - 56, 1.5);

	// ── LEFT PANEL – VALUE ───────────────────────────────────
	const val = opts.voucherValue > 0 ? String(Math.round(opts.voucherValue)) : '0';

	// Big value number (green, centred ~x=250)
	ctx.fillStyle = C_GREEN;
	ctx.font = 'bold 200px Tahoma, Arial';
	ctx.textAlign = 'center';
	ctx.fillText(val, 248, 460);

	// "ريال" – upper-right of the large number
	ctx.font = 'bold 58px Tahoma, Arial';
	ctx.textAlign = 'center';
	ctx.fillText('ريال', 454, 346);

	// Reward label (Arabic)
	ctx.fillStyle = C_GREEN;
	ctx.font = 'bold 36px Tahoma, Arial';
	ctx.textAlign = 'center';
	ctx.fillText(opts.rewardLabel || 'قسيمة مشتريات', 276, 520);

	// English sub-label
	ctx.fillStyle = C_GOLD;
	ctx.font = 'bold 19px Arial';
	ctx.textAlign = 'center';
	ctx.fillText('SHOPPING VOUCHER', 276, 554);

	// ── FEATURE ICONS ROW ────────────────────────────────────
	const featureLabels  = ['جودة مميزة', 'منتجات طازجة', 'نظافة واهتمام', 'خدمة عملاء راقية'];
	const featureSymbols = ['★', '♦', '✓', '♡'];
	const featureXs  = [63, 193, 334, 470];
	const dividerXs  = [130, 266, 404];

	dividerXs.forEach(x => {
		ctx.fillStyle = '#C8C8C8';
		ctx.fillRect(x, 596, 1, 52);
	});

	featureXs.forEach((x, i) => {
		ctx.fillStyle = C_GOLD;
		ctx.beginPath();
		ctx.arc(x, 612, 15, 0, Math.PI * 2);
		ctx.fill();

		ctx.fillStyle = '#FFF';
		ctx.font = 'bold 14px Arial';
		ctx.textAlign = 'center';
		ctx.fillText(featureSymbols[i], x, 617);

		ctx.fillStyle = '#555';
		ctx.font = '12px Tahoma, Arial';
		ctx.fillText(featureLabels[i], x, 640);
	});

	// ── EXPIRY BAR (dark green strip, bottom-left) ───────────
	ctx.fillStyle = C_DARK_GREEN;
	ctx.fillRect(0, H - 62, SPLIT - 50, 62);

	let expStr = '—';
	if (opts.expiresAt) {
		try {
			const d = new Date(opts.expiresAt);
			expStr = `${String(d.getDate()).padStart(2, '0')}/${String(d.getMonth() + 1).padStart(2, '0')}/${d.getFullYear()}`;
		} catch { expStr = opts.expiresAt; }
	}

	ctx.fillStyle = '#FFF';
	ctx.font = 'bold 21px Tahoma, Arial';
	ctx.textAlign = 'left';
	ctx.fillText('📅  صالح حتى: ' + expStr, 30, H - 18);

	// ── DECORATIVE BOW (top-right corner of green panel) ─────
	drawBow(ctx, W - 148, 82, C_GOLD, C_GOLD_LT);

	// ── RIGHT PANEL – TEXT CONTENT ───────────────────────────
	ctx.fillStyle = C_GOLD_LT;
	ctx.font = 'bold 27px Tahoma, Arial';
	ctx.textAlign = 'center';
	ctx.fillText('هذه القسيمة بقيمة', RCX, 172);

	ctx.font = 'bold 106px Tahoma, Arial';
	ctx.fillText(val, RCX, 295);

	ctx.font = 'bold 50px Tahoma, Arial';
	ctx.fillText('ريال', RCX, 360);

	ctx.fillStyle = 'rgba(255,255,255,0.82)';
	ctx.font = '22px Tahoma, Arial';
	ctx.fillText('تستخدم في زيارة لاحقة', RCX, 408);

	// ── QR CODE BOX ──────────────────────────────────────────
	const qrW = 214, qrH = 207;
	const qrX = RCX - qrW / 2;
	const qrY = 425;

	// White box with shadow
	ctx.shadowColor    = 'rgba(0,0,0,0.28)';
	ctx.shadowBlur     = 16;
	ctx.shadowOffsetY  = 4;
	ctx.fillStyle = '#FFF';
	ctx.beginPath();
	ctx.roundRect(qrX, qrY, qrW, qrH, 12);
	ctx.fill();
	ctx.shadowColor = 'transparent';
	ctx.shadowBlur = 0;
	ctx.shadowOffsetY = 0;

	// "كود القسيمة" label
	ctx.fillStyle = C_GREEN;
	ctx.font = 'bold 17px Tahoma, Arial';
	ctx.textAlign = 'center';
	ctx.fillText('كود القسيمة', RCX, qrY + 27);

	// Divider inside box
	ctx.fillStyle = '#E4E4E4';
	ctx.fillRect(qrX + 14, qrY + 35, qrW - 28, 1);

	// QR code image
	try {
		const QRCode = await import('qrcode');
		const qrUrl  = await QRCode.toDataURL(opts.voucherCode, { width: 168, margin: 1 });
		const qrImg  = await loadImg(qrUrl);
		if (qrImg) ctx.drawImage(qrImg, qrX + 23, qrY + 40, 168, 162);
	} catch { /* skip QR if unavailable */ }

	// ── CODE BAR (gold bar at bottom of right panel) ─────────
	const cbY = H - 80;
	ctx.fillStyle = C_GOLD;
	ctx.beginPath();
	ctx.roundRect(qrX, cbY, qrW, 52, 9);
	ctx.fill();

	ctx.fillStyle = '#FFF';
	ctx.font = 'bold 21px "Courier New", monospace';
	ctx.textAlign = 'center';
	ctx.fillText(opts.voucherCode, RCX, cbY + 35);

	// ── End clip ─────────────────────────────────────────────
	ctx.restore();

	// ── GOLD OUTER BORDER (drawn on top, outside clip) ───────
	ctx.strokeStyle = C_GOLD;
	ctx.lineWidth   = 4;
	ctx.beginPath();
	ctx.roundRect(2, 2, W - 4, H - 4, 23);
	ctx.stroke();

	return canvas.toDataURL('image/png', 1.0);
}

/** Load an image from a URL; resolves null on error or timeout. */
function loadImg(src: string): Promise<HTMLImageElement | null> {
	return new Promise((resolve) => {
		const img = new Image();
		const timer = setTimeout(() => resolve(null), 4000);
		img.onload  = () => { clearTimeout(timer); resolve(img); };
		img.onerror = () => { clearTimeout(timer); resolve(null); };
		img.src = src;
	});
}

/** Draw a gold bow/ribbon decoration in the top-right area. */
function drawBow(
	ctx: CanvasRenderingContext2D,
	cx: number, cy: number,
	gold: string, goldLt: string
): void {
	ctx.save();

	// Ribbon tails radiating to the corner
	ctx.strokeStyle = goldLt;
	ctx.lineWidth   = 5;
	ctx.lineCap     = 'round';
	ctx.globalAlpha = 0.88;

	ctx.beginPath();
	ctx.moveTo(cx, cy);
	ctx.lineTo(cx + 148, cy - 82);
	ctx.stroke();

	ctx.beginPath();
	ctx.moveTo(cx, cy);
	ctx.lineTo(cx + 148, cy + 82);
	ctx.stroke();

	ctx.globalAlpha = 1;

	// Left bow wing
	ctx.fillStyle = gold;
	ctx.beginPath();
	ctx.moveTo(cx, cy);
	ctx.bezierCurveTo(cx - 45, cy - 55, cx - 90, cy - 5, cx - 65, cy + 42);
	ctx.bezierCurveTo(cx - 38, cy + 72, cx - 6, cy + 47, cx, cy);
	ctx.closePath();
	ctx.fill();
	ctx.strokeStyle = goldLt;
	ctx.lineWidth   = 1.5;
	ctx.stroke();

	// Right bow wing
	ctx.fillStyle = gold;
	ctx.beginPath();
	ctx.moveTo(cx, cy);
	ctx.bezierCurveTo(cx + 38, cy - 52, cx + 82, cy - 18, cx + 68, cy + 30);
	ctx.bezierCurveTo(cx + 54, cy + 65, cx + 16, cy + 45, cx, cy);
	ctx.closePath();
	ctx.fill();
	ctx.stroke();

	// Centre knot
	ctx.fillStyle = goldLt;
	ctx.beginPath();
	ctx.ellipse(cx, cy, 13, 17, 0.2, 0, Math.PI * 2);
	ctx.fill();

	ctx.restore();
}
