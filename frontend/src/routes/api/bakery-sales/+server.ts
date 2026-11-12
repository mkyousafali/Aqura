import { createCounterSalesHandler } from '$lib/server/businessCounterSales';
import { BAKERY_COUNTER } from '$lib/types/businessCounter';

export const GET = createCounterSalesHandler(BAKERY_COUNTER);
