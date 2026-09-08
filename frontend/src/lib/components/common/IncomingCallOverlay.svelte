<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { outgoingCallRequest, outgoingTextRequest } from '$lib/stores/callStore';
	import { speakWithGoogleTTS, stopSpeaking } from '$lib/utils/ttsService';
	import { sendPushNotification } from '$lib/utils/pushNotificationSender';

	// ── Call phases ──
	// idle: no call | outgoing: waiting for answer | incoming: ringing
	// connecting: WebRTC handshake | active: voice connected
	type CallPhase = 'idle' | 'outgoing' | 'incoming' | 'connecting' | 'active';

	let phase: CallPhase = 'idle';
	let peerName = '';
	let peerNameAr = '';
	let peerId = '';
	let myUserId = '';

	// ── Text message overlay ──
	let showTextOverlay = false;
	let textSenderName = '';
	let textSenderNameAr = '';
	let textMessage = '';

	// WebRTC
	let peerConnection: RTCPeerConnection | null = null;
	let localStream: MediaStream | null = null;
	let remoteAudio: HTMLAudioElement;
	let isMuted = false;
	let micError = '';

	// Call timer
	let callDuration = 0;
	let callTimer: any = null;

	// Outgoing call timeout (120s)
	let outgoingTimeout: any = null;
	let rebroadcastInterval: any = null;  // Re-sends incoming_call signal periodically

	// Audio
	let ringtoneAudio: HTMLAudioElement | null = null;

	// Channels
	let myChannel: any = null;       // Personal channel for initial notifications
	let sessionChannel: any = null;  // Shared channel for call signaling

	const ICE_SERVERS: RTCIceServer[] = [
		{ urls: 'stun:stun.l.google.com:19302' },
		{ urls: 'stun:stun1.l.google.com:19302' },
		{ urls: 'stun:stun2.l.google.com:19302' }
	];

	// ──────── Lifecycle ────────
	let unsubUser: any;
	let unsubOutgoing: any;
	let unsubText: any;

	onMount(() => {
		unsubUser = currentUser.subscribe((user) => {
			if (user?.id && user.id !== myUserId) {
				myUserId = user.id;
				setupMyChannel(user.id);
			}
		});

		unsubOutgoing = outgoingCallRequest.subscribe((req) => {
			if (req && phase === 'idle' && myUserId) {
				startOutgoingCall(req);
				outgoingCallRequest.set(null);
			}
		});

		unsubText = outgoingTextRequest.subscribe((req) => {
			if (req && myUserId) {
				sendTextToUser(req);
				outgoingTextRequest.set(null);
			}
		});
	});

	onDestroy(() => {
		unsubUser?.();
		unsubOutgoing?.();
		unsubText?.();
		cleanupAll();
	});

	// ──────── Personal Channel (initial call notifications) ────────
	function setupMyChannel(userId: string) {
		if (myChannel) supabase.removeChannel(myChannel);

		myChannel = supabase
			.channel(`incoming-call:${userId}`)
			.on('broadcast', { event: 'incoming_call' }, (payload: any) => {
				if (phase !== 'idle') return; // Already in a call
				const { caller_name, caller_name_ar, caller_id } = payload.payload;
				peerName = caller_name || 'Unknown';
				peerNameAr = caller_name_ar || '';
				peerId = caller_id;
				phase = 'incoming';
				startRinging();
				announceIncomingCall(caller_name, caller_name_ar);
			})
			.on('broadcast', { event: 'incoming_text' }, (payload: any) => {
				const { sender_name, sender_name_ar, message } = payload.payload;
				textSenderName = sender_name || 'Unknown';
				textSenderNameAr = sender_name_ar || '';
				textMessage = message || '';
				showTextOverlay = true;
				announceIncomingText(sender_name, sender_name_ar, message);
			})
			.subscribe((status: string) => {
				if (status === 'SUBSCRIBED') {
					console.log('📞 Call channel ready for user:', userId);
				}
			});
	}

	// ──────── Session Channel (signaling during call) ────────
	function getSessionName(): string {
		return `call:${[myUserId, peerId].sort().join('-')}`;
	}

	function joinSession(): Promise<void> {
		return new Promise((resolve) => {
			if (sessionChannel) { resolve(); return; }

			sessionChannel = supabase
				.channel(getSessionName())
				.on('broadcast', { event: 'call_accepted' }, async () => {
					console.log('📞 [CALL] Received call_accepted, phase:', phase);
					if (phase !== 'outgoing') return;
					stopRinging();
					clearTimeout(outgoingTimeout);
					clearInterval(rebroadcastInterval);
					phase = 'connecting';
					await createOfferAndSend();
				})
				.on('broadcast', { event: 'call_declined' }, () => {
					console.log('📞 [CALL] Received call_declined');
					if (phase !== 'outgoing') return;
					stopRinging();
					clearTimeout(outgoingTimeout);
					clearInterval(rebroadcastInterval);
					phase = 'idle';
					resetState();
				})
				.on('broadcast', { event: 'call_offer' }, async (payload: any) => {
					console.log('📞 [CALL] Received call_offer');
					const { sdp } = payload.payload;
					await handleReceivedOffer(sdp);
				})
				.on('broadcast', { event: 'call_answer' }, async (payload: any) => {
					if (!peerConnection) return;
					const { sdp } = payload.payload;
					try {
						await peerConnection.setRemoteDescription(new RTCSessionDescription(sdp));
					} catch (err) {
						console.error('Failed to set remote description:', err);
					}
				})
				.on('broadcast', { event: 'ice_candidate' }, async (payload: any) => {
					if (!peerConnection) return;
					const { candidate } = payload.payload;
					if (candidate) {
						try {
							await peerConnection.addIceCandidate(new RTCIceCandidate(candidate));
						} catch (err) {
							console.error('Failed to add ICE candidate:', err);
						}
					}
				})
				.on('broadcast', { event: 'call_ended' }, () => {
					console.log('📞 [CALL] Received call_ended');
					endCall(false);
				})
				.subscribe((status: string) => {
					if (status === 'SUBSCRIBED') resolve();
				});
		});
	}

	function leaveSession() {
		if (sessionChannel) {
			supabase.removeChannel(sessionChannel);
			sessionChannel = null;
		}
	}

	async function sendSignal(event: string, payload: any) {
		if (!sessionChannel) return;
		await sessionChannel.send({ type: 'broadcast', event, payload });
	}

	// ──────── Send initial notification to peer's personal channel ────────
	async function notifyPeer(event: string, payload: any) {
		const ch = supabase.channel(`incoming-call:${peerId}`);
		// Wait for SUBSCRIBED status before sending
		await new Promise<void>((resolve) => {
			ch.subscribe((status: string) => {
				if (status === 'SUBSCRIBED') resolve();
			});
		});
		await ch.send({ type: 'broadcast', event, payload });
		supabase.removeChannel(ch);
	}

	// ──────── Outgoing Call (triggered from Taskbar via store) ────────
	async function startOutgoingCall(req: any) {
		phase = 'outgoing';
		peerName = req.targetName;
		peerNameAr = req.targetNameAr;
		peerId = req.targetUserId;

		// Join session channel first so we're ready for the response
		await joinSession();

		const callSignalPayload = {
			caller_name: req.callerName,
			caller_name_ar: req.callerNameAr,
			caller_id: myUserId
		};

		// Send notification to peer's personal channel
		await notifyPeer('incoming_call', callSignalPayload);

		// Also send push notification in case the app is closed
		sendPushNotification({
			notificationId: `call-${Date.now()}`,
			userIds: [req.targetUserId],
			title: '📞 Incoming Call — Aqura',
			body: `Urgent call from ${req.callerName}`,
			type: 'incoming_call',
			url: '/',
			data: callSignalPayload
		}).catch((err) => console.warn('Push notification failed (call):', err));

		startOutgoingTone();

		// Re-broadcast incoming_call every 5s so if the other user opens the app
		// from push notification, they will catch a re-broadcast
		rebroadcastInterval = setInterval(() => {
			if (phase !== 'outgoing') { clearInterval(rebroadcastInterval); return; }
			notifyPeer('incoming_call', callSignalPayload).catch(() => {});
		}, 5000);

		// Timeout after 120 seconds if no response
		outgoingTimeout = setTimeout(() => {
			if (phase === 'outgoing') {
				clearInterval(rebroadcastInterval);
				sendSignal('call_ended', {}).catch(() => {});
				stopRinging();
				phase = 'idle';
				resetState();
			}
		}, 120000);
	}

	// ──────── Accept incoming call ────────
	async function acceptCall() {
		stopRinging();
		stopAnnouncement(); // Stop TTS announcement loop
		phase = 'connecting';
		micError = '';

		// Check if MediaDevices API is available (requires HTTPS)
		if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
			console.error('❌ MediaDevices not available — site not served over HTTPS?');
			micError = 'Microphone not available. Voice calls require HTTPS.';
			phase = 'incoming';
			startRinging();
			return;
		}

		// Check existing permission state (if API available)
		try {
			if (navigator.permissions) {
				const permStatus = await navigator.permissions.query({ name: 'microphone' as PermissionName });
				console.log('📞 [CALL] Microphone permission state:', permStatus.state);
				if (permStatus.state === 'denied') {
					micError = 'Microphone blocked. Go to browser settings → Site permissions → Microphone → Allow.';
					phase = 'incoming';
					startRinging();
					return;
				}
			}
		} catch {
			// permissions.query not supported for microphone on some browsers — continue
		}

		// Request microphone access BEFORE telling the caller we accepted.
		try {
			console.log('📞 [CALL] Requesting microphone access...');
			localStream = await navigator.mediaDevices.getUserMedia({ audio: true });
			console.log('🎤 Microphone access granted');
		} catch (err: any) {
			console.error('❌ Microphone access failed:', err);
			if (err?.name === 'NotAllowedError') {
				micError = 'Microphone access denied. Tap Accept again and allow microphone when prompted.';
			} else if (err?.name === 'NotFoundError') {
				micError = 'No microphone found on this device.';
			} else {
				micError = `Microphone error: ${err?.message || 'Unknown error'}`;
			}
			phase = 'incoming'; // Go back to incoming so user can retry
			startRinging();
			return;
		}

		// Mic works — join session channel and tell caller we accepted
		await joinSession();
		await sendSignal('call_accepted', {});
		// Now wait for the caller to send us a WebRTC offer
	}

	// ──────── Decline incoming call ────────
	async function declineCall() {
		stopRinging();
		stopAnnouncement(); // Stop TTS announcement loop
		// Join session briefly to send decline
		await joinSession();
		await sendSignal('call_declined', {});
		leaveSession();
		phase = 'idle';
		resetState();
	}

	// ──────── Cancel outgoing call ────────
	function cancelOutgoingCall() {
		clearTimeout(outgoingTimeout);
		clearInterval(rebroadcastInterval);
		sendSignal('call_ended', {}).catch(() => {});
		stopRinging();
		leaveSession();
		phase = 'idle';
		resetState();
	}

	// ──────── WebRTC: Caller creates offer ────────
	async function createOfferAndSend() {
		try {
			localStream = await navigator.mediaDevices.getUserMedia({ audio: true });
			peerConnection = createPeerConnection();

			localStream.getTracks().forEach(track => {
				peerConnection!.addTrack(track, localStream!);
			});

			const offer = await peerConnection.createOffer();
			await peerConnection.setLocalDescription(offer);

			await sendSignal('call_offer', {
				sdp: { type: offer.type, sdp: offer.sdp }
			});
		} catch (err: any) {
			console.error('❌ Failed to create offer:', err);
			micError = err?.message?.includes('Permission') || err?.message?.includes('NotAllowed')
				? 'Microphone access denied'
				: 'Failed to start call';
			endCall(true);
		}
	}

	// ──────── WebRTC: Receiver handles offer ────────
	async function handleReceivedOffer(sdp: RTCSessionDescriptionInit) {
		try {
			// localStream may already be set from acceptCall(); only request if not
			if (!localStream) {
				localStream = await navigator.mediaDevices.getUserMedia({ audio: true });
			}
			peerConnection = createPeerConnection();

			localStream.getTracks().forEach(track => {
				peerConnection!.addTrack(track, localStream!);
			});

			await peerConnection.setRemoteDescription(new RTCSessionDescription(sdp));
			const answer = await peerConnection.createAnswer();
			await peerConnection.setLocalDescription(answer);

			await sendSignal('call_answer', {
				sdp: { type: answer.type, sdp: answer.sdp }
			});
		} catch (err: any) {
			console.error('❌ Failed to handle offer:', err);
			micError = err?.message?.includes('Permission') || err?.message?.includes('NotAllowed')
				? 'Microphone access denied'
				: 'Failed to connect call';
			endCall(true);
		}
	}

	// ──────── Create RTCPeerConnection ────────
	function createPeerConnection(): RTCPeerConnection {
		const pc = new RTCPeerConnection({ iceServers: ICE_SERVERS });

		pc.onicecandidate = (event) => {
			if (event.candidate) {
				sendSignal('ice_candidate', { candidate: event.candidate.toJSON() });
			}
		};

		pc.ontrack = (event) => {
			if (remoteAudio && event.streams[0]) {
				remoteAudio.srcObject = event.streams[0];
				remoteAudio.play().catch(() => console.log('Remote audio autoplay blocked'));
			}
		};

		pc.onconnectionstatechange = () => {
			console.log('📞 [CALL] Connection state:', pc.connectionState);
			if (pc.connectionState === 'connected') {
				phase = 'active';
				startCallTimer();
			} else if (pc.connectionState === 'disconnected' || pc.connectionState === 'failed') {
				endCall(true);
			}
		};

		return pc;
	}

	// ──────── End call ────────
	function endCall(shouldNotify = true) {
		clearTimeout(outgoingTimeout);
		clearInterval(rebroadcastInterval);

		if (shouldNotify && sessionChannel) {
			sendSignal('call_ended', {}).catch(() => {});
		}

		// Stop WebRTC
		if (peerConnection) {
			peerConnection.close();
			peerConnection = null;
		}

		if (localStream) {
			localStream.getTracks().forEach(t => t.stop());
			localStream = null;
		}

		stopRinging();
		stopAnnouncement(); // Stop TTS announcement loop
		stopCallTimer();
		leaveSession();
		phase = 'idle';
		resetState();
	}

	// ──────── Mute/Unmute ────────
	function toggleMute() {
		if (localStream) {
			const audioTrack = localStream.getAudioTracks()[0];
			if (audioTrack) {
				audioTrack.enabled = !audioTrack.enabled;
				isMuted = !audioTrack.enabled;
			}
		}
	}

	// ──────── Call timer ────────
	function startCallTimer() {
		callDuration = 0;
		callTimer = setInterval(() => { callDuration++; }, 1000);
	}

	function stopCallTimer() {
		if (callTimer) {
			clearInterval(callTimer);
			callTimer = null;
		}
		callDuration = 0;
	}

	function formatDuration(secs: number): string {
		const m = Math.floor(secs / 60).toString().padStart(2, '0');
		const s = (secs % 60).toString().padStart(2, '0');
		return `${m}:${s}`;
	}

	// ──────── Audio ────────
	function startRinging() {
		try {
			ringtoneAudio = new Audio('/sounds/ringtone.mp3');
			ringtoneAudio.loop = true;
			ringtoneAudio.volume = 0.7;
			ringtoneAudio.play().catch(() => console.log('📞 Ringtone autoplay blocked'));
		} catch { /* no sound file */ }
	}

	function startOutgoingTone() {
		try {
			ringtoneAudio = new Audio('/sounds/ringtone.mp3');
			ringtoneAudio.loop = true;
			ringtoneAudio.volume = 0.3;
			ringtoneAudio.play().catch(() => console.log('📞 Outgoing tone blocked'));
		} catch { /* no sound file */ }
	}

	function stopRinging() {
		if (ringtoneAudio) {
			ringtoneAudio.pause();
			ringtoneAudio.currentTime = 0;
			ringtoneAudio = null;
		}
	}

	// ──────── TTS Announcements ────────
	// English first (British female Neural), then Arabic — repeat until responded
	const EN_VOICE = 'en-neural2-a'; // British Woman (Neural)
	const AR_VOICE = 'ar-wavenet-a'; // Arabic Woman (Wavenet)
	let announcementActive = false;

	async function announceIncomingCall(callerName: string, callerNameAr: string) {
		announcementActive = true;
		const enText = `Urgent emergency call from ${callerName || 'unknown'} on Aqura`;
		const arName = callerNameAr || callerName || 'مجهول';
		const arText = `مكالمة طوارئ عاجلة من ${arName} على أكورا`;

		while (announcementActive && phase === 'incoming') {
			try {
				await speakWithGoogleTTS(enText, 'en', EN_VOICE);
				if (!announcementActive || phase !== 'incoming') break;
				await speakWithGoogleTTS(arText, 'ar', AR_VOICE);
				if (!announcementActive || phase !== 'incoming') break;
				// Brief pause before repeating
				await new Promise(r => setTimeout(r, 1500));
			} catch (err) {
				console.log('📞 TTS announcement failed:', err);
				break;
			}
		}
	}

	async function announceIncomingText(senderName: string, senderNameAr: string, message: string) {
		announcementActive = true;
		const enText = `Text from ${senderName || 'unknown'}. ${senderName || 'The user'} says: ${message}`;
		const arName = senderNameAr || senderName || 'مجهول';
		const arText = `رسالة من ${arName}. ${arName} يقول: ${message}`;

		while (announcementActive && showTextOverlay) {
			try {
				await speakWithGoogleTTS(enText, 'en', EN_VOICE);
				if (!announcementActive || !showTextOverlay) break;
				await speakWithGoogleTTS(arText, 'ar', AR_VOICE);
				if (!announcementActive || !showTextOverlay) break;
				// Brief pause before repeating
				await new Promise(r => setTimeout(r, 1500));
			} catch (err) {
				console.log('📞 TTS text announcement failed:', err);
				break;
			}
		}
	}

	function stopAnnouncement() {
		announcementActive = false;
		stopSpeaking();
	}

	// ──────── Text Message ────────
	async function sendTextToUser(req: any) {
		const ch = supabase.channel(`incoming-call:${req.targetUserId}`);
		await new Promise<void>((resolve) => {
			ch.subscribe((status: string) => {
				if (status === 'SUBSCRIBED') resolve();
			});
		});
		await ch.send({
			type: 'broadcast',
			event: 'incoming_text',
			payload: {
				sender_name: req.senderName,
				sender_name_ar: req.senderNameAr,
				message: req.message
			}
		});
		supabase.removeChannel(ch);

		// Also send push notification in case the app is closed
		sendPushNotification({
			notificationId: `text-${Date.now()}`,
			userIds: [req.targetUserId],
			title: `💬 Message from ${req.senderName}`,
			body: req.message,
			type: 'incoming_text',
			url: '/',
			data: {
				sender_name: req.senderName,
				sender_name_ar: req.senderNameAr,
				message: req.message
			}
		}).catch((err) => console.warn('Push notification failed (text):', err));
	}

	function dismissText() {
		showTextOverlay = false;
		stopAnnouncement(); // Stop TTS announcement loop
		textSenderName = '';
		textSenderNameAr = '';
		textMessage = '';
	}

	// ──────── Cleanup ────────
	function resetState() {
		peerName = '';
		peerNameAr = '';
		peerId = '';
		isMuted = false;
		micError = '';
		callDuration = 0;
	}

	function cleanupAll() {
		endCall(false);
		if (myChannel) {
			supabase.removeChannel(myChannel);
			myChannel = null;
		}
	}
</script>

<!-- Hidden audio element for remote voice playback -->
<audio bind:this={remoteAudio} autoplay></audio>

{#if phase !== 'idle'}
	<div class="call-overlay">
		<div class="call-card">

			{#if phase === 'outgoing'}
				<!-- ── OUTGOING: Waiting for answer ── -->
				<div class="call-icon-ring">
					<div class="call-icon-pulse"></div>
					<div class="call-icon-pulse delay"></div>
					<div class="call-icon-center">
						<svg width="48" height="48" viewBox="0 0 24 24" fill="white" stroke="none">
							<path d="M20.01 15.38c-1.23 0-2.42-.2-3.53-.56a.977.977 0 0 0-1.01.24l-1.57 1.97c-2.83-1.35-5.48-3.9-6.89-6.83l1.95-1.66c.27-.28.35-.67.24-1.02-.37-1.11-.56-2.3-.56-3.53 0-.54-.45-.99-.99-.99H4.19C3.65 3 3 3.24 3 3.99 3 13.28 10.73 21 20.01 21c.71 0 .99-.63.99-1.18v-3.45c0-.54-.45-.99-.99-.99z"/>
						</svg>
					</div>
				</div>

				<div class="call-phase-label">Calling...</div>
				<div class="caller-info">
					<div class="caller-name">{peerName}</div>
					{#if peerNameAr}
						<div class="caller-name-ar">{peerNameAr}</div>
					{/if}
				</div>
				<div class="call-status">Ringing...</div>

				<button class="end-call-btn" on:click={cancelOutgoingCall} aria-label="Cancel call">
					<svg width="24" height="24" viewBox="0 0 24 24" fill="white" stroke="none">
						<path d="M12 9c-1.6 0-3.15.25-4.6.72v3.1c0 .39-.23.74-.56.9-.98.49-1.87 1.12-2.66 1.85-.18.18-.43.28-.7.28-.28 0-.53-.11-.71-.29L.29 13.08c-.18-.17-.29-.42-.29-.7 0-.28.11-.53.29-.71C3.34 8.78 7.46 7 12 7s8.66 1.78 11.71 4.67c.18.18.29.43.29.71 0 .28-.11.53-.29.71l-2.48 2.48c-.18.18-.43.29-.71.29-.27 0-.52-.11-.7-.28-.79-.74-1.69-1.36-2.67-1.85-.33-.16-.56-.5-.56-.9v-3.1C15.15 9.25 13.6 9 12 9z"/>
					</svg>
					<span>Cancel</span>
				</button>

			{:else if phase === 'incoming'}
				<!-- ── INCOMING: Accept or Decline ── -->
				<div class="call-icon-ring">
					<div class="call-icon-pulse"></div>
					<div class="call-icon-pulse delay"></div>
					<div class="call-icon-center shaking">
						<svg width="48" height="48" viewBox="0 0 24 24" fill="white" stroke="none">
							<path d="M20.01 15.38c-1.23 0-2.42-.2-3.53-.56a.977.977 0 0 0-1.01.24l-1.57 1.97c-2.83-1.35-5.48-3.9-6.89-6.83l1.95-1.66c.27-.28.35-.67.24-1.02-.37-1.11-.56-2.3-.56-3.53 0-.54-.45-.99-.99-.99H4.19C3.65 3 3 3.24 3 3.99 3 13.28 10.73 21 20.01 21c.71 0 .99-.63.99-1.18v-3.45c0-.54-.45-.99-.99-.99z"/>
						</svg>
					</div>
				</div>

				<div class="call-phase-label incoming">Incoming Call</div>
				<div class="caller-info">
					<div class="caller-name">{peerName}</div>
					{#if peerNameAr}
						<div class="caller-name-ar">{peerNameAr}</div>
					{/if}
				</div>
				<div class="call-status">is calling you...</div>

				{#if micError}
					<div class="mic-error">⚠️ {micError}</div>
				{/if}

				<div class="call-actions">
					<button class="accept-btn" on:click={acceptCall} aria-label="Accept call">
						<svg width="28" height="28" viewBox="0 0 24 24" fill="white" stroke="none">
							<path d="M20.01 15.38c-1.23 0-2.42-.2-3.53-.56a.977.977 0 0 0-1.01.24l-1.57 1.97c-2.83-1.35-5.48-3.9-6.89-6.83l1.95-1.66c.27-.28.35-.67.24-1.02-.37-1.11-.56-2.3-.56-3.53 0-.54-.45-.99-.99-.99H4.19C3.65 3 3 3.24 3 3.99 3 13.28 10.73 21 20.01 21c.71 0 .99-.63.99-1.18v-3.45c0-.54-.45-.99-.99-.99z"/>
						</svg>
						<span>Accept</span>
					</button>
					<button class="decline-btn" on:click={declineCall} aria-label="Decline call">
						<svg width="28" height="28" viewBox="0 0 24 24" fill="white" stroke="none">
							<path d="M12 9c-1.6 0-3.15.25-4.6.72v3.1c0 .39-.23.74-.56.9-.98.49-1.87 1.12-2.66 1.85-.18.18-.43.28-.7.28-.28 0-.53-.11-.71-.29L.29 13.08c-.18-.17-.29-.42-.29-.7 0-.28.11-.53.29-.71C3.34 8.78 7.46 7 12 7s8.66 1.78 11.71 4.67c.18.18.29.43.29.71 0 .28-.11.53-.29.71l-2.48 2.48c-.18.18-.43.29-.71.29-.27 0-.52-.11-.7-.28-.79-.74-1.69-1.36-2.67-1.85-.33-.16-.56-.5-.56-.9v-3.1C15.15 9.25 13.6 9 12 9z"/>
						</svg>
						<span>Decline</span>
					</button>
				</div>

			{:else if phase === 'connecting'}
				<!-- ── CONNECTING: WebRTC handshake ── -->
				<div class="connecting-spinner"></div>
				<div class="call-phase-label">Connecting...</div>
				<div class="caller-info">
					<div class="caller-name">{peerName}</div>
					{#if peerNameAr}
						<div class="caller-name-ar">{peerNameAr}</div>
					{/if}
				</div>
				{#if micError}
					<div class="mic-error">⚠️ {micError}</div>
				{/if}

				<button class="end-call-btn" on:click={() => endCall(true)} aria-label="Cancel call">
					<span>Cancel</span>
				</button>

			{:else if phase === 'active'}
				<!-- ── ACTIVE: Voice connected ── -->
				<div class="call-icon-center connected">
					<svg width="48" height="48" viewBox="0 0 24 24" fill="white" stroke="none">
						<path d="M20.01 15.38c-1.23 0-2.42-.2-3.53-.56a.977.977 0 0 0-1.01.24l-1.57 1.97c-2.83-1.35-5.48-3.9-6.89-6.83l1.95-1.66c.27-.28.35-.67.24-1.02-.37-1.11-.56-2.3-.56-3.53 0-.54-.45-.99-.99-.99H4.19C3.65 3 3 3.24 3 3.99 3 13.28 10.73 21 20.01 21c.71 0 .99-.63.99-1.18v-3.45c0-.54-.45-.99-.99-.99z"/>
					</svg>
				</div>

				<div class="call-phase-label active-label">Connected</div>
				<div class="caller-info">
					<div class="caller-name">{peerName}</div>
					{#if peerNameAr}
						<div class="caller-name-ar">{peerNameAr}</div>
					{/if}
				</div>
				<div class="call-timer">{formatDuration(callDuration)}</div>

				<div class="call-actions">
					<button class="mute-btn" class:muted={isMuted} on:click={toggleMute} aria-label={isMuted ? 'Unmute' : 'Mute'}>
						{#if isMuted}
							<!-- Mic off icon -->
							<svg width="28" height="28" viewBox="0 0 24 24" fill="white" stroke="none">
								<path d="M19 11h-1.7c0 .74-.16 1.43-.43 2.05l1.23 1.23c.56-.98.9-2.09.9-3.28zm-4.02.17c0-.06.02-.11.02-.17V5c0-1.66-1.34-3-3-3S9 3.34 9 5v.18l5.98 5.99zM4.27 3L3 4.27l6.01 6.01V11c0 1.66 1.33 3 2.99 3 .22 0 .44-.03.65-.08l1.66 1.66c-.71.33-1.5.52-2.31.52-2.76 0-5.3-2.1-5.3-5.1H5c0 3.41 2.72 6.23 6 6.72V21h2v-3.28c.91-.13 1.77-.45 2.54-.9L19.73 21 21 19.73 4.27 3z"/>
							</svg>
						{:else}
							<!-- Mic on icon -->
							<svg width="28" height="28" viewBox="0 0 24 24" fill="white" stroke="none">
								<path d="M12 14c1.66 0 2.99-1.34 2.99-3L15 5c0-1.66-1.34-3-3-3S9 3.34 9 5v6c0 1.66 1.34 3 3 3zm5.3-3c0 3-2.54 5.1-5.3 5.1S6.7 14 6.7 11H5c0 3.41 2.72 6.23 6 6.72V21h2v-3.28c3.28-.48 6-3.3 6-6.72h-1.7z"/>
							</svg>
						{/if}
						<span>{isMuted ? 'Unmute' : 'Mute'}</span>
					</button>
					<button class="end-call-btn" on:click={() => endCall(true)} aria-label="End call">
						<svg width="28" height="28" viewBox="0 0 24 24" fill="white" stroke="none">
							<path d="M12 9c-1.6 0-3.15.25-4.6.72v3.1c0 .39-.23.74-.56.9-.98.49-1.87 1.12-2.66 1.85-.18.18-.43.28-.7.28-.28 0-.53-.11-.71-.29L.29 13.08c-.18-.17-.29-.42-.29-.7 0-.28.11-.53.29-.71C3.34 8.78 7.46 7 12 7s8.66 1.78 11.71 4.67c.18.18.29.43.29.71 0 .28-.11.53-.29.71l-2.48 2.48c-.18.18-.43.29-.71.29-.27 0-.52-.11-.7-.28-.79-.74-1.69-1.36-2.67-1.85-.33-.16-.56-.5-.56-.9v-3.1C15.15 9.25 13.6 9 12 9z"/>
						</svg>
						<span>End Call</span>
					</button>
				</div>
			{/if}

		</div>
	</div>
{/if}

<!-- ── TEXT MESSAGE OVERLAY ── -->
{#if showTextOverlay}
	<div class="text-overlay">
		<div class="text-card">
			<!-- Message icon -->
			<div class="text-icon-circle">
				<svg width="40" height="40" viewBox="0 0 24 24" fill="white" stroke="none">
					<path d="M20 2H4c-1.1 0-1.99.9-1.99 2L2 22l4-4h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm-2 12H6v-2h12v2zm0-3H6V9h12v2zm0-3H6V6h12v2z"/>
				</svg>
			</div>

			<div class="text-label">New Message</div>

			<div class="text-sender-info">
				<div class="text-sender-name">{textSenderName}</div>
				{#if textSenderNameAr}
					<div class="text-sender-name-ar">{textSenderNameAr}</div>
				{/if}
			</div>

			<div class="text-message-box">
				<p class="text-message-content">{textMessage}</p>
			</div>

			<button class="text-read-btn" on:click={dismissText} aria-label="Mark as read">
				<svg width="22" height="22" viewBox="0 0 24 24" fill="white" stroke="none">
					<path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"/>
				</svg>
				<span>Read</span>
			</button>
		</div>
	</div>
{/if}

<style>
	/* ── Overlay ── */
	.call-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.88);
		backdrop-filter: blur(14px);
		-webkit-backdrop-filter: blur(14px);
		z-index: 999999;
		display: flex;
		align-items: center;
		justify-content: center;
		animation: overlayFadeIn 0.3s ease-out;
	}

	@keyframes overlayFadeIn {
		from { opacity: 0; }
		to { opacity: 1; }
	}

	.call-card {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 20px;
		padding: 40px 60px;
		text-align: center;
	}

	/* ── Pulsing ring ── */
	.call-icon-ring {
		position: relative;
		width: 120px;
		height: 120px;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.call-icon-pulse {
		position: absolute;
		width: 100%;
		height: 100%;
		border-radius: 50%;
		background: rgba(34, 197, 94, 0.3);
		animation: pulseRing 2s ease-out infinite;
	}

	.call-icon-pulse.delay {
		animation-delay: 0.5s;
	}

	@keyframes pulseRing {
		0% { transform: scale(0.8); opacity: 1; }
		100% { transform: scale(1.8); opacity: 0; }
	}

	/* ── Phone icon circle ── */
	.call-icon-center {
		width: 90px;
		height: 90px;
		border-radius: 50%;
		background: linear-gradient(135deg, #22c55e 0%, #16a34a 100%);
		display: flex;
		align-items: center;
		justify-content: center;
		box-shadow: 0 8px 32px rgba(34, 197, 94, 0.4);
		z-index: 1;
	}

	.call-icon-center.shaking {
		animation: phoneShake 0.5s ease-in-out infinite;
	}

	.call-icon-center.connected {
		background: linear-gradient(135deg, #22c55e 0%, #16a34a 100%);
		box-shadow: 0 8px 32px rgba(34, 197, 94, 0.5);
		animation: connectedPulse 2s ease-in-out infinite;
	}

	@keyframes phoneShake {
		0%, 100% { transform: rotate(0deg); }
		10% { transform: rotate(-8deg); }
		20% { transform: rotate(8deg); }
		30% { transform: rotate(-6deg); }
		40% { transform: rotate(6deg); }
		50% { transform: rotate(0deg); }
	}

	@keyframes connectedPulse {
		0%, 100% { box-shadow: 0 8px 32px rgba(34, 197, 94, 0.4); }
		50% { box-shadow: 0 8px 48px rgba(34, 197, 94, 0.6); }
	}

	/* ── Labels ── */
	.call-phase-label {
		color: #22c55e;
		font-size: 0.9rem;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 3px;
	}

	.call-phase-label.incoming {
		color: #22c55e;
		animation: labelPulse 1.5s ease-in-out infinite;
	}

	.call-phase-label.active-label {
		color: #4ade80;
	}

	@keyframes labelPulse {
		0%, 100% { opacity: 1; }
		50% { opacity: 0.5; }
	}

	.caller-info {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 6px;
	}

	.caller-name {
		color: white;
		font-size: 2rem;
		font-weight: 700;
		letter-spacing: -0.5px;
	}

	.caller-name-ar {
		color: rgba(255, 255, 255, 0.7);
		font-size: 1.3rem;
		direction: rtl;
	}

	.call-status {
		color: rgba(255, 255, 255, 0.5);
		font-size: 1rem;
	}

	.call-timer {
		color: #4ade80;
		font-size: 2.5rem;
		font-weight: 300;
		font-family: 'Courier New', monospace;
		letter-spacing: 4px;
	}

	.mic-error {
		color: #fbbf24;
		font-size: 0.9rem;
		padding: 8px 16px;
		background: rgba(251, 191, 36, 0.1);
		border-radius: 8px;
	}

	/* ── Buttons ── */
	.call-actions {
		display: flex;
		gap: 30px;
		margin-top: 20px;
	}

	.accept-btn {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 8px;
		padding: 20px;
		background: linear-gradient(135deg, #22c55e 0%, #16a34a 100%);
		color: white;
		border: none;
		border-radius: 50%;
		width: 80px;
		height: 80px;
		cursor: pointer;
		transition: all 0.2s;
		box-shadow: 0 6px 24px rgba(34, 197, 94, 0.5);
		animation: acceptPulse 1.5s ease-in-out infinite;
	}

	.accept-btn span {
		position: absolute;
		bottom: -28px;
		font-size: 0.85rem;
		font-weight: 600;
		white-space: nowrap;
	}

	.accept-btn {
		position: relative;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	@keyframes acceptPulse {
		0%, 100% { box-shadow: 0 6px 24px rgba(34, 197, 94, 0.5); }
		50% { box-shadow: 0 6px 40px rgba(34, 197, 94, 0.7); transform: scale(1.05); }
	}

	.accept-btn:hover {
		transform: scale(1.1);
		box-shadow: 0 8px 32px rgba(34, 197, 94, 0.6);
	}

	.accept-btn:active { transform: scale(0.95); }

	.decline-btn {
		position: relative;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 20px;
		background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%);
		color: white;
		border: none;
		border-radius: 50%;
		width: 80px;
		height: 80px;
		cursor: pointer;
		transition: all 0.2s;
		box-shadow: 0 6px 24px rgba(239, 68, 68, 0.4);
	}

	.decline-btn span {
		position: absolute;
		bottom: -28px;
		font-size: 0.85rem;
		font-weight: 600;
		white-space: nowrap;
	}

	.decline-btn:hover {
		transform: scale(1.1);
		box-shadow: 0 8px 32px rgba(239, 68, 68, 0.6);
	}

	.decline-btn:active { transform: scale(0.95); }

	.end-call-btn {
		margin-top: 20px;
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 14px 40px;
		background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%);
		color: white;
		border: none;
		border-radius: 50px;
		font-size: 1rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
		box-shadow: 0 6px 20px rgba(239, 68, 68, 0.4);
	}

	.end-call-btn:hover {
		background: linear-gradient(135deg, #dc2626 0%, #b91c1c 100%);
		transform: scale(1.05);
		box-shadow: 0 8px 28px rgba(239, 68, 68, 0.5);
	}

	.end-call-btn:active { transform: scale(0.98); }

	.mute-btn {
		position: relative;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 20px;
		background: rgba(255, 255, 255, 0.15);
		color: white;
		border: 2px solid rgba(255, 255, 255, 0.3);
		border-radius: 50%;
		width: 70px;
		height: 70px;
		cursor: pointer;
		transition: all 0.2s;
	}

	.mute-btn span {
		position: absolute;
		bottom: -28px;
		font-size: 0.85rem;
		font-weight: 600;
		white-space: nowrap;
	}

	.mute-btn:hover {
		background: rgba(255, 255, 255, 0.25);
		transform: scale(1.05);
	}

	.mute-btn.muted {
		background: rgba(239, 68, 68, 0.3);
		border-color: rgba(239, 68, 68, 0.6);
	}

	.mute-btn:active { transform: scale(0.95); }

	/* ── Connecting spinner ── */
	.connecting-spinner {
		width: 80px;
		height: 80px;
		border: 4px solid rgba(34, 197, 94, 0.2);
		border-top-color: #22c55e;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	/* ── Mobile responsive ── */
	@media (max-width: 640px) {
		.call-card {
			padding: 30px 20px;
		}

		.caller-name {
			font-size: 1.5rem;
		}

		.caller-name-ar {
			font-size: 1.1rem;
		}

		.call-timer {
			font-size: 2rem;
		}

		.call-icon-ring {
			width: 100px;
			height: 100px;
		}

		.call-icon-center {
			width: 75px;
			height: 75px;
		}

		.call-icon-center svg {
			width: 36px;
			height: 36px;
		}

		.accept-btn, .decline-btn {
			width: 70px;
			height: 70px;
		}

		.mute-btn {
			width: 60px;
			height: 60px;
		}

		.call-actions {
			gap: 24px;
		}
	}

	/* ══════════════════════════════════════ */
	/*           TEXT MESSAGE OVERLAY         */
	/* ══════════════════════════════════════ */

	.text-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.9);
		backdrop-filter: blur(16px);
		-webkit-backdrop-filter: blur(16px);
		z-index: 999999;
		display: flex;
		align-items: center;
		justify-content: center;
		animation: overlayFadeIn 0.3s ease-out;
	}

	.text-card {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 20px;
		padding: 40px 50px;
		text-align: center;
		max-width: 480px;
		width: 90%;
	}

	.text-icon-circle {
		width: 80px;
		height: 80px;
		border-radius: 50%;
		background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
		display: flex;
		align-items: center;
		justify-content: center;
		box-shadow: 0 8px 32px rgba(59, 130, 246, 0.4);
		animation: textPulse 2s ease-in-out infinite;
	}

	@keyframes textPulse {
		0%, 100% { box-shadow: 0 8px 32px rgba(59, 130, 246, 0.4); }
		50% { box-shadow: 0 8px 48px rgba(59, 130, 246, 0.6); }
	}

	.text-label {
		color: #60a5fa;
		font-size: 0.85rem;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 3px;
	}

	.text-sender-info {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 4px;
	}

	.text-sender-name {
		color: white;
		font-size: 1.6rem;
		font-weight: 700;
		letter-spacing: -0.5px;
	}

	.text-sender-name-ar {
		color: rgba(255, 255, 255, 0.6);
		font-size: 1.1rem;
		direction: rtl;
	}

	.text-message-box {
		background: rgba(255, 255, 255, 0.08);
		border: 1px solid rgba(255, 255, 255, 0.15);
		border-radius: 16px;
		padding: 24px 28px;
		width: 100%;
		max-height: 200px;
		overflow-y: auto;
	}

	.text-message-content {
		color: white;
		font-size: 1.15rem;
		line-height: 1.6;
		word-wrap: break-word;
		white-space: pre-wrap;
		margin: 0;
	}

	.text-read-btn {
		margin-top: 16px;
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 14px 50px;
		background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
		color: white;
		border: none;
		border-radius: 50px;
		font-size: 1.05rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
		box-shadow: 0 6px 20px rgba(59, 130, 246, 0.4);
	}

	.text-read-btn:hover {
		background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%);
		transform: scale(1.05);
		box-shadow: 0 8px 28px rgba(59, 130, 246, 0.5);
	}

	.text-read-btn:active {
		transform: scale(0.98);
	}

	@media (max-width: 640px) {
		.text-card {
			padding: 30px 20px;
		}

		.text-sender-name {
			font-size: 1.3rem;
		}

		.text-message-content {
			font-size: 1rem;
		}

		.text-icon-circle {
			width: 65px;
			height: 65px;
		}

		.text-icon-circle svg {
			width: 32px;
			height: 32px;
		}
	}
</style>
