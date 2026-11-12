export interface CoffeeOtherPayment {
	id: string;
	amount: number;
	narration: string;
	paymentDate: string;
	createdAt: string;
	updatedAt: string;
	version: number;
}

export interface CoffeeOtherPaymentsResponse {
	success: boolean;
	asOfDate: string;
	total: number;
	payments?: CoffeeOtherPayment[];
}
