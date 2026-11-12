import { createCounterProductsHandler } from '$lib/server/businessCounterProducts';
import { COFFEE_COUNTER } from '$lib/types/businessCounter';

export const GET = createCounterProductsHandler(COFFEE_COUNTER);
