# SME Business Risk Assessment Expert System

An expert system, written in SWI-Prolog, that screens Sri Lankan small and medium enterprises (SMEs) for financial risk. The owner enters basic figures from their accounts. The system classifies the business size using the National SME Policy Framework, calculates four financial ratios and applies 39 sourced rules. It then gives an overall risk level (LOW, MODERATE, HIGH or CRITICAL) with advice. It shows every step of its reasoning: your input, the facts it derived, the rules that fired, why they fired, and which published source each rule comes from.

> **This is a general risk screening for education, not a professional financial audit.**

---

## 1. Requirements

- **SWI-Prolog 9.x or newer** from https://www.swi-prolog.org/download/stable
- Any modern web browser (Chrome, Edge, Firefox, Safari)

Nothing else is needed. The system runs fully offline, with no internet connection, external libraries, fonts or scripts.

## 2. Installation

**Windows**
1. Download the Windows 64-bit installer from the SWI-Prolog download page and run it.
2. On the "Install options" screen, choose **Add swipl to the system PATH**.
3. Open a new Command Prompt or PowerShell and check: `swipl --version`

**macOS**
1. Install with Homebrew: `brew install swi-prolog`, or download the `.dmg` from the download page.
2. Check in Terminal: `swipl --version`

**Linux (Ubuntu / Debian)**
1. `sudo apt-add-repository ppa:swi-prolog/stable && sudo apt update && sudo apt install swi-prolog`
2. Check: `swipl --version`

Then copy this project folder anywhere on your computer.

## 3. How to run

1. Open a terminal **in the project folder** (the folder that contains `main.pl`).
2. Run:
   ```
   swipl main.pl
   ```
3. You will see:
   ```
   SME Risk Expert System running at http://localhost:8080 - open this in your browser. Press Ctrl+C to stop.
   ```
4. Open **http://localhost:8080** in your browser.

**Another port:** if 8080 is in use, run `swipl main.pl 8081` and open http://localhost:8081.

**To stop:** press **Ctrl+C** in the terminal. If a `?-` prompt or an "Action?" menu appears, type `halt.` (or `e` for exit) and press Enter.

## 4. How to use the system

### Home page
Choose one of two ways to use the system:
- **Start full assessment**: answer all 14 questions and see every risk. This uses **forward chaining**.
- **Check a specific risk**: pick one question, such as "Will my cash run out within a month?", and answer only what is needed. This uses **backward chaining**.

### Full assessment (`/assess`)
- The 14 questions are grouped into four numbered sections: about the business, balance sheet, cash and profit, and customers, imports and records.
- Enter amounts in rupees. Commas are fine (`1,000,000`). Turnover is in **Rs. million**. Equity and net profit may be negative.
- To try the system quickly, use the **Fill with example** links: *Nimal's Bakery* (critical), a *healthy service business* (low) and a *busy trading shop* (high).
- Press **Assess my business**. If an answer is wrong, the form comes back with your answers kept and the problem written under that field.

### Reading the result
1. **Overall risk level**: shown in large type. Below it is a strip of the 7 risk categories (Liquidity, Debt, Cash, Customer, Exchange rate, Finance access, Profitability), each marked **Risk** or **Clear**.
2. **Business size**: micro, small or medium, and the rules that decided it. If the employee and turnover categories differ, rule R11 applies and employment decides.
3. **Advice**: each piece of advice, with the rule and source it comes from.
4. **How this was decided** (the HOW explanation), in order:
   your answers → calculated ratios → facts derived → rules applied (numbered in firing order, with the actual values, IF–THEN text, source and rating) → rules checked but not fired → conclusion.
5. **Print this report** opens the browser's print dialog. Navigation is hidden on paper.

If the business is too large to be an SME (rule R12), the report says so and gives no risk level.

### Check a specific risk (`/check`)
1. Choose a question and press **Check this risk**.
2. The system asks **one question at a time**, and only the ones it needs. Open **Why is this asked?** to see the chain of rules that led to the question.
3. The final page says **Yes - proven** or **No - not proven**. It shows the full proof trace, including branches that failed, the sources of the rules used, and how many questions were asked compared with 14.
4. **Continue with a full assessment** opens the full form with your answers already filled in.

### Rules and sources (`/rules`)
Lists all 39 rules in groups A–H, with IF–THEN text, source ids and rating, followed by the full source list. Ratings mean:
- **Direct**: the source states the rule.
- **Applied**: the source supports the rule with a small interpretation.
- **Design**: a combination designed by the knowledge engineer.

### How it works (`/about`)
Shows the architecture diagram and a short explanation of forward and backward chaining.

## 5. Example

**Input: Nimal's Bakery (test case T1)**

| Question | Answer |
|---|---|
| Sector | Manufacturing |
| Employees | 6 |
| Annual turnover | Rs. 8 million |
| Current assets | 800,000 |
| Stock / inventory | 300,000 |
| Current liabilities | 1,000,000 |
| Total liabilities | 3,000,000 |
| Owner's equity | 1,000,000 |
| Cash available now | 350,000 |
| Monthly expenses | 400,000 |
| Largest customer's share | 40% |
| Net profit last year | -50,000 |
| Imports key inputs | Yes |
| Audited statements | No |

**Output (shortened)**

```
Overall risk level: CRITICAL
7 of 7 risk categories present. R33 fired, so the overall risk level is CRITICAL.
Business size: micro (R1, R6, R10)

Ratios: current ratio 0.80, quick ratio 0.50, debt-to-equity 3.00, cash reserve months 0.88

Rules applied, in firing order:
 1. R1   Employees = 6, within the micro range 0 to 10
 2. R6   Turnover = Rs. 8 million, up to 15 (micro)
 3. R10  Employee category is micro; Turnover category is micro
 4. R13  Current ratio = 0.80 < 1.0                       [s2; s3] Direct
 5. R17  Quick ratio = 0.50 < 1.0                         [s3] Direct
 6. R20  Owner's equity > 0; Debt-to-equity = 3.00 > 2.0  [s5; s6] Direct
 7. R23  Cash reserve months = 0.88 < 1.0                 [s7] Applied
 ... R26, R27, R28, R29, R30, R31, R32
15. R33  Acute liquidity crisis (already derived)          [design] Design
16. R37  advice: build cash reserves toward 3 to 6 months
17. R38  advice: prepare audited financial statements

Rules checked but not fired:
 R39 did not fire. Met: Liquidity risk high. Not met: Profitability risk is true.
```

## 6. Running the tests

In the project folder:

```
swipl -g run_tests -t halt tests.pl
```

This runs 43 automated tests (50 including sub-cases):
- **forward**: test cases T1–T8 check the size, fired rules, risk level and advice
- **boundaries**: T9 checks exact boundary values (CR 1.0/1.5/3.0, DE 1.0/2.0, CM 1.0/3.0, customer 10%, turnover and employee bands)
- **validation**: V1, V2, non-numbers, percentage over 100, fractional employees, empty fields
- **backward**: B1–B4 check which questions were asked, the outcome and the failed branches in the trace
- **http**: starts the server on port 8095, loads every page and submits T1, T2, T4 and T5 through the form

Expected last line: `% All 43 (+7 sub-tests) tests passed`

## 7. Project structure

| File | Expert-system component | Contents |
|---|---|---|
| `main.pl` | Entry point | Loads all files and starts the web server |
| `knowledge_base.pl` | Knowledge base (facts) | Questions, thresholds, SME limits, risk categories, descriptions, advice, sources, goals |
| `rules.pl` | Knowledge base (rules) | The 39 IF–THEN rules stored as `rule/7` facts |
| `engine.pl` | Inference engine + working memory | Validation, ratios, forward chaining, backward chaining |
| `explanation.pl` | Explanation facility | HOW and WHY explanations built from the rule data |
| `web_ui.pl` | User interface | Web pages and forms |
| `static/style.css` | User interface | Page styling, including the print layout |
| `tests.pl` | Testing | plunit test cases |

## 8. Troubleshooting

| Problem | Fix |
|---|---|
| `Could not start on port 8080` / port already in use | Another program uses the port. Run `swipl main.pl 8081` and open http://localhost:8081. |
| `'swipl' is not recognized` (Windows) | SWI-Prolog is not on PATH. Reinstall and tick **Add swipl to the system PATH**, or run it with the full path: `"C:\Program Files\swipl\bin\swipl.exe" main.pl` |
| Browser shows "This site can't be reached" | Check the terminal still shows the "running at" message. Use `http://`, not `https://`, and the same port number. |
| Page looks unstyled | Make sure the `static` folder is next to `main.pl` and that you started `swipl` from the project folder. |
| `source_sink ... does not exist` when starting | The terminal is not in the project folder. `cd` into it first. |
