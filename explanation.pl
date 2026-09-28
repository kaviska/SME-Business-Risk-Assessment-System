:- encoding(utf8).
% =====================================================================
%  explanation.pl
%  SME Business Risk Assessment Expert System - EXPLANATION FACILITY
%
%  Turns what the inference engine recorded (fired rules, evidence,
%  proof traces) into plain-English sentences.
%    HOW : how_step/2, near_miss_text/2, conclusion_text/2
%    WHY : why_text/3 (why a question is asked in backward chaining)
%  Every sentence is built from the rule data in rules.pl, so there is
%  no hand-written text for particular test cases.
% =====================================================================

% ---------------------------------------------------------------------
% Names shown to the user
% ---------------------------------------------------------------------
input_label(sector,               'Sector').
input_label(employees,            'Employees').
input_label(turnover,             'Annual turnover').
input_label(current_assets,       'Current assets').
input_label(inventory,            'Stock / inventory').
input_label(current_liabilities,  'Current liabilities').
input_label(total_liabilities,    'Total liabilities').
input_label(equity,               'Owner''s equity').
input_label(cash,                 'Cash available now').
input_label(monthly_expenses,     'Monthly operating expenses').
input_label(largest_customer_pct, 'Largest customer''s share of sales').
input_label(net_profit,           'Net profit last year').
input_label(imports,              'Imports key inputs').
input_label(audited_statements,   'Audited financial statements').

ratio_label(cr, 'Current ratio').
ratio_label(qr, 'Quick ratio').
ratio_label(de, 'Debt-to-equity').
ratio_label(cm, 'Cash reserve months').

ratio_formula(cr, 'Current assets ÷ current liabilities').
ratio_formula(qr, '(Current assets − stock) ÷ current liabilities').
ratio_formula(de, 'Total liabilities ÷ owner''s equity').
ratio_formula(cm, 'Cash ÷ monthly expenses').

not_applicable_reason(cr, 'No short-term liabilities, so liquidity ratios do not apply.').
not_applicable_reason(qr, 'No short-term liabilities, so liquidity ratios do not apply.').
not_applicable_reason(de, 'Not applicable: equity is zero or negative.').
not_applicable_reason(cm, 'Monthly expenses must be more than 0.').

category_label(liquidity,      'Liquidity').
category_label(debt,           'Debt').
category_label(cash,           'Cash').
category_label(customer,       'Customer').
category_label(exchange_rate,  'Exchange rate').
category_label(finance_access, 'Finance access').
category_label(profitability,  'Profitability').

rating_label(direct,  'Direct').
rating_label(applied, 'Applied').
rating_label(design,  'Design').

op_text(<,  '<').
op_text(=<, '≤').
op_text(>,  '>').
op_text(>=, '≥').

rule_label(Id, Label) :- upcase_atom(Id, Label).

level_label(Level, Label) :- upcase_atom(Level, Label).

% fact_name(+Fact, -Text)  e.g. liquidity_risk_high -> 'Liquidity risk high'
fact_name(size(C), T)              :- !, format(atom(T), 'Business size is ~w', [C]).
fact_name(emp_category(C), T)      :- !, format(atom(T), 'Employee category is ~w', [C]).
fact_name(turnover_category(C), T) :- !, format(atom(T), 'Turnover category is ~w', [C]).
fact_name(risk_level(L), T)        :- !, level_label(L, U), format(atom(T), 'Risk level is ~w', [U]).
fact_name(advice(Id), T)           :- !, rule_label(Id, R), format(atom(T), 'Advice ~w is given', [R]).
fact_name(outside_sme_scope, 'Outside SME scope') :- !.
fact_name(F, T) :-
    atomic_list_concat(Words, '_', F),
    atomic_list_concat(Words, ' ', Spaced),
    capitalise(Spaced, T).

capitalise(Text, Cap) :-
    sub_atom(Text, 0, 1, _, First),
    sub_atom(Text, 1, _, 0, Rest),
    upcase_atom(First, Up),
    atom_concat(Up, Rest, Cap).

% ---------------------------------------------------------------------
% Numbers
% ---------------------------------------------------------------------
number_text(V, T) :- integer(V), !, format(atom(T), '~D', [V]).
number_text(V, T) :- V =:= round(V), abs(V) >= 1000, !, I is round(V), format(atom(T), '~D', [I]).
number_text(V, T) :- V =:= round(V), !, format(atom(T), '~1f', [V]).
number_text(V, T) :- format(atom(T), '~2f', [V]).

ratio_text(V, T) :- format(atom(T), '~2f', [V]).

money_input(Name) :-
    memberchk(Name, [current_assets, inventory, current_liabilities, total_liabilities,
                     equity, cash, monthly_expenses, net_profit]).

% value_text(+InputName, +Value, -Text)  adds units: Rs., million, %
value_text(Name, V, T) :- money_input(Name), !, number_text(V, N), format(atom(T), 'Rs. ~w', [N]).
value_text(turnover, V, T) :- !, number_text(V, N), format(atom(T), 'Rs. ~w million', [N]).
value_text(largest_customer_pct, V, T) :- !, number_text(V, N), format(atom(T), '~w%', [N]).
value_text(_, V, T) :- number(V), !, number_text(V, T).
value_text(_, V, V).

% ---------------------------------------------------------------------
% Evidence -> text
% ---------------------------------------------------------------------

% evidence_text(+Evidence, -Text)  for a condition that held
evidence_text(cmp(What, V, Op, L), T) :-
    subject_text(What, V, Label, VT),
    op_text(Op, O), number_text(L, LT),
    format(atom(T), '~w = ~w ~w ~w', [Label, VT, O, LT]).
evidence_text(answer(Name, V), T) :-
    input_label(Name, Label),
    format(atom(T), '~w = ~w', [Label, V]).
evidence_text(emp_in(Cat, E, Min, Max), T) :-
    format(atom(T), 'Employees = ~w, within the ~w range ~w to ~w', [E, Cat, Min, Max]).
evidence_text(emp_over(Cat, E, Max), T) :-
    format(atom(T), 'Employees = ~w, above the ~w maximum of ~w', [E, Cat, Max]).
evidence_text(turnover_in(Cat, V, Low, High), T) :-
    number_text(V, VT),
    (   Low < 0
    ->  format(atom(T), 'Turnover = Rs. ~w million, up to ~w (~w)', [VT, High, Cat])
    ;   format(atom(T), 'Turnover = Rs. ~w million, above ~w and up to ~w (~w)', [VT, Low, High, Cat])
    ).
evidence_text(turnover_over(Cat, V, High), T) :-
    number_text(V, VT),
    format(atom(T), 'Turnover = Rs. ~w million, above the ~w maximum of ~w', [VT, Cat, High]).
evidence_text(fact(F), T) :-
    fact_name(F, N), format(atom(T), '~w (already derived)', [N]).
evidence_text(not_fact(F), T) :-
    fact_name(F, N), format(atom(T), 'Not true: ~w', [N]).
evidence_text(differ(A, B), T) :-
    format(atom(T), 'Employee category (~w) differs from turnover category (~w), so employment decides', [A, B]).
evidence_text(any(Ev), T) :-
    evidence_text(Ev, T).
evidence_text(count(N, Op, L), T) :-
    op_text(Op, O),
    format(atom(T), 'Risk categories present = ~w ~w ~w', [N, O, L]).
evidence_text(not_applicable(R), T) :-
    ratio_label(R, Label),
    not_applicable_reason(R, Why),
    format(atom(T), '~w: ~w', [Label, Why]).

subject_text(input(Name), V, Label, VT) :- input_label(Name, Label), value_text(Name, V, VT).
subject_text(ratio(R), V, Label, VT)    :- ratio_label(R, Label), ratio_text(V, VT).

% condition_text(+Condition, -Text)  describes what a condition asks for
condition_text(in(Name, Op, Limit), T) :-
    input_label(Name, Label), op_text(Op, O), limit_value(Limit, L), number_text(L, LT),
    format(atom(T), '~w ~w ~w', [Label, O, LT]).
condition_text(ratio(R, Op, Limit), T) :-
    ratio_label(R, Label), op_text(Op, O), limit_value(Limit, L), number_text(L, LT),
    format(atom(T), '~w ~w ~w', [Label, O, LT]).
condition_text(answer(Name, V), T) :-
    input_label(Name, Label), format(atom(T), '~w = ~w', [Label, V]).
condition_text(fact(F), T) :- fact_name(F, T).
condition_text(not_fact(F), T) :- fact_name(F, N), format(atom(T), 'NOT ~w', [N]).
condition_text(any(Cs), T) :-
    maplist(condition_text, Cs, Ts),
    atomic_list_concat(Ts, ' OR ', T).
condition_text(C, T) :- format(atom(T), '~w', [C]).

% Why a condition was not met (used for rules that did not fire).
unmet_text(fact(F), T)     :- !, fact_name(F, N), format(atom(T), '~w is not true', [N]).
unmet_text(not_fact(F), T) :- !, fact_name(F, N), format(atom(T), '~w is true', [N]).
unmet_text(any(Cs), T)     :- !, condition_text(any(Cs), C), format(atom(T), 'none of: ~w', [C]).
unmet_text(C, T)           :- condition_text(C, N), format(atom(T), 'not met: ~w', [N]).

% ---------------------------------------------------------------------
% HOW - forward chaining
% ---------------------------------------------------------------------

% how_step(+Fired, -Step)
%   step(Number, RuleLabel, GroupTitle, IfThen, Because, Sources, Rating, Adds)
how_step(fired(N, Id, Conclusion, Evidence),
         step(N, Label, GroupTitle, Text, Because, Sources, Rating, Adds)) :-
    rule(Id, Group, _, _, SourceIds, RatingId, Text),
    rule_label(Id, Label),
    group_info(Group, Letter, Title),
    format(atom(GroupTitle), '~w. ~w', [Letter, Title]),
    maplist(evidence_text, Evidence, Because),
    maplist(source_text, SourceIds, Sources),
    rating_label(RatingId, Rating),
    fact_name(Conclusion, Adds).

source_text(Id, Text) :-
    source(Id, Citation),
    format(atom(Text), '[~w] ~w', [Id, Citation]).

near_miss_text(not_fired(Id, Met, Unmet), Text) :-
    rule_label(Id, Label),
    maplist(evidence_text, Met, MetTexts),
    maplist(unmet_text, Unmet, UnmetTexts),
    atomic_list_concat(MetTexts, '; ', M),
    atomic_list_concat(UnmetTexts, '; ', U),
    format(atom(Text), '~w did not fire. Met: ~w. Not met: ~w.', [Label, M, U]).

conclusion_text(Fired, Level, Text) :-
    member(fired(_, Id, risk_level(Level), _), Fired), !,
    rule_label(Id, Label),
    level_label(Level, L),
    format(atom(Text), '~w fired, so the overall risk level is ~w.', [Label, L]).

% ---------------------------------------------------------------------
% WHY - backward chaining
% ---------------------------------------------------------------------

% why_text(+InputName, +RuleIds, -Text)
%   RuleIds runs from the goal the user picked down to the rule that
%   needs this input, e.g. [r30, r13] for current liabilities.
why_text(Name, [First|Rest], Text) :-
    rule(First, _, _, Goal, _, _, FirstText),
    fact_name(Goal, GoalName),
    rule_label(First, FirstLabel),
    format(atom(Start),
           'This question is asked because the system is trying to prove "~w" using rule ~w (~w)',
           [GoalName, FirstLabel, FirstText]),
    maplist(why_link, Rest, Links),
    input_label(Name, InputLabel),
    downcase_atom(InputLabel, Input),
    format(atom(End), ', which needs ~w.', [Input]),
    atomic_list_concat([Start|Links], '', Middle),
    atom_concat(Middle, End, Text).

why_link(Id, Text) :-
    rule(Id, _, _, _, _, _, RuleText),
    rule_label(Id, Label),
    format(atom(Text), ', which needs ~w (~w)', [Label, RuleText]).

% trace_tree(+Trace, -Tree)
%   Converts the proof trace into node(Text, Status, Children) so the web
%   page can show it as nested lists. Failed branches are kept.
trace_tree(goal(Goal, Status, Tries), node(Text, Status, Children)) :-
    fact_name(Goal, Name),
    goal_word(Status, Word),
    format(atom(Text), 'Goal: ~w - ~w', [Name, Word]),
    maplist(try_tree, Tries, Children).

try_tree(try(Id, Checks, Status), node(Text, Status, Children)) :-
    rule(Id, _, _, _, _, _, RuleText),
    rule_label(Id, Label),
    rule_word(Status, Word),
    format(atom(Text), 'Tried ~w: ~w - ~w', [Label, RuleText, Word]),
    maplist(check_tree, Checks, Children).

check_tree(check(fact(_), _, Sub), Tree) :- !,
    trace_tree(Sub, Tree).
check_tree(check(not_fact(F), Status, negation(Sub)), node(Text, Status, [Tree])) :- !,
    fact_name(F, Name),
    format(atom(Text), 'Needs NOT ~w', [Name]),
    trace_tree(Sub, Tree).
check_tree(check(any(_), Status, any(Checks)), node('At least one of these must be true', Status, Children)) :- !,
    maplist(check_tree, Checks, Children).
check_tree(check(C, Status, Ev), node(Text, Status, [])) :-
    check_text(C, Status, Ev, Text).

check_text(_, _, not_applicable(R), Text) :- !,
    evidence_text(not_applicable(R), Text).
check_text(answer(Name, Wanted), Status, answer(Name, V), Text) :- !,
    input_label(Name, Label),
    (   Status == true
    ->  format(atom(Text), '~w = ~w - holds', [Label, V])
    ;   format(atom(Text), '~w = ~w, needs ~w - fails', [Label, V, Wanted])
    ).
check_text(_, Status, cmp(What, V, Op, L), Text) :- !,
    subject_text(What, V, Label, VT),
    op_text(Op, O), number_text(L, LT),
    (   Status == true
    ->  format(atom(Text), '~w = ~w ~w ~w - holds', [Label, VT, O, LT])
    ;   format(atom(Text), '~w = ~w, not ~w ~w - fails', [Label, VT, O, LT])
    ).
check_text(C, _, _, Text) :-
    condition_text(C, Text).

goal_word(true, proven).
goal_word(false, 'not proven').
rule_word(true, succeeded).
rule_word(false, failed).

% Every rule id used anywhere in a proof trace (for the sources list).
trace_rules(Trace, Ids) :-
    findall(Id, sub_term(try(Id, _, _), Trace), Ids0),
    sort(Ids0, Ids).
