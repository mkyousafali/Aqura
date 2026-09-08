const sharp = require('sharp');
const path = require('path');
const fs = require('fs');

const sourceImage = path.join(__dirname, '../frontend/static/icons/Aqura logo.png');
const outputDir = path.join(__dirname, '../frontend/static/icons');

const sizes = [72, 96, 128, 144, 152, 192, 384, 512];

async function generateIcons() {
    console.log('🎨 Generating PWA icons with rounded corners...\n');

    for (const size of sizes) {
        const outputPath = path.join(outputDir, `icon-${size}x${size}.png`);
        const radius = Math.round(size * 0.22); // 22% radius for visible rounding
        
        // Create rounded corners mask with proper SVG namespace
        const roundedMask = Buffer.from(
            `<svg width="${size}" height="${size}" xmlns="http://www.w3.org/2000/svg">
              <rect x="0" y="0" width="${size}" height="${size}" rx="${radius}" ry="${radius}" fill="white"/>
            </svg>`
        );

        try {
            // First resize with transparent background
            const resized = await sharp(sourceImage)
                .resize(size, size, {
                    fit: 'cover',
                    background: { r: 0, g: 0, b: 0, alpha: 0 }
                })
                .ensureAlpha()
                .toBuffer();
            
            // Apply rounded mask
            await sharp(resized)
                .composite([{
                    input: roundedMask,
                    blend: 'dest-in'
                }])
                .png({ compressionLevel: 9 })
                .toFile(outputPath);

            console.log(`✅ Generated: icon-${size}x${size}.png`);
        } catch (error) {
            console.error(`❌ Error generating ${size}x${size}:`, error.message);
        }
    }

    // Also create favicon with rounded corners
    const faviconPath = path.join(outputDir, '../favicon.png');
    const faviconSize = 32;
    const faviconRadius = Math.round(faviconSize * 0.22);
    const faviconMask = Buffer.from(
        `<svg width="${faviconSize}" height="${faviconSize}" xmlns="http://www.w3.org/2000/svg">
          <rect x="0" y="0" width="${faviconSize}" height="${faviconSize}" rx="${faviconRadius}" ry="${faviconRadius}" fill="white"/>
        </svg>`
    );
    
    try {
        const resizedFavicon = await sharp(sourceImage)
            .resize(faviconSize, faviconSize, {
                fit: 'cover',
                background: { r: 0, g: 0, b: 0, alpha: 0 }
            })
            .ensureAlpha()
            .toBuffer();
        
        await sharp(resizedFavicon)
            .composite([{
                input: faviconMask,
                blend: 'dest-in'
            }])
            .png({ compressionLevel: 9 })
            .toFile(faviconPath);
        console.log(`✅ Generated: favicon.png`);
    } catch (error) {
        console.error(`❌ Error generating favicon:`, error.message);
    }

    console.log('\n🎉 PWA icons generated successfully!');
}

generateIcons();
