import { createCounterProductsHandler } from '$lib/server/businessCounterProducts';
import { BAKERY_COUNTER } from '$lib/types/businessCounter';

export const GET = createCounterProductsHandler(BAKERY_COUNTER);
