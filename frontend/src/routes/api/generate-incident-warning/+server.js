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

// Language name mapping
const languageNames = {
  ar: { name: 'Arabic', nativeName: 'العربية' },
  en: { name: 'English', nativeName: 'English' },
  ml: { name: 'Malayalam', nativeName: 'മലയാളം' },
  bn: { name: 'Bengali', nativeName: 'বাংলা' },
  hi: { name: 'Hindi', nativeName: 'हिंदी' },
  ur: { name: 'Urdu', nativeName: 'اردو' },
  ta: { name: 'Tamil', nativeName: 'தமிழ்' }
};

// Recourse type descriptions
const recourseDescriptions = {
  warning: {
    en: 'This is a formal warning',
    ar: 'هذا تحذير رسمي',
    hasFine: false,
    hasFineThreat: false,
    hasTerminationThreat: false,
    isTermination: false
  },
  warning_fine: {
    en: 'This is a formal warning with a monetary fine (deducted from salary)',
    ar: 'هذا تحذير رسمي مع غرامة مالية (تخصم من الراتب)',
    hasFine: true,
    hasFineThreat: false,
    hasTerminationThreat: false,
    isTermination: false
  },
  warning_fine_threat: {
    en: 'This is a formal warning with a fine threat if repeated',
    ar: 'هذا تحذير رسمي مع تهديد بغرامة في حال التكرار',
    hasFine: false,
    hasFineThreat: true,
    hasTerminationThreat: false,
    isTermination: false
  },
  warning_fine_termination_threat: {
    en: 'This is a formal warning with a fine and termination threat',
    ar: 'هذا تحذير رسمي مع غرامة وتهديد بإنهاء الخدمة',
    hasFine: true,
    hasFineThreat: false,
    hasTerminationThreat: true,
    isTermination: false
  },
  termination: {
    en: 'This is a termination notice',
    ar: 'هذا إشعار إنهاء خدمة',
    hasFine: false,
    hasFineThreat: false,
    hasTerminationThreat: false,
    isTermination: true
  }
};

export async function POST({ request }) {
  try {
    console.log("Generate Incident Warning API accessed...");

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

    const {
      languages = ['en'],
      recourseType = 'warning',
      fineAmount = null,
      whatHappened = '',
      witnessDetails = '',
      investigationReport = '',
      violationName = '',
      violationNameAr = '',
      employeeName = '',
      employeeNameAr = '',
      branchName = ''
    } = body;

    // Build the language instruction
    const languageList = languages.map(lang => languageNames[lang]?.name || lang).join(', ');
    
    // Build recourse description
    const recourseDesc = recourseDescriptions[recourseType] || recourseDescriptions.warning;
    
    // Build fine information
    let fineInfo = '';
    if (fineAmount && (recourseType === 'warning_fine' || recourseType === 'warning_fine_threat' || recourseType === 'warning_fine_termination_threat')) {
      fineInfo = `\n- Fine Amount: ${fineAmount} SAR`;
    }

    // Build consequence instruction based on recourse type
    let consequenceInstruction = '';
    let acknowledgementInstruction = 'DO NOT include any acknowledgement, signature section, or receipt section.';
    
    if (recourseType === 'warning') {
      // Simple warning - no fine
      consequenceInstruction = `5. State that repeating such violations may lead to legal disciplinary actions as per Saudi Labor Law
6. Ask employee to take this seriously and comply with company procedures`;
    } else if (recourseType === 'warning_fine' && fineAmount) {
      // Warning with fine - fine deducted NOW from salary
      consequenceInstruction = `5. State that the fine amount of ${fineAmount} SAR will be deducted from the employee's current month salary
6. State that repeating such violations may lead to further legal disciplinary actions as per Saudi Labor Law
7. Ask employee to take this seriously and comply with company procedures`;
    } else if (recourseType === 'warning_fine_threat') {
      // Warning with fine threat - NO fine now, but warn about FUTURE automatic fine if repeated
      consequenceInstruction = `5. State that NO fine is being applied at this time, but this is a serious warning
6. State that if this same violation is repeated in the future, an automatic fine of ${fineAmount || 'the specified amount'} SAR will be deducted from salary
7. Ask employee to take this seriously and comply with company procedures`;
    } else if (recourseType === 'warning_fine_termination_threat' && fineAmount) {
      // Warning with fine + termination threat - fine deducted NOW and warn about termination
      consequenceInstruction = `5. State that the fine amount of ${fineAmount} SAR will be deducted from the employee's current month salary
6. Warn that if this violation is repeated, it may result in termination of employment as per Saudi Labor Law
7. Ask employee to take this matter very seriously and strictly comply with company procedures`;
    } else if (recourseType === 'termination') {
      // Termination - formal termination notice
      consequenceInstruction = `5. State that due to the severity of this violation and/or repeated offenses, the decision has been made to terminate employment
6. State the effective date of termination (use "effective immediately" or "as per Saudi Labor Law notice period")
7. Reference the applicable Saudi Labor Law article that justifies termination
8. State any final settlement information (final salary, end of service benefits will be calculated as per law)`;
    } else {
      // Fallback - simple warning
      consequenceInstruction = `5. State that repeating such violations may lead to legal disciplinary actions as per Saudi Labor Law
6. Ask employee to take this seriously and comply with company procedures`;
    }

    // Create the prompt
    const prompt = `You are an HR professional writing a formal incident warning letter/report. Generate a professional warning document based on the following information:

**Incident Details:**
- Violation Type: ${violationName}${violationNameAr ? ` / ${violationNameAr}` : ''}
- Employee Name (English): ${employeeName}
${employeeNameAr ? `- Employee Name (Arabic): ${employeeNameAr}` : ''}
- Branch/Location: ${branchName || 'Not specified'}
- What Happened: ${whatHappened}
${witnessDetails ? `- Witness Details: ${witnessDetails}` : ''}
${investigationReport ? `
**Investigation Report:**
${investigationReport}
` : ''}
**CRITICAL - DO NOT TRANSLATE NAMES:**
- Use the EXACT employee name as provided: "${employeeName}"${employeeNameAr ? ` or "${employeeNameAr}"` : ''} - DO NOT translate names
- Use the EXACT branch/location name as provided: "${branchName}" - DO NOT translate branch names
- Names of people, places, and branches must be used EXACTLY as given, not translated

**Warning Type:**
- ${recourseDesc.en}${fineInfo}

**Languages Required:** ${languageList}
**Number of Languages Selected:** ${languages.length}

**CRITICAL FORMAT INSTRUCTIONS:**
${languages.length === 1 ? `Generate the warning in ${languageList} ONLY. Do NOT include any other language. Write the entire document in ${languageList} only.` : `Generate the warning in a MULTILINGUAL format using ONLY these languages: ${languageList}

Each sentence must be immediately followed by its translation in the other selected language(s).

Example format for ${languageList}:
---
[Sentence in ${languageNames[languages[0]]?.name || languages[0]}]
[Same sentence in ${languageNames[languages[1]]?.name || languages[1]}]${languages[2] ? `\n[Same sentence in ${languageNames[languages[2]]?.name || languages[2]}]` : ''}

[Next sentence in ${languageNames[languages[0]]?.name || languages[0]}]
[Same sentence in ${languageNames[languages[1]]?.name || languages[1]}]${languages[2] ? `\n[Same sentence in ${languageNames[languages[2]]?.name || languages[2]}]` : ''}
---

DO NOT use Arabic unless Arabic was selected. DO NOT use English unless English was selected.
ONLY use these exact languages: ${languageList}`}

**SAUDI LABOR LAW & ESTABLISHMENT POLICIES REFERENCE:**
You MUST reference BOTH:
1. The relevant Saudi Labor Law article number that applies to this type of violation
2. The establishment/company policies and regulations

Common Saudi Labor Law articles include:
- Article 80: Grounds for termination without notice or compensation
- Article 66: Working hours violations
- Article 74: End of employment relationship
- Article 75: Notice period
- Article 80(2): Assault on employer/colleagues
- Article 80(3): Failure to perform duties
- Article 80(4): Serious misconduct
- Article 80(6): Absence without valid reason
- Article 80(7): Disclosure of confidential information
- Article 80(8): Forgery
- Article 80(9): Probation period violations
- Article 117: Safety violations
- Article 146: Occupational injury

Include a statement referencing both the establishment's internal policies and the applicable Saudi Labor Law article.

**Content Requirements:**
1. Start DIRECTLY with "Dear [Employee Name]," - NO letterhead, NO date, NO address header
2. State this is a formal warning for the violation
3. Describe what happened (reference the incident details)
4. CITE THE RELEVANT SAUDI LABOR LAW ARTICLE NUMBER with brief explanation of why it applies
5. State the consequence/action being taken (warning${fineAmount ? `, with a fine of ${fineAmount} SAR` : ''})
${consequenceInstruction}

${acknowledgementInstruction}

**DO NOT INCLUDE:**
- Company letterhead
- Date
- Employee address or branch address at the top
- Signature section (Sincerely, HR Department, Company Name, Contact Information)
- Any closing signatures
- Acknowledgment of Receipt section
- Employee Name/Signature/Date blanks

Just start with "Dear [Name]," and end after the final statement. Keep it simple and direct.

**FINAL LANGUAGE REMINDER - THIS IS CRITICAL:**
The ONLY languages you are allowed to use are: ${languageList}
- If Arabic is NOT in that list, DO NOT write ANY Arabic text
- If English is NOT in that list, DO NOT write ANY English text
- ONLY use: ${languageList}

Keep the content professional, formal, and concise. Generate now:`;

    console.log("Sending prompt to OpenAI...");

    const completion = await openai.chat.completions.create({
      model: "gpt-4o-mini",
      messages: [
        {
          role: "system",
          content: `You are an expert HR professional specializing in employee relations and formal documentation. You write clear, professional, and legally appropriate warning letters. 

CRITICAL LANGUAGE RULES:
1. You MUST ONLY use the languages specified by the user
2. If Arabic is not in the list of required languages, DO NOT write anything in Arabic
3. If English is not in the list, DO NOT write in English
4. DO NOT mix scripts from different languages - for example:
   - Malayalam uses only മലയാളം script (not Hindi देवनागरी)
   - Bengali uses only বাংলা script
   - Hindi uses only हिंदी देवनागरी script
   - Tamil uses only தமிழ் script
   - Urdu uses only اردو script
5. Strictly follow the language requirements and use the correct script for each language`
        },
        {
          role: "user",
          content: prompt
        }
      ],
      temperature: 0.7,
      max_tokens: 2000
    });

    const generatedText = completion.choices[0]?.message?.content || '';
    
    console.log("Generated text length:", generatedText.length);

    return json({
      success: true,
      generatedText: generatedText
    });

  } catch (error) {
    console.error("Error generating incident warning:", error);
    return json(
      {
        error: error instanceof Error ? error.message : "Failed to generate warning",
      },
      { status: 500 }
    );
  }
}
