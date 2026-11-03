import { isHttpError, redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';
import { requireDirectOrderAccess } from '$lib/server/directOrderAccess';

export const load: PageServerLoad = async ({ cookies }) => {
	try {
		await requireDirectOrderAccess(cookies, 'mobile');
	} catch (failure) {
		if (isHttpError(failure) && [401, 403].includes(failure.status)) redirect(303, '/mobile-interface');
		throw failure;
	}
	return {};
};
