const { Client } = require('pg');

const client = new Client({
    connectionString: 'postgresql://postgres:%40%23Imanihayath120@db.vmypotfsyrvuublyddyt.supabase.co:5432/postgres'
});

async function addTestImage() {
    try {
        await client.connect();
        console.log('Connected to database');

        const taskId = '27023c12-14c4-4715-9087-6930b5ff7dbc';
        const testImageUrl = 'https://via.placeholder.com/150/0000FF/FFFFFF?text=Test+Image';
        
        const query = `
            INSERT INTO task_images (
                id, task_id, file_name, file_size, file_type, 
                file_url, image_type, uploaded_by, uploaded_by_name, 
                created_at, image_width, image_height
            ) VALUES (
                gen_random_uuid(), $1, $2, $3, $4, $5, $6, $7, $8, NOW(), $9, $10
            )
        `;
        
        const values = [
            taskId, 
            'test-image.jpg', 
            12345, 
            'image/jpeg', 
            testImageUrl, 
            'task_image', 
            'e1fdaee2-97f0-4fc1-872f-9d99c6bd684b', 
            'Test User', 
            150, 
            150
        ];

        await client.query(query, values);
        console.log('✅ Test image added successfully!');

        // Verify the insertion
        const verifyQuery = 'SELECT * FROM task_images WHERE task_id = $1';
        const result = await client.query(verifyQuery, [taskId]);
        console.log('📷 Image records for task:');
        console.table(result.rows);

    } catch (error) {
        console.error('❌ Error:', error.message);
    } finally {
        await client.end();
        console.log('Database connection closed');
    }
}

addTestImage();