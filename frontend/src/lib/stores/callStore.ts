import { writable } from 'svelte/store';

export interface OutgoingCallRequest {
	targetUserId: string;
	targetName: string;
	targetNameAr: string;
	callerName: string;
	callerNameAr: string;
}

export interface OutgoingTextRequest {
	targetUserId: string;
	targetName: string;
	targetNameAr: string;
	senderName: string;
	senderNameAr: string;
	message: string;
}

export const outgoingCallRequest = writable<OutgoingCallRequest | null>(null);
export const outgoingTextRequest = writable<OutgoingTextRequest | null>(null);

export function initiateCall(info: OutgoingCallRequest) {
	outgoingCallRequest.set(info);
}

export function sendTextMessage(info: OutgoingTextRequest) {
	outgoingTextRequest.set(info);
}
