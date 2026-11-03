<script lang="ts">
	import { createEventDispatcher, onDestroy, onMount } from 'svelte';
	import { currentLocale, t } from '$lib/i18n';

	export let mode: 'photo' | 'barcode';

	const dispatch = createEventDispatcher<{ photo: File; scan: string; close: void }>();
	let video: HTMLVideoElement;
	let stream: MediaStream | null = null;
	let timer: ReturnType<typeof setTimeout> | undefined;
	let active = true;
	let generation = 0;
	let starting = true;
	let capturing = false;
	let errorKey = '';

	type Detector = {
		detect(source: HTMLCanvasElement | ImageData): Promise<{ rawValue: string }[]>;
	};
	const formats = ['ean_13', 'ean_8', 'upc_a', 'upc_e', 'code_128', 'code_39'] as const;

	function showDialog(node: HTMLDialogElement) {
		node.showModal();
		return { destroy: () => node.close() };
	}

	function stopCamera() {
		generation++;
		clearTimeout(timer);
		stream?.getTracks().forEach(track => track.stop());
		stream = null;
		if (video) video.srcObject = null;
	}

	function closeCamera() {
		stopCamera();
		dispatch('close');
	}

	async function startCamera() {
		stopCamera();
		const current = generation;
		starting = true;
		errorKey = '';
		try {
			if (!navigator.mediaDevices?.getUserMedia) {
				errorKey = 'cameraUnavailable';
				starting = false;
				return;
			}
			const acquired = await navigator.mediaDevices.getUserMedia({
				video: { facingMode: { ideal: 'environment' }, width: { ideal: 1280 }, height: { ideal: 720 } },
				audio: false
			});
			if (!active || current !== generation) {
				acquired.getTracks().forEach(track => track.stop());
				return;
			}
			stream = acquired;
			video.srcObject = stream;
			await video.play();
			if (!active || current !== generation) return;
			if (mode === 'photo') {
				starting = false;
				return;
			}

			let detector: Detector | undefined;
			const NativeDetector = (window as unknown as {
				BarcodeDetector?: new (options: { formats: string[] }) => Detector;
			}).BarcodeDetector;
			if (NativeDetector) {
				try { detector = new NativeDetector({ formats: [...formats] }); } catch { /* Use the app's polyfill. */ }
			}
			if (!detector) {
				const { BarcodeDetector } = await import('barcode-detector');
				detector = new BarcodeDetector({ formats: [...formats] }) as Detector;
			}
			if (!active || current !== generation) return;
			const canvas = document.createElement('canvas');
			const context = canvas.getContext('2d', { willReadFrequently: true });
			if (!context) throw new Error('Camera canvas is unavailable');
			const reader = detector;
			starting = false;

			async function detectFrame() {
				if (!active || current !== generation) return;
				if (video.readyState >= 2 && video.videoWidth && video.videoHeight) {
					try {
						canvas.width = video.videoWidth;
						canvas.height = video.videoHeight;
						context!.drawImage(video, 0, 0, canvas.width, canvas.height);
						let codes: { rawValue: string }[];
						try { codes = await reader.detect(canvas); }
						catch { codes = await reader.detect(context!.getImageData(0, 0, canvas.width, canvas.height)); }
						if (!active || current !== generation) return;
						const barcode = codes.find(code => code.rawValue?.trim())?.rawValue.trim();
						if (barcode) {
							stopCamera();
							dispatch('scan', barcode);
							return;
						}
					} catch { /* Retry when a frame cannot be decoded. */ }
				}
				if (active && current === generation) timer = setTimeout(detectFrame, 250);
			}
			void detectFrame();
		} catch (failure) {
			if (!active || current !== generation) return;
			stopCamera();
			starting = false;
			errorKey = failure instanceof Error && failure.name === 'NotAllowedError'
				? 'cameraDenied'
				: failure instanceof Error && failure.name === 'NotFoundError'
					? 'cameraNotFound' : 'cameraError';
		}
	}

	function capturePhoto() {
		if (capturing || !stream || !video.videoWidth || !video.videoHeight) return;
		const current = generation;
		const canvas = document.createElement('canvas');
		canvas.width = video.videoWidth;
		canvas.height = video.videoHeight;
		const context = canvas.getContext('2d');
		if (!context) { errorKey = 'photoError'; return; }
		context.drawImage(video, 0, 0);
		capturing = true;
		canvas.toBlob(blob => {
			capturing = false;
			if (!active || current !== generation) return;
			if (!blob) { errorKey = 'photoError'; return; }
			stopCamera();
			dispatch('photo', new File([blob], `direct-order-${Date.now()}.jpg`, { type: 'image/jpeg' }));
		}, 'image/jpeg', 0.9);
	}

	onMount(() => { void startCamera(); });
	onDestroy(() => { active = false; stopCamera(); });
</script>

<dialog
	class="camera-dialog"
	dir={$currentLocale === 'ar' ? 'rtl' : 'ltr'}
	aria-label={t(mode === 'photo' ? 'directOrder.takePhoto' : 'directOrder.scanBarcode')}
	use:showDialog
	on:cancel|preventDefault={closeCamera}
>
	<header>
		<h3>{t(mode === 'photo' ? 'directOrder.takePhoto' : 'directOrder.scanBarcode')}</h3>
		<button type="button" on:click={closeCamera}>{t('directOrder.close')}</button>
	</header>
	<video bind:this={video} autoplay muted playsinline aria-label={t('directOrder.cameraPreview')}></video>
	{#if errorKey}
		<p class="camera-error" role="alert">{t(`directOrder.${errorKey}`)}</p>
		<button type="button" on:click={startCamera}>{t('directOrder.retry')}</button>
	{:else if starting}
		<p role="status">{t('directOrder.openingCamera')}</p>
	{:else if mode === 'barcode'}
		<p role="status">{t('directOrder.scanHint')}</p>
	{/if}
	{#if mode === 'photo'}
		<button class="capture-button" type="button" on:click={capturePhoto} disabled={starting || capturing || !!errorKey}>
			{t('directOrder.capturePhoto')}
		</button>
	{/if}
</dialog>

<style>
	.camera-dialog { box-sizing: border-box; width: calc(100% - 32px); max-width: 640px; max-height: calc(100% - 32px); padding: 20px; border: 0; border-radius: 12px; color: #1f2937; background: white; }
	.camera-dialog::backdrop { background: #0f172ab3; }
	header { display: flex; align-items: center; justify-content: space-between; gap: 12px; margin-bottom: 16px; }
	h3 { margin: 0; font-size: 18px; }
	video { display: block; width: 100%; max-height: 50vh; object-fit: contain; background: #0f172a; border-radius: 8px; }
	p { margin: 14px 0; font-size: 14px; line-height: 1.5; }
	.camera-error { color: #b91c1c; }
	button { padding: 9px 14px; border: 1px solid #cbd5e1; border-radius: 6px; background: white; color: #334155; font: inherit; cursor: pointer; }
	button:focus-visible { outline: 2px solid #2563eb; outline-offset: 2px; }
	button:disabled { opacity: 0.5; cursor: not-allowed; }
	.capture-button { display: block; margin-top: 16px; width: 100%; background: #2563eb; border-color: #2563eb; color: white; }
	@media (max-width: 640px) {
		.camera-dialog { width: calc(100% - 16px); max-height: calc(100dvh - 16px); padding: 16px; padding-bottom: max(16px, env(safe-area-inset-bottom)); }
		button { min-height: 44px; }
		video { max-height: 50dvh; }
	}
</style>
