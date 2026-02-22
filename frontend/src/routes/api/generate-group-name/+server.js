import { json } from "@sveltejs/kit";

const SUPABASE_URL = process.env.VITE_SUPABASE_URL || '';
const SUPABASE_ANON_KEY = process.env.VITE_SUPABASE_ANON_KEY || '';

async function getGeminiKey() {
  try {
    const res = await fetch(
      `${SUPABASE_URL}/rest/v1/system_api_keys?service_name=eq.google&is_active=eq.true&select=api_key&limit=1`,
      { headers: { apikey: SUPABASE_ANON_KEY, Authorization: `Bearer ${SUPABASE_ANON_KEY}` } }
    );
    const rows = await res.json();
    return rows?.[0]?.api_key || null;
  } catch {
    return null;
  }
}

export async function POST({ request }) {
  try {
    console.log("Generate Group Name API accessed...");

    const GEMINI_KEY = await getGeminiKey();
    if (!GEMINI_KEY) {
      return json(
        { error: "Google AI API key not configured. Set it in API Keys Manager." },
        { status: 500 }
      );
    }

    const body = await request.json();
    console.log("Request body received:", JSON.stringify(body, null, 2));

    const { productNames = [] } = body;

    if (!productNames || productNames.length === 0) {
      return json({ error: "No product names provided" }, { status: 400 });
    }

    const productList = productNames.join('\n- ');

    const prompt = `You are a product naming expert for a supermarket/grocery store. Analyze the following product names and create a descriptive group name.

Product names:
- ${productList}

Rules:
1. Find the COMMON product name across all items (e.g., "Tang Drink Powder")
2. Find the COMMON size/weight if present (e.g., "2KG", "500ml", "1L")
3. If products have different flavors/variants (like Mango, Lemon, etc.), add "Assorted" at the end
4. Format: "[Common Product Name] [Size] Assorted" when there are variants
5. Example: If products are "Tang Powder Mango 2KG", "Tang Powder Lemon 2KG" -> "Tang Drink Powder 2KG Assorted"
6. Keep it concise but include size and "Assorted" when applicable
7. Return ONLY a JSON object with "nameEn" (English) and "nameAr" (Arabic) fields
8. For Arabic translation, use these EXACT unit translations:
   - KG, Kg, kg → كيلو (not كجم)
   - gm, GRM, gram, g → جرام
   - ml, ML → مل
   - L, Liter → لتر
   - PCS, pcs → حبة
9. Use "متنوع" for "Assorted" in Arabic
10. Do NOT include any explanations, just the JSON object

Example outputs:
{"nameEn": "Tang Drink Powder 2KG Assorted", "nameAr": "مسحوق تانج 2 كيلو متنوع"}
{"nameEn": "Cookies 500gm Assorted", "nameAr": "بسكويت 500 جرام متنوع"}
{"nameEn": "Coca Cola 330ml Assorted", "nameAr": "كوكا كولا 330 مل متنوع"}

Your response (JSON only):`;

    console.log("Sending prompt to Gemini...");

    const geminiRes = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${GEMINI_KEY}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: "You are a product naming assistant. Always respond with valid JSON only, no explanations." }] },
          contents: [{ role: 'user', parts: [{ text: prompt }] }],
          generationConfig: { temperature: 0.3, maxOutputTokens: 200 }
        })
      }
    );

    if (!geminiRes.ok) {
      const errText = await geminiRes.text();
      throw new Error(`Gemini API error ${geminiRes.status}: ${errText}`);
    }

    const geminiData = await geminiRes.json();
    const responseText = geminiData.candidates?.[0]?.content?.parts?.[0]?.text?.trim();
    console.log("Gemini response:", responseText);

    if (!responseText) {
      return json({ error: "No response from AI" }, { status: 500 });
    }

    // Parse the JSON response
    try {
      // Clean up the response in case it has markdown code blocks
      let cleanedResponse = responseText;
      if (cleanedResponse.startsWith('```')) {
        cleanedResponse = cleanedResponse.replace(/```json?\n?/g, '').replace(/```/g, '').trim();
      }
      
      const result = JSON.parse(cleanedResponse);
      
      return json({
        success: true,
        nameEn: result.nameEn || "Assorted Products",
        nameAr: result.nameAr || "منتجات متنوعة"
      });
    } catch (parseError) {
      console.error("Failed to parse AI response:", parseError);
      // Fallback: try to extract from the text
      return json({
        success: true,
        nameEn: "Assorted Products",
        nameAr: "منتجات متنوعة"
      });
    }

  } catch (error) {
    console.error("Error generating group name:", error);
    return json(
      {
        error: error.message || "Failed to generate group name",
      },
      { status: 500 }
    );
  }
}
