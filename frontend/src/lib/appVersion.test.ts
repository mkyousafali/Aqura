import { expect, it } from 'vitest';
import { version } from '../../package.json';
import {
	appVersion, versionNumber, desktopVersion, mobileVersion, cashierVersion, customerVersion
} from './appVersion';

it('uses one V-AQ version for every interface and the package', () => {
	expect(appVersion).toBe(`V-AQ${versionNumber}`);
	expect([desktopVersion, mobileVersion, cashierVersion, customerVersion, version])
		.toEqual(Array(5).fill(appVersion));
});
