import { createCounterSalesHandler } from '$lib/server/businessCounterSales';
import { COFFEE_COUNTER } from '$lib/types/businessCounter';

export const GET = createCounterSalesHandler(COFFEE_COUNTER);
