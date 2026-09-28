% =====================================================================
%  engine.pl
%  SME Business Risk Assessment Expert System - INFERENCE ENGINE
%
%  Holds the WORKING MEMORY and the two reasoning methods:
%    - forward chaining  (assess/2)     : data-driven, used by the full assessment
%    - backward chaining (prove_goal/3) : goal-driven, used by "Check a specific risk"
%  Input validation and ratio calculation also live here because they
%  prepare the data the rules work on.
% =====================================================================

:- dynamic wm_input/2.      % wm_input(Name, Value)       user answers
:- dynamic wm_ratio/2.      % wm_ratio(Name, Value)       calculated ratios
:- dynamic wm_fact/1.       % wm_fact(Fact)               derived facts
:- dynamic wm_fired/4.      % wm_fired(Step, RuleId, Conclusion, Evidence)

% The forward engine runs the rule groups in this order. Each phase runs
% to a fixpoint before the next starts, so not_fact/1 and the category
% count only look at facts that are already final.
phase(1, [size]).
phase(2, [liquidity, debt, cash, other]).
phase(3, [combined]).
phase(4, [risk_level]).
phase(5, [advice]).

% =====================================================================
% 1. Validation
% =====================================================================

% validate_answer(+Name, +Text, -Result)   Result = ok(Value) | error(Message)
validate_answer(Name, Text, Result) :-
    input_name(Q, Name),
    question(Q, _, Type),
    normalize_space(atom(Clean0), Text),
    downcase_atom(Clean0, Clean),
    (   Clean == ''
    ->  Result = error('This field is required.')
    ;   check_type(Type, Name, Clean, Result)
    ).

check_type(choice(Options), _, Text, Result) :-
    (   memberchk(Text, Options)
    ->  Result = ok(Text)
    ;   atomic_list_concat(Options, ' or ', Choices),
        format(atom(Msg), 'Choose ~w.', [Choices]),
        Result = error(Msg)
    ).
check_type(yes_no, _, Text, Result) :-
    (   memberchk(Text, [yes, no])
    ->  Result = ok(Text)
    ;   Result = error('Choose yes or no.')
    ).
check_type(number, Name, Text, Result) :-
    atomic_list_concat(Parts, ',', Text),          % allow 1,000,000
    atomic_list_concat(Parts, Plain),
    (   catch(atom_number(Plain, N), _, fail), number(N)
    ->  number_limit(Name, N, Result)
    ;   Result = error('Enter a number, for example 250000.')
    ).

number_limit(employees, N, Result) :- !,
    (   integer(N), N >= 0
    ->  Result = ok(N)
    ;   Result = error('Enter a whole number of employees (0 or more).')
    ).
number_limit(largest_customer_pct, N, Result) :- !,
    (   N >= 0, N =< 100
    ->  Result = ok(N)
    ;   Result = error('Enter a percentage from 0 to 100.')
    ).
number_limit(monthly_expenses, N, Result) :- !,                         % V1
    (   N > 0
    ->  Result = ok(N)
    ;   Result = error('Monthly expenses must be more than 0 so cash reserve months can be calculated.')
    ).
number_limit(Name, N, ok(N)) :-
    memberchk(Name, [equity, net_profit]), !.     % these may be negative
number_limit(_, N, Result) :-
    (   N >= 0
    ->  Result = ok(N)
    ;   Result = error('This amount cannot be negative.')
    ).

% validate_form(+Pairs, -Inputs, -Errors)
%   Pairs:  Name-Text for what the user typed
%   Inputs: Name-Value for every valid answer
%   Errors: Name-Message for every problem (empty list = form is fine)
validate_form(Pairs, Inputs, Errors) :-
    findall(Name, input_name(_, Name), Names),
    check_fields(Names, Pairs, Inputs, FieldErrors),
    cross_field_errors(Inputs, CrossErrors),
    append(FieldErrors, CrossErrors, Errors).

check_fields([], _, [], []).
check_fields([Name|Names], Pairs, Inputs, Errors) :-
    ( memberchk(Name-Text, Pairs) -> true ; Text = '' ),
    validate_answer(Name, Text, Result),
    (   Result = ok(Value)
    ->  Inputs = [Name-Value|Inputs1], Errors = Errors1
    ;   Result = error(Msg),
        Inputs = Inputs1, Errors = [Name-Msg|Errors1]
    ),
    check_fields(Names, Pairs, Inputs1, Errors1).

cross_field_errors(Inputs, Errors) :-                                   % V2
    (   memberchk(inventory-Inv, Inputs),
        memberchk(current_assets-CA, Inputs),
        Inv > CA
    ->  Errors = [inventory-'Stock is part of current assets, so it cannot be larger than current assets.']
    ;   Errors = []
    ).

% =====================================================================
% 2. Ratios
% =====================================================================

ratio_inputs(cr, [current_assets, current_liabilities]).
ratio_inputs(qr, [current_assets, inventory, current_liabilities]).
ratio_inputs(de, [total_liabilities, equity]).
ratio_inputs(cm, [cash, monthly_expenses]).

% compute_ratio fails when the ratio cannot be calculated (V3, V4).
compute_ratio(cr, [CA, CL], V)        :- CL > 0, V is CA / CL.
compute_ratio(qr, [CA, Inv, CL], V)   :- CL > 0, V is (CA - Inv) / CL.
compute_ratio(de, [TL, Equity], V)    :- Equity > 0, V is TL / Equity.
compute_ratio(cm, [Cash, Expenses], V) :- Expenses > 0, V is Cash / Expenses.

calculate_ratios :-
    forall(( ratio_inputs(R, Names),
             maplist(wm_input, Names, Values),
             compute_ratio(R, Values, V) ),
           assertz(wm_ratio(R, V))).

% =====================================================================
% 3. Forward chaining
% =====================================================================

% assess(+Inputs, -Result)
%   Inputs is the Name-Value list from validate_form/3. Result is
%   result(Size, OutOfScope, Ratios, Facts, Fired, Level, Categories,
%          Advice, Notes, NotFired)
%   The mutex stops two browser requests sharing working memory.
assess(Inputs, Result) :-
    with_mutex(sme_engine, run_assessment(Inputs, Result)).

run_assessment(Inputs, Result) :-
    clear_memory,
    forall(member(Name-Value, Inputs), assertz(wm_input(Name, Value))),
    calculate_ratios,
    findall(P, phase(P, _), Phases),
    run_phases(Phases),
    collect_result(Result).

clear_memory :-
    retractall(wm_input(_, _)),
    retractall(wm_ratio(_, _)),
    retractall(wm_fact(_)),
    retractall(wm_fired(_, _, _, _)).

run_phases([]).
run_phases([P|Ps]) :-
    phase(P, Groups),
    fire_until_stable(Groups),
    (   wm_fact(outside_sme_scope)        % R12 stops the assessment
    ->  true
    ;   run_phases(Ps)
    ).

fire_until_stable(Groups) :-
    (   fire_one_rule(Groups)
    ->  fire_until_stable(Groups)
    ;   true
    ).

% Find the first rule (in file order) whose conditions hold and whose
% conclusion is new, add the conclusion to working memory and record it.
fire_one_rule(Groups) :-
    rule(Id, Group, Conditions, Conclusion, _, _, _),
    memberchk(Group, Groups),
    all_hold(Conditions, Evidence),
    \+ wm_fact(Conclusion),
    !,
    assertz(wm_fact(Conclusion)),
    aggregate_all(count, wm_fired(_, _, _, _), N),
    Step is N + 1,
    assertz(wm_fired(Step, Id, Conclusion, Evidence)).

all_hold(Conditions, Evidence) :-
    maplist(holds, Conditions, Evidence).

% holds(+Condition, -Evidence)
% Evidence records the actual values that made the condition true, so the
% explanation can say "current ratio = 0.80 < 1.0" instead of just "yes".
holds(in(Name, Op, Limit), cmp(input(Name), V, Op, L)) :-
    wm_input(Name, V),
    limit_value(Limit, L),
    compare_op(Op, V, L).
holds(answer(Name, Value), answer(Name, Value)) :-
    wm_input(Name, Value).
holds(ratio(R, Op, Limit), cmp(ratio(R), V, Op, L)) :-
    wm_ratio(R, V),
    limit_value(Limit, L),
    compare_op(Op, V, L).
holds(emp_in(Cat), emp_in(Cat, E, Min, Max)) :-
    wm_input(sector, Sector),
    wm_input(employees, E),
    employee_limit(Sector, Cat, Min, Max),
    E >= Min, E =< Max.
holds(emp_over(Cat), emp_over(Cat, E, Max)) :-
    wm_input(sector, Sector),
    wm_input(employees, E),
    employee_limit(Sector, Cat, _, Max),
    E > Max.
holds(turnover_in(Cat), turnover_in(Cat, T, Low, High)) :-
    wm_input(turnover, T),
    turnover_limit(Cat, Low, High),
    T > Low, T =< High.
holds(turnover_over(Cat), turnover_over(Cat, T, High)) :-
    wm_input(turnover, T),
    turnover_limit(Cat, _, High),
    T > High.
holds(fact(F), fact(F)) :-
    wm_fact(F).
holds(not_fact(F), not_fact(F)) :-
    \+ wm_fact(F).
holds(differ(A, B), differ(A, B)) :-
    A \== B.
holds(any(Conditions), any(Evidence)) :-
    member(C, Conditions),
    holds(C, Evidence), !.
holds(category_count(Op, Limit), count(N, Op, L)) :-
    risk_categories_present(Present),
    length(Present, N),
    limit_value(Limit, L),
    compare_op(Op, N, L).

% A limit is either a number or the name of a threshold/2 fact.
limit_value(Limit, Limit) :- number(Limit), !.
limit_value(Name, Value) :- threshold(Name, Value).

compare_op(<,  X, Y) :- X < Y.
compare_op(=<, X, Y) :- X =< Y.
compare_op(>,  X, Y) :- X > Y.
compare_op(>=, X, Y) :- X >= Y.

% A category counts once if any of its facts is in working memory.
risk_categories_present(Present) :-
    findall(Cat,
            ( risk_category(Cat, Facts),
              once(( member(F, Facts), wm_fact(F) )) ),
            Present).

collect_result(result(Size, OutOfScope, Ratios, Facts, Fired, Level,
                      Categories, Advice, Notes, NotFired)) :-
    ( wm_fact(size(Size)) -> true ; Size = unknown ),
    ( wm_fact(outside_sme_scope) -> OutOfScope = yes ; OutOfScope = no ),
    findall(R-V, wm_ratio(R, V), Ratios),
    findall(F, wm_fact(F), Facts),
    findall(fired(Step, Id, C, Ev), wm_fired(Step, Id, C, Ev), Fired),
    ( wm_fact(risk_level(Level)) -> true ; Level = none ),
    risk_categories_present(Categories),
    findall(Id, wm_fact(advice(Id)), Advice),
    findall(Note, calculation_note(Note), Notes),
    (   OutOfScope == yes
    ->  NotFired = []
    ;   findall(Miss, near_miss(Miss), NotFired)
    ).

calculation_note(no_current_liabilities) :-
    wm_input(current_liabilities, CL), CL =:= 0.
calculation_note(no_positive_equity) :-
    wm_input(equity, E), E =< 0.

% A combined or advice rule that did not fire although part of it matched.
% Shown on the result page so the user sees why (for example, why R39 did
% not fire for a loss-making business).
near_miss(not_fired(Id, Met, Unmet)) :-
    rule(Id, Group, Conditions, _, _, _, _),
    memberchk(Group, [combined, advice]),
    \+ wm_fired(_, Id, _, _),
    partition(condition_holds, Conditions, MetConds, Unmet),
    MetConds \== [],
    Unmet \== [],
    maplist(holds, MetConds, Met).

condition_holds(C) :- holds(C, _).

% =====================================================================
% 4. Backward chaining
% =====================================================================

% prove_goal(+Goal, +Known, -Outcome)
%   Known is the list of Name-Value answers collected so far.
%   Outcome = proven(Trace) | disproven(Trace) | need_input(Name, WhyRuleIds)
%   Nothing is stored between calls: the web page sends back all answers
%   so far and the proof is repeated from the top each time.
prove_goal(Goal, Known, Outcome) :-
    prove(Goal, Known, [], Status, Trace),
    (   Status = need(Name, Why)
    ->  Outcome = need_input(Name, Why)
    ;   Status == true
    ->  Outcome = proven(Trace)
    ;   Outcome = disproven(Trace)
    ).

% prove(+Goal, +Known, +Path, -Status, -Trace)
%   Status is true, false or need(Name, Why).
%   Path is the chain of rule ids being tried (innermost first).
prove(Goal, Known, Path, Status, goal(Goal, Status, Tries)) :-
    findall(Id, rule(Id, _, _, Goal, _, _, _), Ids),
    try_rules(Ids, Goal, Known, Path, Status, Tries).

try_rules([], _, _, _, false, []).
try_rules([Id|Ids], Goal, Known, Path, Status, [try(Id, Checks, S)|Rest]) :-
    rule(Id, _, Conditions, Goal, _, _, _),
    check_all(Conditions, Known, [Id|Path], S, Checks),
    (   S == false
    ->  try_rules(Ids, Goal, Known, Path, Status, Rest)
    ;   Status = S, Rest = []
    ).

% Conditions are checked left to right and checking stops at the first
% one that fails or needs a new answer.
check_all([], _, _, true, []).
check_all([C|Cs], Known, Path, Status, [check(C, S, Ev)|Rest]) :-
    check(C, Known, Path, S, Ev),
    (   S == true
    ->  check_all(Cs, Known, Path, Status, Rest)
    ;   Status = S, Rest = []
    ).

check(in(Name, Op, Limit), Known, Path, S, Ev) :-
    (   memberchk(Name-V, Known)
    ->  limit_value(Limit, L),
        Ev = cmp(input(Name), V, Op, L),
        truth(compare_op(Op, V, L), S)
    ;   need(Name, Path, S), Ev = none
    ).
check(answer(Name, Wanted), Known, Path, S, Ev) :-
    (   memberchk(Name-V, Known)
    ->  Ev = answer(Name, V),
        truth(V == Wanted, S)
    ;   need(Name, Path, S), Ev = none
    ).
check(ratio(R, Op, Limit), Known, Path, S, Ev) :-
    ratio_inputs(R, Names),
    (   member(Name, Names), \+ memberchk(Name-_, Known)
    ->  need(Name, Path, S), Ev = none
    ;   maplist(known_value(Known), Names, Values),
        (   compute_ratio(R, Values, V)
        ->  limit_value(Limit, L),
            Ev = cmp(ratio(R), V, Op, L),
            truth(compare_op(Op, V, L), S)
        ;   Ev = not_applicable(R), S = false
        )
    ).
check(fact(F), Known, Path, S, Sub) :-
    prove(F, Known, Path, S, Sub).
check(not_fact(F), Known, Path, S, negation(Sub)) :-
    prove(F, Known, Path, S0, Sub),
    negate(S0, S).
check(any(Conditions), Known, Path, S, any(Checks)) :-
    check_any(Conditions, Known, Path, S, Checks).

check_any([], _, _, false, []).
check_any([C|Cs], Known, Path, S, [check(C, S0, Ev)|Rest]) :-
    check(C, Known, Path, S0, Ev),
    (   S0 == false
    ->  check_any(Cs, Known, Path, S, Rest)
    ;   S = S0, Rest = []
    ).

known_value(Known, Name, Value) :- memberchk(Name-Value, Known).

need(Name, Path, need(Name, Why)) :- reverse(Path, Why).

truth(Goal, S) :- ( call(Goal) -> S = true ; S = false ).

negate(true, false).
negate(false, true).
negate(need(N, W), need(N, W)).
