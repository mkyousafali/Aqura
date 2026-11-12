import type { BakeryBranch } from './bakery';

export interface CoffeeBranchStockValue {
	branch: BakeryBranch;
	value: number | null;
	missingCostBatches: number;
	missingQuantityBatches: number;
	negativeStockBatches: number;
}
