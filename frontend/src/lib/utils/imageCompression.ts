/**
 * Compress an image file or base64 data URL by resizing and reducing JPEG quality.
 * Reduces typical phone photos (5-10MB) to ~100-300KB with no visible quality loss.
 * 
 * @param input - File object or base64 data URL string
 * @param maxWidth - Maximum width in pixels (default: 1280)
 * @param maxHeight - Maximum height in pixels (default: 960)
 * @param quality - JPEG quality 0-1 (default: 0.6)
 * @returns Promise<string> - Compressed base64 data URL
 */
export function compressImage(
	input: File | string,
	maxWidth = 1280,
	maxHeight = 960,
	quality = 0.6
): Promise<string> {
	return new Promise((resolve, reject) => {
		const img = new Image();

		img.onload = () => {
			try {
				let { width, height } = img;

				// Scale down if larger than max dimensions
				if (width > maxWidth || height > maxHeight) {
					const ratio = Math.min(maxWidth / width, maxHeight / height);
					width = Math.round(width * ratio);
					height = Math.round(height * ratio);
				}

				const canvas = document.createElement('canvas');
				canvas.width = width;
				canvas.height = height;

				const ctx = canvas.getContext('2d');
				if (!ctx) {
					reject(new Error('Failed to get canvas context'));
					return;
				}

				ctx.drawImage(img, 0, 0, width, height);
				const compressed = canvas.toDataURL('image/jpeg', quality);
				resolve(compressed);
			} catch (err) {
				reject(err);
			}
		};

		img.onerror = () => reject(new Error('Failed to load image'));

		if (typeof input === 'string') {
			// Already a data URL
			img.src = input;
		} else {
			// File object — read as data URL first
			const reader = new FileReader();
			reader.onload = (e) => {
				img.src = e.target?.result as string;
			};
			reader.onerror = () => reject(new Error('Failed to read file'));
			reader.readAsDataURL(input);
		}
	});
}
/**
 * Compress an image File and return a new compressed File object.
 * Useful when you need to upload the compressed result to storage.
 * 
 * @param file - File object to compress
 * @param maxWidth - Maximum width in pixels (default: 1280)
 * @param maxHeight - Maximum height in pixels (default: 960)
 * @param quality - JPEG quality 0-1 (default: 0.6)
 * @returns Promise<File> - Compressed File object
 */
export async function compressImageToFile(
	file: File,
	maxWidth = 1280,
	maxHeight = 960,
	quality = 0.6
): Promise<File> {
	const dataUrl = await compressImage(file, maxWidth, maxHeight, quality);
	const res = await fetch(dataUrl);
	const blob = await res.blob();
	const ext = file.name.split('.').pop()?.toLowerCase();
	const compressedName = file.name.replace(/\.[^.]+$/, '.jpg');
	return new File([blob], compressedName, { type: 'image/jpeg' });
}