% =====================================================================
%  tests.pl
%  Automated test cases (plunit) for the SME risk expert system.
%
%  Run with:   swipl -g run_tests -t halt tests.pl
%
%  The engine is called directly, not through the web pages. A few HTTP
%  smoke tests at the end start the server on port 8095 and load pages.
% =====================================================================

:- ensure_loaded(knowledge_base).
:- ensure_loaded(rules).
:- ensure_loaded(engine).
:- ensure_loaded(explanation).
:- ensure_loaded(web_ui).

:- use_module(library(plunit)).
:- use_module(library(http/http_open)).

% ---------------------------------------------------------------------
% Test data (section 12.1 of the specification)
% ---------------------------------------------------------------------
case(t1, [sector-manufacturing, employees-6, turnover-8,
          current_assets-800000, inventory-300000, current_liabilities-1000000,
          total_liabilities-3000000, equity-1000000, cash-350000,
          monthly_expenses-400000, largest_customer_pct-40, net_profit-(-50000),
          imports-yes, audited_statements-no]).
case(t2, [sector-service, employees-25, turnover-120,
          current_assets-5000000, inventory-1000000, current_liabilities-2500000,
          total_liabilities-3000000, equity-6000000, cash-3000000,
          monthly_expenses-800000, largest_customer_pct-8, net_profit-2000000,
          imports-no, audited_statements-yes]).
case(t3, [sector-manufacturing, employees-45, turnover-200,
          current_assets-4000000, inventory-2500000, current_liabilities-3000000,
          total_liabilities-5000000, equity-3000000, cash-1500000,
          monthly_expenses-1000000, largest_customer_pct-5, net_profit-500000,
          imports-no, audited_statements-yes]).
case(t4, [sector-service, employees-8, turnover-12,
          current_assets-900000, inventory-100000, current_liabilities-1000000,
          total_liabilities-2500000, equity-1000000, cash-500000,
          monthly_expenses-300000, largest_customer_pct-60, net_profit-100000,
          imports-yes, audited_statements-yes]).
case(t5, [sector-manufacturing, employees-15, turnover-40,
          current_assets-2000000, inventory-500000, current_liabilities-1000000,
          total_liabilities-6000000, equity-(-500000), cash-1200000,
          monthly_expenses-300000, largest_customer_pct-5, net_profit-50000,
          imports-no, audited_statements-yes]).

% T2 with some answers replaced.
variant(Changes, Inputs) :-
    case(t2, Base),
    foldl(replace, Changes, Base, Inputs).

replace(Name-Value, In, Out) :-
    selectchk(Name-_, In, Rest),
    Out = [Name-Value|Rest].

run(Inputs, Result) :- assess(Inputs, Result).

fired_ids(result(_, _, _, _, Fired, _, _, _, _, _), Ids) :-
    findall(Id, member(fired(_, Id, _, _), Fired), Ids).

level(result(_, _, _, _, _, Level, _, _, _, _), Level).
size_of(result(Size, _, _, _, _, _, _, _, _, _), Size).
advice(result(_, _, _, _, _, _, _, Advice, _, _), Advice).
ratio(result(_, _, Ratios, _, _, _, _, _, _, _), R, V) :- memberchk(R-V, Ratios).

has_fired(Result, Ids) :- fired_ids(Result, F), subtract(Ids, F, []).
not_fired(Result, Ids) :- fired_ids(Result, F), intersection(Ids, F, []).

close_to(X, Y) :- abs(X - Y) < 0.005.

has_term(X, Term) :- once(sub_term(X, Term)).
contains(Text, Part) :- once(sub_string(Text, _, _, _, Part)).

% ---------------------------------------------------------------------
% Forward chaining
% ---------------------------------------------------------------------
:- begin_tests(forward).

test(t1_nimals_bakery_critical) :-
    case(t1, I), run(I, R),
    size_of(R, micro),
    ratio(R, cr, CR), close_to(CR, 0.80),
    ratio(R, qr, QR), close_to(QR, 0.50),
    ratio(R, de, DE), close_to(DE, 3.00),
    ratio(R, cm, CM), close_to(CM, 0.875),
    has_fired(R, [r1, r6, r10, r13, r17, r20, r23, r26, r27, r28, r29,
                  r30, r31, r32, r33, r37, r38]),
    not_fired(R, [r39]),
    level(R, critical),
    advice(R, Advice), msort(Advice, [r37, r38]).

test(t1_firing_order) :-
    case(t1, I), run(I, R),
    fired_ids(R, Ids),
    assertion(Ids == [r1, r6, r10, r13, r17, r20, r23, r26, r27, r28, r29,
                      r30, r31, r32, r33, r37, r38]).

test(t2_healthy_low) :-
    case(t2, I), run(I, R),
    size_of(R, small),
    has_fired(R, [r2, r7, r10, r15, r18, r22, r25, r36]),
    level(R, low),
    R = result(_, _, _, _, _, _, [], _, _, _),
    advice(R, []).

test(t3_moderate) :-
    case(t3, I), run(I, R),
    size_of(R, small),
    has_fired(R, [r14, r17, r21, r24, r35]),
    R = result(_, _, _, _, _, _, Cats, _, _, _),
    msort(Cats, [cash, liquidity]),
    level(R, moderate),
    advice(R, [r37]).

test(t4_high_not_critical) :-
    case(t4, I), run(I, R),
    size_of(R, micro),
    has_fired(R, [r13, r17, r20, r24, r26, r27, r34, r37, r39]),
    not_fired(R, [r30, r31, r32, r33]),
    R = result(_, _, _, _, _, _, Cats, _, _, _),
    length(Cats, 5),
    level(R, high),
    advice(R, Advice), msort(Advice, [r37, r39]).

test(t5_negative_equity) :-
    case(t5, I), run(I, R),
    size_of(R, small),
    has_fired(R, [r15, r18, r19, r25, r33]),
    not_fired(R, [r20, r21, r22]),
    \+ ratio(R, de, _),
    R = result(_, _, _, _, _, _, _, _, Notes, _),
    memberchk(no_positive_equity, Notes),
    level(R, critical).

test(t6_size_tie_break) :-
    variant([employees-40, turnover-900], I), run(I, R),
    has_fired(R, [r2, r9, r11]),
    not_fired(R, [r10, r12]),
    size_of(R, small),
    level(R, low).

test(t7_outside_sme_scope) :-
    variant([sector-service, employees-250, turnover-800], I), run(I, R),
    has_fired(R, [r5, r9, r10, r12]),
    R = result(large, yes, _, _, Fired, none, _, _, _, _),
    last(Fired, fired(_, r12, _, _)).

test(t8_no_current_liabilities) :-
    variant([current_liabilities-0], I), run(I, R),
    \+ ratio(R, cr, _), \+ ratio(R, qr, _),
    not_fired(R, [r13, r14, r15, r16, r17, r18]),
    R = result(_, _, _, _, _, _, _, _, Notes, _),
    memberchk(no_current_liabilities, Notes),
    level(R, low).

:- end_tests(forward).

% ---------------------------------------------------------------------
% Boundary values (T9)
% ---------------------------------------------------------------------
:- begin_tests(boundaries).

test(cr_exactly_1_0)  :- variant([current_assets-2500000], I), run(I, R), has_fired(R, [r14]), not_fired(R, [r13]).
test(cr_exactly_1_5)  :- variant([current_assets-3750000], I), run(I, R), has_fired(R, [r15]), not_fired(R, [r14]).
test(cr_exactly_3_0)  :- variant([current_assets-7500000], I), run(I, R), has_fired(R, [r15]), not_fired(R, [r16]).
test(de_exactly_2_0)  :- variant([total_liabilities-12000000], I), run(I, R), has_fired(R, [r21]), not_fired(R, [r20]).
test(de_exactly_1_0)  :- variant([total_liabilities-6000000], I), run(I, R), has_fired(R, [r21]), not_fired(R, [r22]).
test(cm_exactly_1_0)  :- variant([cash-800000], I), run(I, R), has_fired(R, [r24]), not_fired(R, [r23]).
test(cm_exactly_3_0)  :- variant([cash-2400000], I), run(I, R), has_fired(R, [r25]), not_fired(R, [r24]).
test(customer_exactly_10) :- variant([largest_customer_pct-10], I), run(I, R), has_fired(R, [r26]).

test(turnover_bands, [forall(member(T-Rule, [15-r6, 15.5-r7, 250-r7, 250.5-r8, 750-r8, 750.5-r9]))]) :-
    variant([turnover-T], I), run(I, R),
    has_fired(R, [Rule]).

test(employee_bands, [forall(member(S-E-Rule, [manufacturing-300-r3, service-200-r4, service-201-r5]))]) :-
    variant([sector-S, employees-E], I), run(I, R),
    has_fired(R, [Rule]).

:- end_tests(boundaries).

% ---------------------------------------------------------------------
% Validation (section 12.2)
% ---------------------------------------------------------------------
:- begin_tests(validation).

as_text(Name-Value, Name-Text) :- format(atom(Text), '~w', [Value]).

form_with(Changes, Errors) :-
    variant(Changes, Inputs),
    maplist(as_text, Inputs, Pairs),
    validate_form(Pairs, _, Errors).

test(valid_form) :- form_with([], []).
test(commas_accepted) :-
    case(t2, I), maplist(as_text, I, P0),
    replace(current_assets-'5,000,000', P0, P),
    validate_form(P, Inputs, []),
    memberchk(current_assets-5000000, Inputs).
test(v1_zero_expenses)     :- form_with([monthly_expenses-0], E), memberchk(monthly_expenses-_, E).
test(v2_stock_over_assets) :- form_with([inventory-6000000], E), memberchk(inventory-_, E).
test(not_a_number)         :- form_with([cash-abc], E), memberchk(cash-_, E).
test(percent_over_100)     :- form_with([largest_customer_pct-120], E), memberchk(largest_customer_pct-_, E).
test(fractional_employees) :- form_with([employees-3.5], E), memberchk(employees-_, E).
test(negative_equity_allowed) :- form_with([equity-(-100)], []).
test(empty_field)          :- form_with([cash-''], E), memberchk(cash-_, E).

:- end_tests(validation).

% ---------------------------------------------------------------------
% Backward chaining (section 12.3)
% ---------------------------------------------------------------------
:- begin_tests(backward).

% Plays the role of the user: answers each question from a test case
% and records which questions the engine asked.
ask_until_done(Goal, Case, Asked, Outcome) :-
    case(Case, All),
    ask_loop(Goal, All, [], Asked, Outcome).

ask_loop(Goal, All, Known, Asked, Outcome) :-
    prove_goal(Goal, Known, O),
    (   O = need_input(Name, _)
    ->  memberchk(Name-V, All),
        append(Known, [Name-V], Known1),
        Asked = [Name|Asked1],
        ask_loop(Goal, All, Known1, Asked1, Outcome)
    ;   Asked = [], Outcome = O
    ).

test(b1_acute_liquidity_crisis) :-
    ask_until_done(acute_liquidity_crisis, t1, Asked, Outcome),
    assertion(Asked == [current_assets, current_liabilities, cash, monthly_expenses]),
    Outcome = proven(Trace),
    has_term(try(r30, _, true), Trace),
    has_term(try(r13, _, true), Trace),
    has_term(try(r23, _, true), Trace).

test(b2_critical_t1) :-
    ask_until_done(risk_level(critical), t1, Asked, Outcome),
    Asked = [equity|_],
    Outcome = proven(Trace),
    has_term(try(r19, _, false), Trace),
    has_term(try(r30, _, true), Trace).

test(b3_critical_t2_disproven) :-
    ask_until_done(risk_level(critical), t2, _, Outcome),
    Outcome = disproven(Trace),
    has_term(try(r19, _, false), Trace),
    has_term(try(r30, _, false), Trace),
    has_term(try(r31, _, false), Trace).

test(b4_critical_cash_t4) :-
    ask_until_done(critical_cash_risk, t4, Asked, Outcome),
    assertion(Asked == [cash, monthly_expenses]),
    Outcome = disproven(_).

test(why_chain) :-
    prove_goal(acute_liquidity_crisis, [], need_input(current_assets, Why)),
    assertion(Why == [r30, r13]).

:- end_tests(backward).

% ---------------------------------------------------------------------
% HTTP smoke tests
% ---------------------------------------------------------------------
:- begin_tests(http, [setup(start_server(8095)), cleanup(http_stop_server(8095, []))]).

page_text(Path, Text) :-
    format(atom(URL), 'http://localhost:8095~w', [Path]),
    setup_call_cleanup(http_open(URL, In, [status_code(Code)]),
                       read_string(In, _, Text),
                       close(In)),
    assertion(Code == 200).

post_text(Path, Case, Text) :-
    case(Case, Inputs),
    maplist(form_field, Inputs, Form),
    format(atom(URL), 'http://localhost:8095~w', [Path]),
    setup_call_cleanup(http_open(URL, In, [post(form(Form)), status_code(Code)]),
                       read_string(In, _, Text),
                       close(In)),
    assertion(Code == 200).

form_field(Name-Value, Name=Text) :- format(atom(Text), '~w', [Value]).

test(home)  :- page_text('/', T), contains(T, "Start full assessment").
test(form)  :- page_text('/assess', T), contains(T, "Assess my business").
test(rules) :- page_text('/rules', T), contains(T, "R39").
test(about) :- page_text('/about', T), contains(T, "Backward chaining").
test(check) :- page_text('/check', T), contains(T, "Check this risk").
test(css)   :- page_text('/static/style.css', T), contains(T, "--ink").

test(post_t1) :- post_text('/assess', t1, T), contains(T, "Critical"), contains(T, "R33").
test(post_t2) :- post_text('/assess', t2, T), contains(T, "Low"), contains(T, "R36").
test(post_t4) :- post_text('/assess', t4, T), contains(T, "High"), contains(T, "R39").
test(post_t5) :- post_text('/assess', t5, T), contains(T, "Not applicable").

:- end_tests(http).
