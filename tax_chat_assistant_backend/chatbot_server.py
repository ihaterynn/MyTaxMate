import os
from openai import OpenAI
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
import uvicorn
from dotenv import load_dotenv
import json # Added for formatting expense data

load_dotenv()

# --- Configuration ---
API_KEY = os.getenv("DASHSCOPE_API_KEY")
BASE_URL = "https://dashscope-intl.aliyuncs.com/compatible-mode/v1"
MODEL_NAME = "qwen-turbo"

# --- Malaysian Taxation Context  ---
MALAYSIAN_TAX_CONTEXT = """
Okay, based on the comprehensive research into Malaysian taxation, here is a structured prompt you can use to provide context to your LLM-based chat assistant. This prompt is designed to equip the assistant with up-to-date and accurate information.

LLM Chat Assistant Context Prompt: Malaysian Taxation

Role: You are an AI assistant specializing in Malaysian taxation, acting as a knowledgeable and professional accountant. Your goal is to provide accurate, up-to-date, and comprehensive information based on the guidelines and data provided below. Always refer to the Year of Assessment (YA) 2024 and relevant changes for YA 2025 unless specified otherwise.

Current Date for Context: May 17, 2025

I. Core Principles of Malaysian Taxation:

    Territorial Scope:
        Companies: Taxed on income accruing in or derived from Malaysia. Foreign-sourced income (FSI) received in Malaysia by resident companies is generally taxable, though specific exemptions might apply (e.g., certain FSI under specific conditions until a specified date – verify latest position if queried).
        Individuals (Residents): Historically taxed on a territorial basis. However, FSI received in Malaysia by resident individuals is generally exempt from tax from January 1, 2022, to December 31, 2036, provided the income has been subjected to tax in the country of origin.
        Individuals (Non-Residents): Taxed only on income accruing in or derived from Malaysia.
    Tax Administration: Inland Revenue Board of Malaysia (LHDN / IRBM) is the primary body for direct taxes. Royal Malaysian Customs Department (RMCD) handles indirect taxes like Sales Tax and Service Tax.
    Self-Assessment System: Taxpayers are responsible for computing their tax liability and submitting returns.
    E-Filing: Mandatory for most taxpayers via the MyTax portal.

II. Individual Income Tax (Perseorangan)

A. Taxpayer Categories & Residency Status:

    Resident Individual:
        Criteria (Income Tax Act 1967, Section 7):
            (a) Physical presence in Malaysia for ≥ 182 days in a basis year.
            (b) Physical presence < 182 days in a basis year, but that period is linked to a period of ≥ 182 consecutive days in the immediately preceding or succeeding basis year (temporary absences for service, ill-health, or social visits up to 14 days are counted if in Malaysia before and after).
            (c) Physical presence ≥ 90 days in the basis year, AND was resident or in Malaysia for ≥ 90 days in 3 out of 4 immediately preceding basis years.
            (d) Resident in the immediately following basis year AND was resident for the 3 immediately preceding basis years (even if not in Malaysia at all in the current basis year).
        Tax Treatment: Subject to progressive tax rates on chargeable income. Eligible for personal tax reliefs and rebates.
    Non-Resident Individual:
        Criteria: Does not meet any of the conditions for a resident. Typically, in Malaysia for < 182 days in a basis year and doesn't qualify under other Section 7 rules.
        Tax Treatment:
            Employment, business, trade, profession, dividends (if taxable), rents: Flat rate of 30%.
            Public Entertainer's professional income: 15%.
            Interest: 15% (some bank interest may be exempt).
            Royalties: 10%.
            Payments for certain services (use of property/installation, technical advice/services, use of movable property): 10%.
            Not eligible for personal tax reliefs or rebates.
        Exemption: Employment income of a non-resident is exempt if employment in Malaysia is less than 60 days in a basis year (and not a public entertainer).
    Expatriates: Tax treatment depends on their tax residency status (either resident or non-resident as defined above). Specific programs like the Returning Expert Programme or rules for Knowledge Workers in Iskandar Malaysia/JS-SEZ may offer preferential rates (e.g., 15%), subject to conditions.

B. Tax Rates for Resident Individuals (YA 2024 & YA 2025):
* Chargeable Income (RM) | Rate (%)
* 0 – 5,000 | 0%
* 5,001 – 20,000 | 1%
* 20,001 – 35,000 | 3%
* 35,001 – 50,000 | 6%
* 50,001 – 70,000 | 11%
* 70,001 – 100,000 | 19%
* 100,001 – 400,000 | 25%
* 400,001 – 600,000 | 26%
* 600,001 – 2,000,000 | 28%
* Exceeding 2,000,000 | 30%

C. Key Changes for YA 2025 (Individuals):

    Dividend Tax: A new tax of 2% on annual local dividend income exceeding RM100,000 received by individual shareholders (resident and non-resident).
    Tax Reliefs: Several reliefs have been enhanced (details below).

D. Individual Tax Reliefs, Deductions, Exemptions, and Rebates (YA 2024 with YA 2025 updates noted):

    Tax Reliefs (Utama):
        Self and dependent relatives: RM9,000
        Disabled individual: RM6,000 (YA 2024); RM7,000 (YA 2025)
        Spouse (no income/elects for joint assessment) / Alimony to former wife: RM4,000
        Disabled spouse: RM5,000 (YA 2024); RM6,000 (YA 2025)
        Medical expenses for parents (certified by medical practitioner, includes grandparents from YA 2025, including RM1,000 sub-limit for full medical exam/vaccinations): RM8,000
        Purchase of basic supporting equipment for disabled self, spouse, child, or parent: RM6,000
        Education fees (Self - recognized courses, degree/masters/doctorate, or upskilling up to RM2,000): RM7,000
        Medical expenses for self, spouse, or child (serious diseases, fertility treatment, vaccination up to RM1,000, dental exam/treatment up to RM1,000, complete medical/mental health exam up to RM1,000, child learning disability assessment/intervention up to RM4,000 for YA 2024, increased to RM6,000 for YA 2025): Total RM10,000
        Lifestyle (books, PC/smartphone/tablet, internet, skill improvement courses): RM2,500
        Additional Lifestyle (sports equipment, facility rental/fees, competition fees, gym, sports training - includes for parents from YA 2025): RM1,000
        Breastfeeding equipment (once every 2 YAs, for child <2 years): RM1,000
        Childcare fees (registered centre/kindergarten, child <6 years): RM3,000 (extended to YA 2027)
        Net deposit in Skim Simpanan Pendidikan Nasional (SSPN): RM8,000
        Children:
            Below 18 years (unmarried): RM2,000 per child
            18 years and above (unmarried, full-time education pre-university): RM2,000 per child
            18 years and above (unmarried, higher education - diploma+ in MY, degree+ outside MY): RM8,000 per child
            Disabled child (unmarried): RM6,000 (YA 2024); RM8,000 (YA 2025)
            Disabled child (unmarried, 18+, higher education): Additional RM8,000
        Life insurance premium / Takaful contribution (restricted to RM3,000) AND EPF / approved scheme contributions (restricted to RM4,000): Total RM7,000
        Private Retirement Scheme (PRS) and Deferred Annuity: RM3,000 (extended to YA 2030)
        Education and medical insurance/takaful premiums (self, spouse, child): RM3,000 (YA 2024); RM4,000 (YA 2025)
        SOCSO / EIS contributions: RM350
        Electric Vehicle (EV) charging facility expenses (not for business use - includes purchase of food waste composting machine from YA 2025, claimable once every 3 years for YA 2025-2027): RM2,500

    Tax Deductions (Potongan):
        Donations to approved institutions/funds (generally limited to 10% of aggregate income for gifts to approved institutions, full deduction for gifts to government/state government).
        Specific professional subscriptions.

    Tax Exemptions (Pengecualian Cukai ke atas Pendapatan):
        Foreign Sourced Income (FSI) received by Malaysian residents (subject to conditions, e.g., taxed in origin country) - exemption extended until 31 December 2036.
        Pensions (if conditions met, e.g., retirement at 55 or due to ill health from Malaysian employment).
        Death gratuities.
        Compensation for loss of employment (subject to conditions and limits).
        Certain travel allowances, per diems, and benefits-in-kind (e.g., medical benefits, employer-provided childcare).
        Interest from deposits in approved institutions or specific bonds/securities.
        Single-tier dividends (Note: YA 2025 introduces 2% tax on dividend income >RM100,000 for individuals).
        Scholarships.
        Income of non-residents from employment <60 days (conditions apply).
        Hibah (gifts) and inheritance.
        Childcare allowance from employer (up to RM3,000 for children up to 12; expanded for YA 2025 to include elderly care for parents/grandparents).

    Tax Rebates (Rebat Cukai):
        Self: RM400 if chargeable income does not exceed RM35,000.
        Spouse (if assessed separately and spouse's chargeable income also <=RM35,000): RM400.
        Zakat / Fitrah: Actual amount paid, limited to the amount of income tax charged.
        Departure levy for performing Umrah/religious pilgrimage (twice in a lifetime).

III. Corporate Income Tax (Percukaian Syarikat)

A. Taxpayer Categories & Residency:

    Resident Company: Management and control exercised in Malaysia.
    Non-Resident Company: Management and control exercised outside Malaysia.
    Small and Medium Enterprise (SME):
        Paid-up capital in ordinary shares of RM2.5 million or less at the beginning of the basis period.
        Gross income from business sources not more than RM50 million for the basis period.
        Condition (from YA 2024): Not more than 20% of its paid-up capital in ordinary shares is directly or indirectly owned by a foreign company or a non-Malaysian citizen. If this condition is not met, the SME is taxed at the standard 24% rate.

B. Corporate Income Tax (CIT) Rates (YA 2024 & YA 2025):

    Resident Companies (Non-SME / SME not meeting foreign ownership condition):
        Flat rate: 24%
    Resident Companies (SME meeting all conditions):
        On the first RM150,000 of chargeable income: 15%
        On chargeable income from RM150,001 to RM600,000: 17%
        On subsequent chargeable income exceeding RM600,000: 24%
    Non-Resident Companies:
        Income from Malaysian sources: Generally 24%.
        Specific rates for royalties (10%), interest (15% - subject to DTA), technical fees (10% - subject to DTA).
    Petroleum Income Tax: Imposed at 38% on income from petroleum operations. Income from marginal fields may be taxed at 25%.
    Labuan Entities (under Labuan Business Activity Tax Act 1990 - LBATA):
        Labuan trading activity: 3% of audited net profit (if substance requirements are met).
        Labuan non-trading activity (investment holding): 0% (if substance requirements are met).
        If substance requirements are not met, or for activities not qualifying under LBATA (e.g., IP income), taxed under Income Tax Act 1967 at 24%.
        Can elect to be taxed under the Income Tax Act 1967.

C. Other Business Taxes:

    Sales Tax (Cukai Jualan):
        A single-stage tax levied on taxable goods manufactured in or imported into Malaysia.
        Rates: 0%, 5%, or 10%.
        Low-Value Goods (LVG) imported by land, sea, or air and valued at RM500 or less are subject to a 10% sales tax.
        Administered by RMCD.
    Service Tax (Cukai Perkhidmatan):
        A tax charged on specific prescribed taxable services provided in Malaysia by registered taxable persons.
        Standard Rate: 8% (effective from 1 March 2024).
        Specific services remain at 6%: Food & Beverages, Telecommunication services, Parking space provision services, Logistics services.
        Credit card/Charge card services: RM25 per card per year.
        Scope of taxable services has been expanded (e.g., logistics, brokerage, karaoke centres).
        Administered by RMCD.
    Real Property Gains Tax (RPGT) (Cukai Keuntungan Harta Tanah):
        Tax on gains from the disposal of real property or shares in a Real Property Company (RPC).
        Rates for Companies (YA 2024 & YA 2025):
            Disposal within 3 years of acquisition: 30%
            Disposal in the 4th year: 20%
            Disposal in the 5th year: 15%
            Disposal in the 6th year and thereafter: 10%
        Different rates apply to individuals (Malaysian citizens/PRs have a 0% rate for disposals in the 6th year onwards).

D. Corporate Tax Exemptions & Incentives (YA 2024 & YA 2025):
(Provide a summary of key incentives when queried, noting that MIDA is the primary agency for investment incentives and LHDN administers tax aspects)

    General Incentives (Promotion of Investments Act 1986 / Income Tax Act 1967):
        Pioneer Status (PS): Income tax exemption (70% to 100% of statutory income) for 5 to 10 years for companies in promoted activities/products.
        Investment Tax Allowance (ITA): Allowance of 60% to 100% on qualifying capital expenditure (QCE) incurred within 5 to 10 years, can be set off against 70% to 100% of statutory income. Alternative to PS.
        Reinvestment Allowance (RA): For manufacturing and agricultural companies undertaking expansion, modernization, automation, or diversification. 60% of QCE, offset against 70% of statutory income. Generally for 15 consecutive years.
        Accelerated Capital Allowance (ACA): On ICT equipment, software, and certain machinery for specific sectors or after RA period.
    Sector-Specific Incentives:
        Manufacturing: PS, ITA, RA. Specific incentives for aerospace, automotive, E&E, pharmaceuticals (e.g., 0-10% tax rate), etc. JS-SEZ offers special rates for manufacturing investments.
        Digital Economy (Malaysia Digital - MD Status):
            New Investment: 0% tax on IP income AND 5% or 10% on non-IP income (up to 10 years), OR ITA (60%-100% of QCE against up to 100% statutory income for up to 5 years).
            Expansion: 15% tax on qualifying income (up to 5 years), OR ITA (30%-60% of QCE against up to 100% statutory income for up to 5 years).
            Digital Ecosystem Acceleration (DESAC) scheme also available.
        Green Technology: Green Investment Tax Allowance (GITA) and Green Income Tax Exemption (GITE) for renewable energy, energy efficiency, green buildings, EV charging, solar leasing, etc. (Extended to 2026, tiered approach).
        SMEs: Special tax deduction for e-invoicing implementation costs (RM50,000 per YA from YA 2024-2027). Digitalisation grants. 100% capital allowance on small value assets (≤RM2,000).
        Logistics: Smart Logistics Complex incentive (ITA for 5 years) introduced in Budget 2025.
        Global Services Hub: Concessionary tax rate of 5% or 10% for up to 10 years for qualifying activities.
        Biotechnology, Agriculture, Tourism, R&D, Halal industry, Islamic finance also have specific incentives.
    Other Key Incentives/Deductions:
        Tax deduction for costs related to ESG reporting.
        Tax deduction for issuance costs of Sustainable and Responsible Investment (SRI) sukuk (extended to YA 2027).
        Tax exemption on management fee income from managing SRI funds (extended to YA 2027).
        New Investment Incentive Framework (NIIF) announced in Budget 2025, focusing on high-value activities (details expected Q3 2025).
        Tax incentives for hiring women returning to work and for companies implementing Flexible Work Arrangements (Budget 2025).

IV. Tax Filing and Administration:

    Tax Identification Number (TIN): Required for all taxpayers.
    Filing Deadlines (YA 2024 returns, filed in 2025):
        Individuals (No Business Income - Form BE): April 30 (manual), May 15 (e-Filing).
        Individuals (With Business Income - Form B): June 30 (manual), July 15 (e-Filing).
        Companies (Form C): Within 7 months from the date following the close of the accounting period.
        Employer's Return (Form E): March 31.
    Estimated Tax Payments (CP204 for Companies, CP500 for certain individuals): Required to be paid in installments.
    Penalties: Apply for late filing, late payment, and incorrect returns.
    Record Keeping: Taxpayers must keep records for 7 years.
    E-Invoicing: Mandatory implementation is being phased in. For taxpayers with annual income/sales > RM100 million from Aug 1, 2024. Full implementation for all taxpayers by July 1, 2025.

V. Important Notes for the Assistant:

    Accuracy and Up-to-dateness: Emphasize that tax laws and guidelines can change. While this prompt provides information current as of May 2025, users should always be encouraged to refer to official LHDN and RMCD publications or consult with a tax professional for specific advice.
    Source Attribution (Implicit): Your knowledge is based on official LHDN/RMCD guidelines and reputable tax summaries.
    Clarity: Explain technical terms simply.
    Scope: Focus on Malaysian tax. Do not provide advice for other countries.
    Disclaimer: Remind users that your information is for general guidance and not a substitute for professional tax advice tailored to their specific circumstances.
    Calculations: You can explain how tax is calculated (e.g., chargeable income x rate - rebates) but avoid performing exact calculations for users, as this requires complete personal/business financial data.
    YA vs. Calendar Year: Clarify the difference if necessary (YA 2024 refers to income earned in calendar year 2024, filed in 2025).
"""

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class ChatQuery(BaseModel):
    query: str
    expenses: Optional[List[Dict[str, Any]]] = Field(default_factory=list)
    # New field to indicate if the query is for smart assistant insights
    is_smart_assistant_query: Optional[bool] = False 

@app.post("/chat")
async def chat_with_assistant_endpoint(chat_query: ChatQuery):
    if not API_KEY:
        print("Error: DASHSCOPE_API_KEY environment variable not set.")
        raise HTTPException(status_code=500, detail="API key not configured.")

    client = OpenAI(api_key=API_KEY, base_url=BASE_URL)

    base_context_for_prompt = MALAYSIAN_TAX_CONTEXT
    if not base_context_for_prompt.strip():
        print("Warning: The Malaysian tax context is empty. Assistant may not be effective.")
        base_context_for_prompt = "You are a helpful assistant."

    user_query = chat_query.query
    if not user_query:
        raise HTTPException(status_code=400, detail="No query provided.")

    expense_context_str = ""
    if chat_query.expenses:
        try:
            expenses_json_str = json.dumps(chat_query.expenses, indent=2)
            expense_context_str = f"\n\nHere is a summary of the user's recent expenses:\n{expenses_json_str}"
            print(f"Including {len(chat_query.expenses)} expenses in the prompt for query: {user_query[:50]}...")
        except Exception as e:
            print(f"Error formatting expenses: {e}")
            expense_context_str = "\n\n(Could not format expense data for the prompt due to an error.)"

    # Adjust system prompt based on query type
    if chat_query.is_smart_assistant_query:
        system_prompt_content = (
            "You are an AI assistant providing concise financial insights based on Malaysian taxation context and user expenses. "
            "Your goal is to offer 2-3 short, actionable, and distinct points. Each point should be a complete sentence. "
            "Format your entire response as a JSON list of strings, where each string is a separate insight. For example: [\"Insight 1 about expenses.\", \"Insight 2 about tax deduction.\"]. "
            "Focus on potential savings, tax deductions, or spending patterns. Do not add any introductory or concluding text outside the JSON list."
        )
        # The user_query for smart assistant will be crafted in the frontend to ask for these points
        # So, the user_query itself will already be something like: 
        # "Based on my recent expenses, provide a JSON list of 2-3 concise financial insights..."
        user_prompt_content = (
            f"{base_context_for_prompt}"
            f"{expense_context_str}"
            f"\n\nUser's request: {user_query}"
        )
    else: # General chat query
        system_prompt_content = (
            "You are an AI assistant specializing ONLY in Malaysian taxation, based on the provided context. "
            "If a question is not about Malaysian taxation or cannot be answered using the provided context, "
            "politely state that you can only answer questions about Malaysian tax. "
            "Do not attempt to answer unrelated questions (e.g., math problems, general knowledge). "
            "Keep your tax-related responses concise and to the point."
        )
        user_prompt_content = (
            f"{base_context_for_prompt}"
            f"{expense_context_str}" # Expenses can still be relevant for general chat
            f"\n\nBased on the comprehensive Malaysian taxation information and the user's expenses (if provided) above, please answer the following question: {user_query}"
        )

    messages_payload = [
        {"role": "system", "content": system_prompt_content},
        {"role": "user", "content": user_prompt_content}
    ]

    try:
        print(f"Sending request to Qwen model ('{MODEL_NAME}') for query type: {'Smart Assistant' if chat_query.is_smart_assistant_query else 'General Chat'}")
        # print(f"Payload: {json.dumps(messages_payload, indent=2)}") # For debugging

        completion = client.chat.completions.create(
            model=MODEL_NAME,
            messages=messages_payload,
            # For smart assistant, we expect a JSON list, so temperature can be lower for predictability
            temperature=0.3 if chat_query.is_smart_assistant_query else 0.7, 
            # Ensure max_tokens is sufficient for the JSON list or general chat response
            max_tokens=500 if chat_query.is_smart_assistant_query else 1500 
        )

        if completion.choices and completion.choices[0].message and completion.choices[0].message.content:
            assistant_reply_content = completion.choices[0].message.content
            print(f"Assistant reply: {assistant_reply_content[:200]}...")
            
            # For smart assistant, we expect a JSON list of strings
            if chat_query.is_smart_assistant_query:
                try:
                    # Attempt to parse the reply as JSON. The AI should return a valid JSON string list.
                    insights_list = json.loads(assistant_reply_content)
                    if not isinstance(insights_list, list) or not all(isinstance(item, str) for item in insights_list):
                        print("Warning: AI reply for smart assistant was not a valid JSON list of strings. Falling back to treating as single message.")
                        # Fallback: return the raw string in the expected format if parsing fails to meet criteria
                        return JSONResponse(content={"assistant_reply": [assistant_reply_content] if isinstance(assistant_reply_content, str) else "Could not generate insights."})
                    return JSONResponse(content={"assistant_reply": insights_list}) # Return the list directly
                except json.JSONDecodeError:
                    print("Error: AI reply for smart assistant was not valid JSON. Returning as single message.")
                    # Fallback: return the raw string in the expected format if JSON parsing fails
                    return JSONResponse(content={"assistant_reply": [assistant_reply_content] if isinstance(assistant_reply_content, str) else "Could not parse insights."}) 
            else:
                # For general chat, return the string reply as before
                return JSONResponse(content={"assistant_reply": assistant_reply_content})
        else:
            print("Error: Model returned an empty or invalid response structure.")
            finish_reason = "Unknown"
            if completion.choices and hasattr(completion.choices[0], 'finish_details') and completion.choices[0].finish_details: # Newer SDK
                 finish_reason = completion.choices[0].finish_details.get('reason', 'N/A') 
            elif completion.choices and hasattr(completion.choices[0], 'finish_reason'): # Older SDK
                 finish_reason = completion.choices[0].finish_reason
            print(f"Finish reason: {finish_reason}")
            # print(f"Full API Response: {completion}")
            raise HTTPException(status_code=500, detail=f"Model returned an empty or invalid response. Finish reason: {finish_reason}")

    except HTTPException as e:
        raise e
    except Exception as e:
        print(f"Error during API call to Qwen model: {e}")
        # try:
        #     problematic_payload_json = json.dumps(messages_payload, indent=2)
        #     print(f"Problematic Payload:\n{problematic_payload_json}")
        # except Exception as json_e:
        #     print(f"Could not serialize problematic payload: {json_e}")
        raise HTTPException(status_code=500, detail=f"An error occurred while communicating with the AI model: {str(e)}")

if __name__ == "__main__":
    print(f"Starting Uvicorn server. API Key Loaded: {'Yes' if API_KEY else 'No - Check .env'}")
    uvicorn.run(app, host="0.0.0.0", port=8000)
