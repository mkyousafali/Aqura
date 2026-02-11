<script lang="ts">
	import { onMount } from 'svelte';
	import { DotLottie } from '@lottiefiles/dotlottie-web';
	import { currentLocale } from '$lib/i18n';

	let showBubble = false;
	let bubbleText = '';
	let hidden = false;
	let canvasEl: HTMLCanvasElement;
	let dotLottie: DotLottie | null = null;
	let messageIndex = 0;
	let bubbleTimer: ReturnType<typeof setTimeout> | null = null;
	let intervalTimer: ReturnType<typeof setInterval> | null = null;

	const greetingsEn = [
		'Assalamu Alaikum 🤲',
		'Subhanallah ✨',
		'Alhamdulillah 🌟',
		'Astaghfirullah 🤲',
		'La ilaha illallah 🕌',
		'Believe in yourself 💪',
		'Keep going 🚀',
		'Stay strong 💎',
		'Success is near ⭐',
		'You can do it 🎯',
		'Never give up 🔥',
		'Think positive 💡',
		'Hard work pays off 🏆',
		'Aim high 📈',
		'Trust Allah 🤲',
		'Be patient ☀️',
		'Every day is a new chance 🌅',
		'Start now ▶️',
		'Dream big 🌙',
		'Stay focused 🎯'
	];

	const greetingsAr = [
		'السلام عليكم 🤲',
		'سبحان الله ✨',
		'الحمد لله 🌟',
		'أستغفر الله 🤲',
		'لا إله إلا الله 🕌',
		'آمن بنفسك 💪',
		'استمر 🚀',
		'كن قويًا 💎',
		'النجاح قريب ⭐',
		'تستطيع فعلها 🎯',
		'لا تستسلم 🔥',
		'فكر بإيجابية 💡',
		'العمل الجاد يؤتي ثماره 🏆',
		'ارفع سقف طموحك 📈',
		'توكل على الله 🤲',
		'كن صبورًا ☀️',
		'كل يوم فرصة جديدة 🌅',
		'ابدأ الآن ▶️',
		'احلم كبيرًا 🌙',
		'حافظ على تركيزك 🎯'
	];

	$: greetings = $currentLocale === 'ar' ? greetingsAr : greetingsEn;

	// Animation file from static folder
	const ANIMATION_URL = '/animations/businessman.lottie';

	function showNextMessage() {
		if (bubbleTimer) clearTimeout(bubbleTimer);
		bubbleText = greetings[messageIndex % greetings.length];
		messageIndex++;
		showBubble = true;
		bubbleTimer = setTimeout(() => {
			showBubble = false;
			bubbleTimer = null;
		}, 4000);
	}

	onMount(() => {
		dotLottie = new DotLottie({
			canvas: canvasEl,
			src: ANIMATION_URL,
			loop: true,
			autoplay: true,
			speed: 0.8
		});

		// Show messages automatically in order: 4s visible, 2s pause, then next
		intervalTimer = setInterval(() => {
			if (!showBubble) {
				showNextMessage();
			}
		}, 6000);

		// Show first message after 3 seconds
		setTimeout(() => showNextMessage(), 3000);

		return () => {
			dotLottie?.destroy();
			if (intervalTimer) clearInterval(intervalTimer);
			if (bubbleTimer) clearTimeout(bubbleTimer);
		};
	});

	function handleClick() {
		showNextMessage();
	}

	function handleHide() {
		hidden = true;
		setTimeout(() => (hidden = false), 30000);
	}
</script>

{#if !hidden}
	<div class="character-wrapper">
		{#if showBubble}
			<div class="speech-bubble" style:direction={$currentLocale === 'ar' ? 'rtl' : 'ltr'}>
				{bubbleText}
				<div class="bubble-tail"></div>
			</div>
		{/if}

		<button
			class="character-btn"
			on:click={handleClick}
			on:dblclick={handleHide}
			title="Click to greet • Double-click to hide"
		>
			<canvas bind:this={canvasEl} width="150" height="150" class="character-canvas"></canvas>
		</button>
	</div>
{/if}

<style>
	.character-wrapper {
		position: fixed;
		bottom: 52px;
		right: 16px;
		z-index: 1999;
		pointer-events: auto;
		display: flex;
		flex-direction: column;
		align-items: center;
	}

	.speech-bubble {
		position: absolute;
		bottom: 155px;
		right: -10px;
		background: #fff;
		color: #333;
		padding: 8px 16px;
		border-radius: 14px;
		font-size: 13px;
		font-weight: 600;
		white-space: nowrap;
		box-shadow: 0 4px 20px rgba(0, 0, 0, 0.12);
		animation: bubblePop 0.35s cubic-bezier(0.34, 1.56, 0.64, 1);
		z-index: 10;
		font-family: 'Segoe UI', Tahoma, Arial, sans-serif;
		direction: ltr;
	}

	.bubble-tail {
		position: absolute;
		bottom: -7px;
		right: 20px;
		width: 0;
		height: 0;
		border-left: 7px solid transparent;
		border-right: 7px solid transparent;
		border-top: 9px solid #fff;
	}

	@keyframes bubblePop {
		0% {
			transform: scale(0) translateY(10px);
			opacity: 0;
		}
		60% {
			transform: scale(1.08) translateY(-3px);
			opacity: 1;
		}
		100% {
			transform: scale(1) translateY(0);
			opacity: 1;
		}
	}

	.character-btn {
		background: none;
		border: none;
		padding: 0;
		cursor: pointer;
		outline: none;
		transition: filter 0.3s;
		-webkit-tap-highlight-color: transparent;
	}

	.character-btn:hover {
		filter: drop-shadow(0 2px 12px rgba(100, 100, 200, 0.3));
	}

	.character-canvas {
		width: 150px;
		height: 150px;
	}

	@media (max-width: 768px) {
		.character-wrapper {
			display: none;
		}
	}
</style>
