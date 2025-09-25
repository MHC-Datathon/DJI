import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ request }) => {
	const userAgent = request.headers.get('user-agent') ?? '';
	const isFirefox = /\bfirefox\b/i.test(userAgent);

	return {
		isFirefox
	};
};
