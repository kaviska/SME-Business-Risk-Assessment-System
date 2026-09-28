% =====================================================================
%  rules.pl
%  SME Business Risk Assessment Expert System - RULES
%
%  Part of the KNOWLEDGE BASE. The 39 IF-THEN rules are stored as data:
%
%     rule(Id, Group, Conditions, Conclusion, Sources, Rating, Text)
%
%  Because the rules are plain facts, the forward engine, the backward
%  engine and the explanation facility all read the same knowledge.
%  No number is written here - limits come from knowledge_base.pl.
%
%  Condition language (all conditions in the list must hold):
%     in(Name, Op, Limit)       user input compared with a number or a threshold name
%     answer(Name, Value)       user input equals Value (sector, yes/no)
%     ratio(Name, Op, Limit)    calculated ratio (cr, qr, de, cm) compared with a limit
%     emp_in(Cat)               employees inside employee_limit/4 for the sector
%     emp_over(Cat)             employees above the maximum of Cat for the sector
%     turnover_in(Cat)          turnover inside turnover_limit/3
%     turnover_over(Cat)        turnover above the upper limit of Cat
%     fact(F)                   F has already been derived
%     not_fact(F)               F has not been derived (negation as failure)
%     differ(A, B)              A and B are different
%     any(Conditions)           at least one of the conditions holds (OR)
%     category_count(Op, Limit) number of risk categories present
%
%  Op is one of  <  =<  >  >=
%  A ratio condition simply fails when the ratio could not be calculated.
%  Rating is direct, applied or design.
% =====================================================================

% ---------------------------------------------------------------------
% Group A - Business size (National SME Policy Framework)
% ---------------------------------------------------------------------
rule(r1, size, [emp_in(micro)], emp_category(micro), [s1], direct,
     'IF employees are within the micro limit (up to 10) THEN employee category is micro').
rule(r2, size, [emp_in(small)], emp_category(small), [s1], direct,
     'IF employees are within the small limit (11 to 50) THEN employee category is small').
rule(r3, size, [answer(sector, manufacturing), emp_in(medium)], emp_category(medium), [s1], direct,
     'IF sector is manufacturing AND employees are 51 to 300 THEN employee category is medium').
rule(r4, size, [answer(sector, service), emp_in(medium)], emp_category(medium), [s1], direct,
     'IF sector is service AND employees are 51 to 200 THEN employee category is medium').
rule(r5, size, [emp_over(medium)], emp_category(large), [s1], direct,
     'IF employees are above the medium maximum for the sector THEN employee category is large').
rule(r6, size, [turnover_in(micro)], turnover_category(micro), [s1], direct,
     'IF turnover is Rs. 15 million or less THEN turnover category is micro').
rule(r7, size, [turnover_in(small)], turnover_category(small), [s1], direct,
     'IF turnover is above Rs. 15 million and up to Rs. 250 million THEN turnover category is small').
rule(r8, size, [turnover_in(medium)], turnover_category(medium), [s1], direct,
     'IF turnover is above Rs. 250 million and up to Rs. 750 million THEN turnover category is medium').
rule(r9, size, [turnover_over(medium)], turnover_category(large), [s1], direct,
     'IF turnover is above Rs. 750 million THEN turnover category is large').
rule(r10, size, [fact(emp_category(C)), fact(turnover_category(C))], size(C), [s1], direct,
     'IF employee category and turnover category are the same THEN business size is that category').
rule(r11, size, [fact(emp_category(C)), fact(turnover_category(T)), differ(C, T)], size(C), [s1], direct,
     'IF employee category and turnover category differ THEN business size is the employee category').
rule(r12, size, [fact(size(large))], outside_sme_scope, [s1], applied,
     'IF business size is large THEN it is outside SME scope and the assessment stops').

% ---------------------------------------------------------------------
% Group B - Liquidity
% ---------------------------------------------------------------------
rule(r13, liquidity, [ratio(cr, <, current_ratio_low)],
     liquidity_risk_high, [s2, s3], direct,
     'IF current ratio < 1.0 THEN liquidity risk is high').
rule(r14, liquidity, [ratio(cr, >=, current_ratio_low), ratio(cr, <, current_ratio_healthy_min)],
     liquidity_caution, [s3], applied,
     'IF current ratio is 1.0 or more but below 1.5 THEN liquidity needs caution').
rule(r15, liquidity, [ratio(cr, >=, current_ratio_healthy_min), ratio(cr, =<, current_ratio_healthy_max)],
     liquidity_healthy, [s3], direct,
     'IF current ratio is between 1.5 and 3.0 THEN liquidity is healthy').
rule(r16, liquidity, [ratio(cr, >, current_ratio_healthy_max)],
     possible_idle_assets, [s3], applied,
     'IF current ratio > 3.0 THEN assets may be sitting idle').
rule(r17, liquidity, [ratio(qr, <, quick_ratio_min)],
     quick_liquidity_weak, [s3], direct,
     'IF quick ratio < 1.0 THEN quick liquidity is weak').
rule(r18, liquidity, [ratio(qr, >=, quick_ratio_min)],
     quick_liquidity_ok, [s3], direct,
     'IF quick ratio is 1.0 or more THEN quick liquidity is adequate').

% ---------------------------------------------------------------------
% Group C - Debt and solvency
% ---------------------------------------------------------------------
rule(r19, debt, [in(equity, =<, 0)],
     balance_sheet_insolvency, [s5, s4], applied,
     'IF owner''s equity is zero or negative THEN the balance sheet is insolvent').
rule(r20, debt, [in(equity, >, 0), ratio(de, >, debt_equity_high)],
     high_debt_risk, [s5, s6], direct,
     'IF equity is positive AND debt-to-equity > 2.0 THEN debt risk is high').
rule(r21, debt, [in(equity, >, 0), ratio(de, >=, debt_equity_manageable_min), ratio(de, =<, debt_equity_high)],
     debt_manageable, [s6], direct,
     'IF equity is positive AND debt-to-equity is between 1.0 and 2.0 THEN debt is manageable').
rule(r22, debt, [in(equity, >, 0), ratio(de, <, debt_equity_manageable_min)],
     largely_self_funded, [s6], direct,
     'IF equity is positive AND debt-to-equity < 1.0 THEN the business is largely self-funded').

% ---------------------------------------------------------------------
% Group D - Cash reserves
% ---------------------------------------------------------------------
rule(r23, cash, [ratio(cm, <, cash_months_critical)],
     critical_cash_risk, [s7], applied,
     'IF cash covers less than 1 month of expenses THEN cash risk is critical').
rule(r24, cash, [ratio(cm, >=, cash_months_critical), ratio(cm, <, cash_months_recommended)],
     cash_reserve_low, [s8], direct,
     'IF cash covers 1 month or more but less than 3 months THEN the cash reserve is low').
rule(r25, cash, [ratio(cm, >=, cash_months_recommended)],
     cash_reserve_adequate, [s8], direct,
     'IF cash covers 3 months or more THEN the cash reserve is adequate').

% ---------------------------------------------------------------------
% Group E - Other risks
% ---------------------------------------------------------------------
rule(r26, other, [in(largest_customer_pct, >=, major_customer_pct)],
     major_customer_reliance, [s9, s10], applied,
     'IF the largest customer gives 10% or more of sales THEN the business relies on a major customer').
rule(r27, other, [answer(imports, yes)],
     exchange_rate_risk, [s11, s12], applied,
     'IF key inputs are imported THEN there is exchange rate risk').
rule(r28, other, [answer(audited_statements, no)],
     finance_access_risk, [s13], direct,
     'IF there are no audited financial statements THEN access to finance is at risk').
rule(r29, other, [in(net_profit, <, 0)],
     profitability_risk, [s14], applied,
     'IF net profit is negative THEN there is a profitability risk').

% ---------------------------------------------------------------------
% Group F - Combined conditions
% ---------------------------------------------------------------------
rule(r30, combined, [fact(liquidity_risk_high), fact(critical_cash_risk)],
     acute_liquidity_crisis, [design], design,
     'IF liquidity risk is high AND cash risk is critical THEN there is an acute liquidity crisis').
rule(r31, combined, [fact(high_debt_risk), fact(profitability_risk)],
     debt_distress, [design], design,
     'IF debt risk is high AND the business made a loss THEN the business is in debt distress').
rule(r32, combined, [fact(finance_access_risk), any([fact(liquidity_risk_high), fact(critical_cash_risk)])],
     refinancing_difficulty, [design], design,
     'IF finance access is at risk AND (liquidity risk is high OR cash risk is critical) THEN refinancing will be difficult').

% ---------------------------------------------------------------------
% Group G - Overall risk level
% ---------------------------------------------------------------------
rule(r33, risk_level,
     [any([fact(balance_sheet_insolvency), fact(acute_liquidity_crisis), fact(debt_distress)])],
     risk_level(critical), [design], design,
     'IF balance sheet insolvency OR acute liquidity crisis OR debt distress THEN risk level is CRITICAL').
rule(r34, risk_level,
     [not_fact(risk_level(critical)), category_count(>=, high_risk_min_categories)],
     risk_level(high), [design], design,
     'IF not critical AND 4 or more risk categories are present THEN risk level is HIGH').
rule(r35, risk_level,
     [not_fact(risk_level(critical)), category_count(>=, moderate_risk_min_categories),
      category_count(<, high_risk_min_categories)],
     risk_level(moderate), [design], design,
     'IF not critical AND 2 or 3 risk categories are present THEN risk level is MODERATE').
rule(r36, risk_level,
     [not_fact(risk_level(critical)), category_count(<, moderate_risk_min_categories)],
     risk_level(low), [design], design,
     'IF not critical AND 0 or 1 risk categories are present THEN risk level is LOW').

% ---------------------------------------------------------------------
% Group H - Advice
% ---------------------------------------------------------------------
rule(r37, advice, [any([fact(critical_cash_risk), fact(cash_reserve_low)])],
     advice(r37), [s8], direct,
     'IF cash risk is critical OR the cash reserve is low THEN advise building cash reserves toward 3 to 6 months').
rule(r38, advice, [fact(finance_access_risk)],
     advice(r38), [s13], applied,
     'IF access to finance is at risk THEN advise preparing audited financial statements').
rule(r39, advice, [fact(liquidity_risk_high), not_fact(profitability_risk)],
     advice(r39), [s3], applied,
     'IF liquidity risk is high AND the business is profitable THEN advise short-term financing backed by long-term prospects').

% Display information for each group (letter and title on the rules page).
group_info(size,       'A', 'Business size').
group_info(liquidity,  'B', 'Liquidity').
group_info(debt,       'C', 'Debt and solvency').
group_info(cash,       'D', 'Cash reserves').
group_info(other,      'E', 'Other risks').
group_info(combined,   'F', 'Combined conditions').
group_info(risk_level, 'G', 'Overall risk level').
group_info(advice,     'H', 'Advice').
