# Build Prompt: SME Business Risk Assessment Expert System (Prolog + Web UI)

You are helping a third-year IT undergraduate at the University of Moratuwa, Sri Lanka, complete an **Expert Systems** university assignment. Your job is to build a **complete, runnable expert system in SWI-Prolog with a web-based user interface** served by SWI-Prolog's built-in HTTP server.

Read this whole document before writing any code. Then read `knowledge_base.pl` (already in this folder). Then write a short plan, and build in the order given in section 14.

---

## 1. Who you are building for

- The student is **new to Prolog and expert systems**. They must **explain every part of the code in a viva**. So:
  - Write **clear, simple, well-commented Prolog**. Prefer readable code over clever code.
  - Every file starts with a header comment explaining its role in the expert-system architecture.
  - Every rule, predicate, and HTTP handler has a short comment explaining what it does and why.
  - Avoid advanced features unless necessary (no DCG tricks, no constraint libraries, no dicts unless they genuinely simplify things; if you use dicts, comment them).
- The system must run on **Windows, macOS, and Linux** with only SWI-Prolog installed. That is why the UI is a web page, not XPCE.
- The examiner will run it by following the README. It must work **offline** (no CDNs, no Google Fonts, no external JS/CSS).

---

## 2. The assignment requirements (must all be satisfied)

From the course page:

1. Build an expert system in a selected domain.
2. Explanation of the system with a suitable diagram.
3. Interface of the expert system with a description.
4. Knowledge base and inference engine description.
5. Test cases of the system built.
6. 20 rules, each referenced to a valid document.

From the lecturer's guidelines:

- At least **20 facts and 20 rules** (we have ~97 facts and 39 rules).
- Prolog is strongly encouraged.
- The system must demonstrate **both forward chaining and backward chaining**.
- It must have a **user interface**.
- It must **not just give a final answer**. It must show: **User Input → Facts → Rules Applied → Reasoning → Final Conclusion**.
- Test cases must show valid inputs, different scenarios, expected vs actual outputs, **which rules fired**, and that the explanation is correct.
- A **user manual**: required software, installation, how to run, how to use the UI, example inputs and outputs.
- The final system must be executable by another person following the guide.

---

## 3. The domain

**SME Business Risk Assessment for Sri Lankan small and medium businesses.**

A small business owner enters basic financial and business information. The system:

1. Classifies the business size (micro / small / medium) using Sri Lanka's National SME Policy Framework.
2. Calculates four financial ratios.
3. Identifies risk indicators (liquidity, debt, cash, customer dependency, exchange rate, finance access, profitability).
4. Combines them into an overall risk level: **LOW, MODERATE, HIGH, or CRITICAL**.
5. Gives sourced advice.
6. Explains exactly which rules fired, why, and which published source each rule comes from.

Problem context (for the home page and README, keep it short): many Sri Lankan SMEs struggled or closed after the 2022 economic crisis, and small owners usually cannot afford a financial consultant. This tool gives a general risk screening. **It is not a professional audit** — say this clearly in the UI footer and README.

---

## 4. Existing file: `knowledge_base.pl`

Already written and tested. **Do not change any threshold, limit, source, or question wording.** You may add new facts if needed (for example, rule definitions or "why" text), but keep them in clearly marked sections.

It contains these predicates:

| Predicate | Meaning |
|---|---|
| `question(Id, Text, Type)` | 14 questions q0–q13. Type is `number`, `yes_no`, or `choice(List)` |
| `input_name(Id, Name)` | Maps q0–q13 to names: `sector, employees, turnover, current_assets, inventory, current_liabilities, total_liabilities, equity, cash, monthly_expenses, largest_customer_pct, net_profit, imports, audited_statements` |
| `threshold(Name, Value)` | All numeric thresholds used by rules |
| `employee_limit(Sector, Category, Min, Max)` | SME employee limits per sector |
| `turnover_limit(Category, LowerExclusive, UpperInclusive)` | SME turnover limits (Rs. million) |
| `risk_category(Category, FactList)` | The 7 categories C1–C7 used for counting |
| `description(Fact, Text)` | Plain-English meaning of each derived fact |
| `advice_text(RuleId, Text)` | Advice text for r37, r38, r39 |
| `source(Id, Citation)` | Sources s1–s14 plus `design` |
| `goal_option(Goal, Label)` | Goals the user can test in backward-chaining mode |

The rules must **look up thresholds from `threshold/2` and the limit facts**, never hard-code the numbers. This separation of knowledge from reasoning is a key point in the student's report.

---

## 5. Architecture and files to create

```
sme_expert_system/
├── main.pl            Entry point. Loads everything, starts the web server, prints the URL.
├── knowledge_base.pl  (exists) Facts.
├── rules.pl           The 39 rules, stored as data (see section 8).
├── engine.pl          Validation, calculations, forward chaining, backward chaining.
├── explanation.pl     Builds HOW and WHY explanations from the engine's trace.
├── web_ui.pl          HTTP handlers and HTML generation (library(http/html_write)).
├── static/style.css   All styling (served locally).
├── tests.pl           plunit tests for the test cases in section 12.
└── README.md          User manual (section 13).
```

This split mirrors the classic expert-system architecture (knowledge base, inference engine, explanation facility, user interface, working memory). Keep that mapping explicit in header comments so the student can draw the architecture diagram from it.

---

## 6. Inputs, validation, and calculations

### 6.1 Inputs (from `question/3`)

| Id | Name | Type | Notes |
|---|---|---|---|
| q0 | sector | choice | manufacturing / service |
| q1 | employees | number | whole number ≥ 0 |
| q2 | turnover | number | Rs. million, ≥ 0 |
| q3 | current_assets | number | Rs., ≥ 0 |
| q4 | inventory | number | Rs., ≥ 0 |
| q5 | current_liabilities | number | Rs., ≥ 0 |
| q6 | total_liabilities | number | Rs., ≥ 0 |
| q7 | equity | number | Rs., **may be negative** |
| q8 | cash | number | Rs., ≥ 0 |
| q9 | monthly_expenses | number | Rs., > 0 |
| q10 | largest_customer_pct | number | 0–100 |
| q11 | net_profit | number | Rs., **may be negative** |
| q12 | imports | yes_no | |
| q13 | audited_statements | yes_no | |

### 6.2 Validation (runs before any rule; these are input checks, NOT knowledge rules)

- Every field must be filled. Numbers must parse (use `atom_number/2` on the submitted text; accept commas like `1,000,000` by removing them first).
- Basic type checks: employees whole number ≥ 0; non-negative fields ≥ 0; percentage 0–100.
- **V1:** `monthly_expenses` must be > 0. Error: "Monthly expenses must be more than 0 so cash reserve months can be calculated."
- **V2:** `inventory` must not exceed `current_assets`. Error: "Stock is part of current assets, so it cannot be larger than current assets."
- **V3:** If `current_liabilities` = 0, do not calculate CR or QR; skip rules R13–R18 and show the note "No short-term liabilities, so liquidity ratios do not apply."
- **V4:** If `equity` ≤ 0, do not calculate DE; skip R20–R22 (R19 handles this case).

Errors must be shown **next to the field that caused them**, with the user's previously typed values kept in the form.

### 6.3 Calculations

| Name | Formula | Only if |
|---|---|---|
| Current ratio (CR) | current_assets ÷ current_liabilities | current_liabilities > 0 |
| Quick ratio (QR) | (current_assets − inventory) ÷ current_liabilities | current_liabilities > 0 |
| Debt-to-equity (DE) | total_liabilities ÷ equity | equity > 0 |
| Cash reserve months (CM) | cash ÷ monthly_expenses | always (V1 guarantees > 0) |

Show ratios rounded to 2 decimal places in the UI.

---

## 7. Sources (for display in the UI and the explanation)

These match `source/2` in the knowledge base. Show the short citation in the explanation, and the full list on an About/Sources page.

| Id | Source |
|---|---|
| s1 | Ministry of Industry and Commerce, Sri Lanka. National Policy Framework for SME Development |
| s2 | Association of Corporate Treasurers, ACT Wiki: "Current ratio" |
| s3 | Saylor Academy: "Liquidity Ratios" |
| s4 | Companies Act No. 7 of 2007 (Sri Lanka), s.57; Nanayakkara (2021), Asian Journal of Law and Governance 3(1), 33–46 |
| s5 | Xero: "Debt-to-equity ratio" guide |
| s6 | Funding Circle UK: "Small business debt-to-equity ratio" |
| s7 | JPMorgan Chase Institute (2016): Cash is King: Flows, Balances, and Buffer Days |
| s8 | SCORE: "How Much Cash Should a Small Business Keep in Reserve?" |
| s9 | IFRS 8 Operating Segments, paragraph 34 |
| s10 | Dhaliwal, Judd, Serfling & Shaikh (2016), Journal of Accounting and Economics 61(1), 23–48 |
| s11 | Central Bank of Sri Lanka (2022): Recent Economic Developments: Highlights of 2022 and Prospects for 2023 |
| s12 | National Chamber of Exporters of Sri Lanka (2026) |
| s13 | Gamage (2013), Corporate Ownership & Control 10(3-3), 402–409 |
| s14 | Altman (1968), Journal of Finance 23(4), 589–609 |
| design | Knowledge engineer design, inspired by the multi-factor principle (Altman, 1968) |

**Do not invent, add, or change sources.**

---

## 8. The 39 rules (implement exactly)

Ratings: **DIRECT** (source states it), **APPLIED** (source supports it with small interpretation), **DESIGN** (knowledge-engineer combination). Show the rating in the explanation.

### 8.1 Rule representation

Store every rule as **data**, so both chaining modes and the explanation use the same knowledge:

```prolog
% rule(Id, Group, Conditions, Conclusion, Sources, Rating, EnglishText)
rule(r13, liquidity,
     [ratio(cr, <, current_ratio_low)],
     liquidity_risk_high,
     [s2, s3], direct,
     'IF current ratio < 1 THEN liquidity risk is high').
```

Design a small, readable **condition language** and document it at the top of `rules.pl`. Suggested condition forms (you may adjust, but keep it simple and comment it):

- `input(Name, Op, ValueOrThresholdName)` — compare a user input
- `input_is(Name, Value)` — e.g. `input_is(imports, yes)`
- `ratio(RatioName, Op, ThresholdName)` — compare a calculated ratio to a threshold fact
- `between_t(RatioName, LowThreshold, Op1, Op2, HighThreshold)` or two separate ratio conditions — for ranges
- `fact(F)` — a derived fact must be true
- `not_fact(F)` — negation as failure (only after the relevant phase has run)
- `any(ListOfConditions)` — OR
- `category_count(Op, ThresholdNameOrNumber)` — number of risk categories present
- `emp_in(Category)`, `turnover_in(Category)` — use `employee_limit/4`, `turnover_limit/3`
- `same_category` / `different_category` — for R10/R11

A condition referring to a ratio that is not calculable (V3/V4) simply **fails** (the rule does not fire).

### 8.2 Group A — Business size (source s1, all DIRECT except R12)

| Rule | IF | THEN |
|---|---|---|
| R1 | employees within `employee_limit(Sector, micro, _, _)` (≤ 10) | emp_category(micro) |
| R2 | employees 11–50 | emp_category(small) |
| R3 | sector = manufacturing AND employees 51–300 | emp_category(medium) |
| R4 | sector = service AND employees 51–200 | emp_category(medium) |
| R5 | employees above the sector's medium maximum | emp_category(large) |
| R6 | turnover ≤ 15 | turnover_category(micro) |
| R7 | turnover > 15 AND ≤ 250 | turnover_category(small) |
| R8 | turnover > 250 AND ≤ 750 | turnover_category(medium) |
| R9 | turnover > 750 | turnover_category(large) |
| R10 | emp_category = turnover_category | size(that category) |
| R11 | emp_category ≠ turnover_category | size(emp_category) — the framework says employment decides |
| R12 (APPLIED) | size(large) | outside_sme_scope → **stop the assessment** and tell the user the system only assesses SMEs |

Turnover bands are continuous (no gaps). Example: 40 employees + Rs. 900M → emp small, turnover large, R11 → size small.

### 8.3 Group B — Liquidity (skip if current_liabilities = 0)

| Rule | IF | THEN | Sources | Rating |
|---|---|---|---|---|
| R13 | CR < 1.0 | liquidity_risk_high | s2, s3 | DIRECT |
| R14 | 1.0 ≤ CR < 1.5 | liquidity_caution | s3 | APPLIED |
| R15 | 1.5 ≤ CR ≤ 3.0 | liquidity_healthy | s3 | DIRECT |
| R16 | CR > 3.0 | possible_idle_assets | s3 | APPLIED |
| R17 | QR < 1.0 | quick_liquidity_weak | s3 | DIRECT |
| R18 | QR ≥ 1.0 | quick_liquidity_ok | s3 | DIRECT |

### 8.4 Group C — Debt and solvency

| Rule | IF | THEN | Sources | Rating |
|---|---|---|---|---|
| R19 | equity ≤ 0 | balance_sheet_insolvency | s5, s4 | APPLIED |
| R20 | equity > 0 AND DE > 2.0 | high_debt_risk | s5, s6 | DIRECT |
| R21 | equity > 0 AND 1.0 ≤ DE ≤ 2.0 | debt_manageable | s6 | DIRECT |
| R22 | equity > 0 AND DE < 1.0 | largely_self_funded | s6 | DIRECT |

### 8.5 Group D — Cash reserves

| Rule | IF | THEN | Sources | Rating |
|---|---|---|---|---|
| R23 | CM < 1.0 | critical_cash_risk | s7 | APPLIED |
| R24 | 1.0 ≤ CM < 3.0 | cash_reserve_low | s8 | DIRECT |
| R25 | CM ≥ 3.0 | cash_reserve_adequate | s8 | DIRECT |

### 8.6 Group E — Other risks

| Rule | IF | THEN | Sources | Rating |
|---|---|---|---|---|
| R26 | largest_customer_pct ≥ 10 | major_customer_reliance | s9, s10 | APPLIED |
| R27 | imports = yes | exchange_rate_risk | s11, s12 | APPLIED |
| R28 | audited_statements = no | finance_access_risk | s13 | DIRECT |
| R29 | net_profit < 0 | profitability_risk | s14 | APPLIED |

### 8.7 Group F — Combined conditions (all DESIGN, source `design`)

| Rule | IF | THEN |
|---|---|---|
| R30 | liquidity_risk_high AND critical_cash_risk | acute_liquidity_crisis |
| R31 | high_debt_risk AND profitability_risk | debt_distress |
| R32 | finance_access_risk AND (liquidity_risk_high OR critical_cash_risk) | refinancing_difficulty |

### 8.8 Group G — Overall risk level (all DESIGN, source `design`)

Count **risk categories** using `risk_category/2`. A category counts **once** if any of its facts is true.

| Rule | IF | THEN |
|---|---|---|
| R33 | balance_sheet_insolvency OR acute_liquidity_crisis OR debt_distress | risk_level(critical) |
| R34 | NOT critical AND categories ≥ 4 | risk_level(high) |
| R35 | NOT critical AND categories 2–3 | risk_level(moderate) |
| R36 | NOT critical AND categories 0–1 | risk_level(low) |

Exactly one risk level must result for every in-scope business.

### 8.9 Group H — Advice

| Rule | IF | THEN (advice text from `advice_text/2`) | Sources | Rating |
|---|---|---|---|---|
| R37 | critical_cash_risk OR cash_reserve_low | Build cash reserves toward 3–6 months of expenses | s8 | DIRECT |
| R38 | finance_access_risk | Prepare audited financial statements to improve access to bank finance | s13 | APPLIED |
| R39 | liquidity_risk_high AND NOT profitability_risk | Short-term financing backed by long-term prospects may bridge the gap | s3 | APPLIED |

### 8.10 Phases (needed for correct negation and counting)

Run the forward engine in phases so `not_fact/1` and category counting only happen after the facts they depend on are final:

1. Phase 1: Group A (size). If R12 fires, stop.
2. Phase 2: Groups B, C, D, E (indicators).
3. Phase 3: Group F (combined).
4. Phase 4: Group G (risk level).
5. Phase 5: Group H (advice).

Within each phase, loop until no new rule fires (fixpoint).

---

## 9. Inference engine

### 9.1 Working memory

Use dynamic predicates, cleared at the start of each assessment:

- `wm_input(Name, Value)` — user answers
- `wm_ratio(Name, Value)` — calculated ratios
- `wm_fact(Fact)` — derived facts
- `wm_fired(Step, RuleId)` — the order rules fired in

Because the web server is multi-threaded, wrap each full assessment in `with_mutex(sme_engine, ...)` so two browser requests never mix working memory. (Single-user demo, but this keeps it correct.)

### 9.2 Forward chaining (data-driven) — used by "Full risk assessment"

- Input: all 14 validated answers.
- Clear working memory, store inputs, calculate ratios, run phases 1–5 as above.
- Output a result term the UI can render, for example:

```prolog
result(Size, OutOfScope, Ratios, Facts, FiredRules, RiskLevel, CategoryCount, Advice, Notes)
```

`FiredRules` must be in firing order, each with: rule id, group, English text, the actual values that satisfied it (e.g. "CR = 0.80 < 1.0"), sources, rating, and the fact it added.

### 9.3 Backward chaining (goal-driven) — used by "Check a specific risk"

- The user picks a goal from `goal_option/2`: `risk_level(critical)`, `acute_liquidity_crisis`, `debt_distress`, `critical_cash_risk`.
- `prove(Goal)` finds rules whose conclusion matches, then proves each condition:
  - `fact(F)` → recursively `prove(F)`
  - an input or ratio condition → needs specific inputs; if an input is **not yet known**, the engine must stop and report `need_input(Name, WhyRuleIds)` instead of guessing
  - `any(List)` → try each in order
- **The system must only ask the questions that are actually needed.** Example: for `acute_liquidity_crisis` it should ask only current assets, current liabilities, cash, and monthly expenses.
- Record the proof trace: each goal tried, which rule was used, which conditions succeeded or failed. Failed branches must be shown too (e.g. "Tried R19: equity ≤ 0 — failed, equity is 1,000,000").
- For `risk_level(critical)`, only R33 is needed (it is an OR of three conditions). Try them in order: insolvency, acute_liquidity_crisis, debt_distress.

Suggested API for the web layer:

```prolog
% prove_goal(+Goal, +KnownAnswers, -Outcome)
% Outcome = proven(Trace) | disproven(Trace) | need_input(Name, WhyRuleIds)
```

The web layer keeps the answers collected so far in the HTTP session (`library(http/http_session)`), calls `prove_goal/3` again after each answer, and repeats until the outcome is `proven` or `disproven`. This is how backward chaining works interactively on the web: one question at a time, each with a **Why is this asked?** explanation built from `WhyRuleIds`.

Validate each single answer the same way as section 6.2 (V1 for monthly expenses, basic types; skip cross-field checks like V2 if the other field is not asked).

### 9.4 Explanation facility (`explanation.pl`)

- **HOW** (after a result): the chain User Input → Calculated ratios → Facts derived → Rules applied (in order, with values, sources, rating) → Conclusion → Advice.
- Also list important **rules that were checked but did not fire**, when useful. At minimum: if R39 did not fire because of a loss, say so; if R12 stopped the run, say so.
- **WHY** (during backward chaining): "This question is asked because the system is trying to prove *acute liquidity crisis* using rule R30 (IF liquidity risk high AND critical cash risk ...), which needs R13 (current ratio < 1), which needs current liabilities."
- Generate explanations from the rule data, not hand-written strings per case.

---

## 10. Web UI

### 10.1 Technical

- Use `library(http/thread_httpd)`, `library(http/http_dispatch)`, `library(http/http_parameters)`, `library(http/html_write)`, `library(http/http_session)`, and `library(http/http_files)` or `http_reply_file` for `static/style.css`.
- Default port **8080**; if busy, allow `swipl main.pl 8081`. On start, print: `SME Risk Expert System running at http://localhost:8080 — open this in your browser. Press Ctrl+C to stop.`
- `main.pl` should start the server automatically when run with `swipl main.pl`, and keep running.
- Use `html_write` so all user text is escaped automatically. No inline user input in raw HTML.
- Standard HTML forms with POST. **No JavaScript is required**; if you add any, the pages must still work without it.
- Must work offline. System font stack only.

### 10.2 Pages and flow

1. **Home (`/`)**
   - One-sentence explanation of what the tool does and for whom.
   - Two clear actions: **Start full assessment** (forward chaining) and **Check a specific risk** (backward chaining). Under each, one plain sentence explaining the difference (e.g. "Answer all 14 questions and see every risk found" vs "Pick one question about your business and answer only what's needed").
   - Links: **How it works** (short architecture + chaining explanation), **Rules and sources**.
   - Footer: "General risk screening for education. Not a professional financial audit."

2. **Full assessment form (`/assess`)**
   - All 14 questions on one page, grouped into four sections that follow the order a person would gather the information:
     1. About the business (q0 sector, q1 employees, q2 turnover)
     2. Balance sheet (q3–q7)
     3. Cash and profit (q8, q9, q11)
     4. Customers, imports and records (q10, q12, q13)
   - Numbers: text inputs with `inputmode="decimal"`, placeholder examples, and a small hint (e.g. "Rs. — include cash, stock, and money customers owe you").
   - Sector and yes/no: radio buttons.
   - A **"Fill with example: Nimal's Bakery"** link or button that pre-fills test case T1, so the examiner can demo quickly. Also add examples for T2 (healthy) and T4 (high).
   - Submit button text: **"Assess my business"**.
   - On validation errors: re-render the form with values kept and the error message under the specific field; a summary at the top listing the problems.

3. **Result page (`/result` or rendered directly after POST)**
   - The memorable element (see design section): the **risk level** shown large, with the 7 risk categories displayed as a strip of 7 labelled segments, each marked present or clear (with text, not colour alone).
   - Business size and how it was decided (R1–R11 path, including the R11 employment tie-break if it applied).
   - Ratios table: CR, QR, DE, CM with value, threshold used, and meaning. Show "Not applicable" with reason for skipped ratios (V3/V4).
   - Risks found: each with its description.
   - Advice: each with its rule id and source.
   - **How this was decided** (the HOW explanation): an ordered list of every fired rule with rule id, IF–THEN text, actual values, source citation(s), and rating. This list IS a sequence, so numbering is appropriate.
   - Rules checked but not fired (where useful, see 9.4).
   - Buttons: **Start a new assessment**, **Print this report** (browser print; add a print stylesheet that hides navigation).
   - If R12 fired: show a clear message that the business is outside SME limits (with its employee and turnover figures and the limits), and do not show a risk level.

4. **Check a specific risk (`/check`)**
   - Choose one goal (radio list from `goal_option/2`).
   - Then one question at a time (`/check/ask`). Each question page shows:
     - the question and input
     - a progress line such as "Question 3 — the system asks only what it needs"
     - a **Why is this asked?** disclosure (`<details>`) with the WHY explanation
   - Final page: **Proven** or **Not proven**, the proof trace (tried rules, succeeded and failed conditions), sources, and the number of questions asked compared with the 14 in a full assessment.
   - Button to switch to full assessment with answers already given pre-filled.

5. **Rules and sources (`/rules`)**
   - All 39 rules grouped A–H, generated from `rule/7`, with IF–THEN text, source ids, and rating.
   - Full source list from `source/2`.
   - Short note explaining DIRECT / APPLIED / DESIGN.

6. **How it works (`/about`)**
   - A simple architecture diagram built with HTML/CSS or inline SVG (User → Web interface → Inference engine ↔ Knowledge base, Working memory, Explanation facility).
   - One short paragraph each on forward and backward chaining, using this system's rules as the example.

### 10.3 Writing in the UI

- Plain, active language. Sentence case. No filler.
- Name things by what the user understands: "Cash available now", not "q8".
- Errors say what is wrong and how to fix it. No apologies.
- Buttons say exactly what happens: "Assess my business", "Check this risk", "Start a new assessment".

---

## 11. Visual design

Subject: a financial health check for small Sri Lankan business owners (bakeries, hardware shops, garment workshops), also viewed by a university examiner. It should feel like a **trustworthy, calm, well-kept account book**, not a startup dashboard or a generic SaaS template.

**Palette (5 core colours + status):**

| Name | Hex | Use |
|---|---|---|
| Ledger ink | `#1D2B36` | Main text, headings |
| Page | `#F3F5F4` | Page background (cool, not cream) |
| Sheet | `#FFFFFF` | Form and report surfaces |
| Rule line | `#CBD3CF` | Borders, table lines, dividers |
| Account green | `#1F5E4A` | Primary buttons, links, "clear" state |
| Status: caution | `#9A6200` | Moderate |
| Status: high | `#A8431A` | High |
| Status: critical | `#9B1C1C` | Critical |
| Status: low | `#1F5E4A` | Low |

Every status must also be written in words; never rely on colour alone. Check contrast meets WCAG AA.

**Type:** system font stack only (offline): `system-ui, -apple-system, "Segoe UI", Roboto, "Noto Sans", "Noto Sans Sinhala", Arial, sans-serif`. Use `font-variant-numeric: tabular-nums` for every number and ratio so figures line up like a ledger. Clear type scale (e.g. 15/17px body, 1.5 line height; headings in a restrained scale). Keep line length under ~75 characters for prose.

**Layout:**
- Single centred column, max width about 760px for forms, about 900px for the result report.
- Forms: labels above inputs, hints below labels, generous spacing between sections, section headings numbered 1–4 because the form is a sequence.
- Result page: the risk level block first, then the report in document order. Tables use thin rule lines like an account book, right-aligned numbers.

**The one bold element:** the risk-level block on the result page — the level in large type, plus the strip of 7 category segments (Liquidity, Debt, Cash, Customer, Exchange rate, Finance access, Profitability), each labelled and marked "Risk" or "Clear". Keep everything else quiet.

**Avoid:** identical rounded cards everywhere, soft grey drop shadows, gradient washes, all-caps eyebrow labels, emoji, decorative icons, arrows appended to button text, monospace data labels, cream backgrounds with terracotta accents.

**Quality floor:** responsive to mobile width, visible keyboard focus styles, `prefers-reduced-motion` respected (little or no motion anyway), proper `<label for>` on every input, a print stylesheet for the result page.

---

## 12. Tests (`tests.pl`, using plunit)

Write plunit tests that call the engine directly (not through HTTP) and check the size, risk level, fired rules, and advice. Also include a few HTTP smoke tests if easy (start server on a test port, request `/`, `/assess`, `/rules`, check status 200), otherwise document manual checks in the README.

### 12.1 Forward chaining test cases

Money in Rs. unless stated; turnover in Rs. million.

**T1 — Nimal's Bakery (CRITICAL)**
Inputs: manufacturing, 6 employees, turnover 8, current assets 800000, inventory 300000, current liabilities 1000000, total liabilities 3000000, equity 1000000, cash 350000, monthly expenses 400000, largest customer 40, net profit −50000, imports yes, audited no.
Ratios: CR 0.80, QR 0.50, DE 3.00, CM 0.875.
Expected: size micro (R1, R6, R10). Fired indicators: R13, R17, R20, R23, R26, R27, R28, R29. Combined: R30, R31, R32. Level: R33 → CRITICAL. Advice: R37, R38. **R39 must NOT fire** (loss-making).

**T2 — Healthy service business (LOW)**
service, 25, turnover 120, CA 5000000, inventory 1000000, CL 2500000, TL 3000000, equity 6000000, cash 3000000, expenses 800000, customer 8, profit 2000000, imports no, audited yes.
Ratios: CR 2.00, QR 1.60, DE 0.50, CM 3.75.
Expected: size small (R2, R7, R10). Fired: R15, R18, R22, R25. Categories 0 → R36 LOW. No advice rules fire.

**T3 — Moderate manufacturer (MODERATE)**
manufacturing, 45, turnover 200, CA 4000000, inventory 2500000, CL 3000000, TL 5000000, equity 3000000, cash 1500000, expenses 1000000, customer 5, profit 500000, imports no, audited yes.
Ratios: CR 1.33, QR 0.50, DE 1.67, CM 1.50.
Expected: size small. Fired: R14, R17, R21, R24. Categories: liquidity, cash = 2 → R35 MODERATE. Advice: R37.

**T4 — High risk but not critical (HIGH)**
service, 8, turnover 12, CA 900000, inventory 100000, CL 1000000, TL 2500000, equity 1000000, cash 500000, expenses 300000, customer 60, profit 100000, imports yes, audited yes.
Ratios: CR 0.90, QR 0.80, DE 2.50, CM 1.67.
Expected: size micro. Fired: R13, R17, R20, R24, R26, R27. R30, R31, R32 do NOT fire. Categories: liquidity, debt, cash, customer, exchange rate = 5 → R34 HIGH. Advice: R37, **R39 fires** (liquidity risk high and profitable).

**T5 — Negative equity (CRITICAL via insolvency)**
manufacturing, 15, turnover 40, CA 2000000, inventory 500000, CL 1000000, TL 6000000, equity −500000, cash 1200000, expenses 300000, customer 5, profit 50000, imports no, audited yes.
Expected: size small. R15, R18, R19, R25 fire. **R20–R22 do NOT fire** (DE not calculated). R33 → CRITICAL. DE shown as "Not applicable: equity is zero or negative".

**T6 — Size tie-break (R11)**
Same as T2 but employees 40 and turnover 900.
Expected: R2 (emp small), R9 (turnover large), R11 → size small. Assessment continues. LOW.

**T7 — Outside SME scope (R12)**
Same as T2 but sector service, employees 250, turnover 800.
Expected: R5 (250 > service medium max 200), R9, R10 → size large, R12 fires, assessment stops, no risk level shown.

**T8 — No current liabilities (V3)**
Same as T2 but current liabilities 0.
Expected: CR and QR not calculated; none of R13–R18 fire; note shown. Assessment otherwise completes (LOW).

**T9 — Boundary values**
- CR exactly 1.0 → R14 (not R13). CR exactly 1.5 → R15. CR exactly 3.0 → R15.
- DE exactly 2.0 → R21 (not R20). DE exactly 1.0 → R21.
- CM exactly 1.0 → R24. CM exactly 3.0 → R25.
- Largest customer exactly 10 → R26 fires.
- Turnover exactly 15 → micro; 15.5 → small; 250 → small; 250.5 → medium; 750 → medium; 750.5 → large.
- Manufacturing 300 employees → medium; service 200 → medium; service 201 → large.

### 12.2 Validation tests

- Monthly expenses 0 → V1 error.
- Inventory greater than current assets → V2 error.
- Non-numeric text in a number field → error for that field.
- Percentage 120 → error.
- Employees 3.5 → error.

### 12.3 Backward chaining tests

- **B1:** Goal `acute_liquidity_crisis` with T1's values. The engine must request exactly: current_assets, current_liabilities, cash, monthly_expenses (in a sensible order). Outcome: proven via R30 (R13 + R23).
- **B2:** Goal `risk_level(critical)` with T1's values. Tries R19 first (asks equity → fails), then R30's path (proves it). Outcome: proven. Trace shows the failed R19 branch.
- **B3:** Goal `risk_level(critical)` with T2's values. Outcome: disproven, trace shows all three branches failing.
- **B4:** Goal `critical_cash_risk` with T4's values. Asks only cash and monthly_expenses. Outcome: disproven (CM 1.67).

---

## 13. README.md (this is also the user manual section of the report)

Include:

1. What the system does (3–4 sentences) and the "not a professional audit" note.
2. Requirements: SWI-Prolog 9.x (link to swi-prolog.org download), any modern browser. No other dependencies.
3. Installation on Windows, macOS, and Linux (brief, step by step).
4. How to run: open a terminal in the folder, run `swipl main.pl`, open `http://localhost:8080`. How to use another port. How to stop (Ctrl+C, then `halt.` if needed).
5. How to use each page: full assessment, check a specific risk, reading the result, the explanation, rules and sources.
6. Example input (T1) and a short example of the output.
7. How to run the tests: `swipl -g run_tests -t halt tests.pl` (or whatever command you implement).
8. Project structure: one line per file, mapped to expert-system components.
9. Troubleshooting: port already in use, `swipl` not recognised (PATH on Windows), browser shows nothing.

---

## 14. Working process

1. Read this document and `knowledge_base.pl`. Write a short plan (files, predicates, condition language) and then proceed.
2. Build `rules.pl` and `engine.pl` (forward chaining first). Test from the Prolog top level with T1–T4.
3. Write `tests.pl` for section 12.1 and 12.2. Run them. **Fix the engine until every test passes.** Do not change expected results to make tests pass — if you think an expected result is wrong, stop and explain why.
4. Add backward chaining and its tests (12.3).
5. Build `explanation.pl`.
6. Build `web_ui.pl`, `static/style.css`, and `main.pl`. Start the server and check every page with `curl` (status 200, key text present). Submit T1, T2, T4, T5, T7 through the form with `curl -d` and confirm the result pages show the correct level and fired rules.
7. Write `README.md`.
8. Final check against the acceptance checklist below, then summarise: files created, how to run, test results, and anything the student should know or explain in the viva.

**Do not** change thresholds, limits, sources, question wording, rule logic, or expected test results. **Do not** add external dependencies.

---

## 15. Acceptance checklist

- [ ] `swipl main.pl` starts the server and prints the URL; the site works offline.
- [ ] All 39 rules implemented as data, each with sources and rating, thresholds read from facts.
- [ ] Forward chaining produces correct results for T1–T9.
- [ ] Backward chaining asks only the needed questions (B1–B4) and shows a proof trace including failed branches.
- [ ] HOW explanation shows input → ratios → facts → rules (with values, sources, ratings) → conclusion → advice.
- [ ] WHY explanation available for each backward-chaining question.
- [ ] Validation V1–V4 and type checks work, with errors next to fields and values kept.
- [ ] R12 stops the assessment for non-SMEs; R11 tie-break works.
- [ ] Rules and sources page lists all 39 rules and all sources.
- [ ] Example-fill buttons for T1, T2, T4.
- [ ] Responsive, keyboard accessible, print stylesheet, status never shown by colour alone.
- [ ] All plunit tests pass.
- [ ] README covers everything in section 13.
- [ ] Code is readable and commented for a beginner who must explain it.
