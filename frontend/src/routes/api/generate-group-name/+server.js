import { json } from "@sveltejs/kit";
import { env } from "$env/dynamic/private";

// Function to create OpenAI client with error handling
function createOpenAIClient() {
  try {
    const apiKey =
      env.OPENAI_API_KEY ||
      env.VITE_OPENAI_API_KEY ||
      process.env.OPENAI_API_KEY ||
      process.env.VITE_OPENAI_API_KEY;

    if (!apiKey) {
      console.warn("No OpenAI API key found in environment variables");
      return null;
    }

    // Dynamic import to avoid initialization errors during build
    return import("openai").then(({ default: OpenAI }) => {
      return new OpenAI({ apiKey });
    });
  } catch (error) {
    console.error("Failed to create OpenAI client:", error);
    return null;
  }
}

export async function POST({ request }) {
  try {
    console.log("Generate Group Name API accessed...");

    // Create OpenAI client
    const openaiClientPromise = createOpenAIClient();
    if (!openaiClientPromise) {
      console.error("Failed to create OpenAI client");
      return json(
        {
          error: "OpenAI API key not configured. Please check server environment variables.",
        },
        { status: 500 }
      );
    }

    const openai = await openaiClientPromise;
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

    console.log("Sending prompt to OpenAI...");

    const completion = await openai.chat.completions.create({
      model: "gpt-4o-mini",
      messages: [
        {
          role: "system",
          content: "You are a product naming assistant. Always respond with valid JSON only, no explanations."
        },
        {
          role: "user",
          content: prompt
        }
      ],
      temperature: 0.3,
      max_tokens: 100,
    });

    const responseText = completion.choices[0]?.message?.content?.trim();
    console.log("OpenAI response:", responseText);

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
