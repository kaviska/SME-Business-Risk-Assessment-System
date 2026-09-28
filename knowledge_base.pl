% =====================================================================
%  knowledge_base.pl
%  SME Business Risk Assessment Expert System - FACTS
%
%  This file holds the domain knowledge as FACTS only.
%  The IF-THEN rules live in rules.pl.
%  Keeping facts separate means a threshold can be changed here
%  without touching any rule.
% =====================================================================

% ---------------------------------------------------------------------
% 1. QUESTIONS asked to the user
%    question(Id, Text, AnswerType)
%    AnswerType: number | yes_no | choice(ListOfOptions)
%    The user interface (console and GUI) reads these facts.
% ---------------------------------------------------------------------
question(q0,  'Is your business manufacturing or service?',
              choice([manufacturing, service])).
question(q1,  'How many employees does the business have?', number).
question(q2,  'What is the annual turnover (Rs. million)?', number).
question(q3,  'What is the total value of current assets (cash, stock, money customers owe you) in Rs.?', number).
question(q4,  'What is the value of stock / inventory in Rs.?', number).
question(q5,  'What is the total of current liabilities (bills and debts due within one year) in Rs.?', number).
question(q6,  'What is the total of all liabilities (short-term + long-term) in Rs.?', number).
question(q7,  'What is the owner''s equity (assets minus liabilities) in Rs.?', number).
question(q8,  'How much cash does the business have available now (Rs.)?', number).
question(q9,  'What are the average monthly operating expenses (Rs.)?', number).
question(q10, 'What percentage of sales comes from your single largest customer (0-100)?', number).
question(q11, 'What was last year''s net profit in Rs.? (enter a negative number for a loss)', number).
question(q12, 'Are key raw materials or products imported?', yes_no).
question(q13, 'Does the business keep audited financial statements?', yes_no).

% Short names used inside the program for each question
input_name(q0,  sector).
input_name(q1,  employees).
input_name(q2,  turnover).
input_name(q3,  current_assets).
input_name(q4,  inventory).
input_name(q5,  current_liabilities).
input_name(q6,  total_liabilities).
input_name(q7,  equity).
input_name(q8,  cash).
input_name(q9,  monthly_expenses).
input_name(q10, largest_customer_pct).
input_name(q11, net_profit).
input_name(q12, imports).
input_name(q13, audited_statements).

% ---------------------------------------------------------------------
% 2. THRESHOLDS used by the rules
%    threshold(Name, Value)
% ---------------------------------------------------------------------
threshold(current_ratio_low,          1.0).   % R13  [2],[3]
threshold(current_ratio_healthy_min,  1.5).   % R14, R15  [3]
threshold(current_ratio_healthy_max,  3.0).   % R15, R16  [3]
threshold(quick_ratio_min,            1.0).   % R17, R18  [3]
threshold(debt_equity_manageable_min, 1.0).   % R21, R22  [6]
threshold(debt_equity_high,           2.0).   % R20  [5],[6]
threshold(cash_months_critical,       1.0).   % R23  [7]
threshold(cash_months_recommended,    3.0).   % R24, R25  [8]
threshold(major_customer_pct,         10).    % R26  [9],[10]
threshold(high_risk_min_categories,   4).     % R34  (design)
threshold(moderate_risk_min_categories, 2).   % R35  (design)

% ---------------------------------------------------------------------
% 3. SME SIZE LIMITS  (Source [1]: National SME Policy Framework)
%    employee_limit(Sector, Category, Min, Max)
%    turnover_limit(Category, LowerExclusive, UpperInclusive)  Rs. million
% ---------------------------------------------------------------------
employee_limit(manufacturing, micro,  0,  10).
employee_limit(manufacturing, small,  11, 50).
employee_limit(manufacturing, medium, 51, 300).
employee_limit(service,       micro,  0,  10).
employee_limit(service,       small,  11, 50).
employee_limit(service,       medium, 51, 200).

turnover_limit(micro,  -1,  15).     % 0 to 15 (inclusive)
turnover_limit(small,  15,  250).    % above 15, up to 250
turnover_limit(medium, 250, 750).    % above 250, up to 750

% ---------------------------------------------------------------------
% 4. RISK CATEGORIES used to calculate the overall risk level (Group G)
%    Each category counts ONCE even if several of its facts are true.
%    risk_category(CategoryName, ListOfFactsInThatCategory)
% ---------------------------------------------------------------------
risk_category(liquidity,      [liquidity_risk_high, liquidity_caution, quick_liquidity_weak]).
risk_category(debt,           [high_debt_risk]).
risk_category(cash,           [critical_cash_risk, cash_reserve_low]).
risk_category(customer,       [major_customer_reliance]).
risk_category(exchange_rate,  [exchange_rate_risk]).
risk_category(finance_access, [finance_access_risk]).
risk_category(profitability,  [profitability_risk]).

% ---------------------------------------------------------------------
% 5. DESCRIPTIONS of each derived fact (shown in the results)
%    description(Fact, PlainEnglishText)
% ---------------------------------------------------------------------
description(liquidity_risk_high,
    'Current liabilities exceed current assets; short-term bills may not be payable.').
description(liquidity_caution,
    'Current ratio is below the healthy range of 1.5 to 3; limited safety buffer.').
description(liquidity_healthy,
    'Current ratio is within the healthy range of 1.5 to 3.').
description(possible_idle_assets,
    'Current ratio above 3; cash or stock may not be used efficiently.').
description(quick_liquidity_weak,
    'Without stock, liquid assets cannot cover short-term liabilities.').
description(quick_liquidity_ok,
    'Liquid assets (excluding stock) can cover short-term liabilities.').
description(balance_sheet_insolvency,
    'Owner''s equity is zero or negative; liabilities equal or exceed assets.').
description(high_debt_risk,
    'Debt is more than twice the owner''s equity; the business relies heavily on borrowing.').
description(debt_manageable,
    'Debt-to-equity is between 1 and 2, typically manageable for a small business.').
description(largely_self_funded,
    'Debt-to-equity is below 1; the business is mostly funded by the owner.').
description(critical_cash_risk,
    'Cash covers less than one month of operating expenses.').
description(cash_reserve_low,
    'Cash covers 1 to 3 months of expenses; below the recommended 3 to 6 months.').
description(cash_reserve_adequate,
    'Cash covers 3 or more months of operating expenses.').
description(major_customer_reliance,
    'One customer provides 10% or more of sales; losing them would hurt the business.').
description(exchange_rate_risk,
    'Imported inputs expose costs to rupee depreciation.').
description(finance_access_risk,
    'Without audited financial statements, getting bank finance is harder.').
description(profitability_risk,
    'The business made a loss last year.').
description(acute_liquidity_crisis,
    'Short-term bills exceed current assets AND cash lasts less than a month.').
description(debt_distress,
    'Heavy borrowing combined with losses; debt may become hard to service.').
description(refinancing_difficulty,
    'Needs short-term funds but lacks the audited statements banks usually require.').

% ---------------------------------------------------------------------
% 6. ADVICE text for the advice rules (Group H)
%    advice_text(RuleId, Text)
% ---------------------------------------------------------------------
advice_text(r37, 'Build cash reserves toward 3 to 6 months of operating expenses.').
advice_text(r38, 'Prepare audited financial statements to improve access to bank finance.').
advice_text(r39, 'The business is profitable, so short-term financing backed by its long-term prospects may bridge the liquidity gap.').

% ---------------------------------------------------------------------
% 7. SOURCES (references for every rule)
%    source(Id, ShortCitation)
% ---------------------------------------------------------------------
source(s1,  'Ministry of Industry and Commerce, Sri Lanka - National Policy Framework for SME Development').
source(s2,  'Association of Corporate Treasurers - ACT Wiki: Current ratio').
source(s3,  'Saylor Academy - Liquidity Ratios').
source(s4,  'Companies Act No. 7 of 2007 (Sri Lanka), s.57; Nanayakkara (2021)').
source(s5,  'Xero - Debt-to-equity ratio guide').
source(s6,  'Funding Circle UK - Small business debt-to-equity ratio').
source(s7,  'JPMorgan Chase Institute (2016) - Cash is King: Flows, Balances, and Buffer Days').
source(s8,  'SCORE - How Much Cash Should a Small Business Keep in Reserve?').
source(s9,  'IFRS 8 Operating Segments, paragraph 34').
source(s10, 'Dhaliwal, Judd, Serfling & Shaikh (2016), Journal of Accounting and Economics 61(1)').
source(s11, 'Central Bank of Sri Lanka (2022) - Recent Economic Developments: Highlights of 2022').
source(s12, 'National Chamber of Exporters of Sri Lanka (2026)').
source(s13, 'Gamage (2013), Corporate Ownership & Control 10(3-3), 402-409').
source(s14, 'Altman (1968), Journal of Finance 23(4), 589-609').
source(design, 'Knowledge engineer design, inspired by the multi-factor principle (Altman, 1968)').

% ---------------------------------------------------------------------
% 8. BACKWARD-CHAINING GOALS the user can ask about
%    goal_option(Goal, LabelShownToUser)
% ---------------------------------------------------------------------
goal_option(risk_level(critical),  'Is my business at CRITICAL risk?').
goal_option(acute_liquidity_crisis,'Is my business in a liquidity crisis?').
goal_option(debt_distress,         'Is my business in debt distress?').
goal_option(critical_cash_risk,    'Will my cash run out within a month?').