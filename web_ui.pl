:- encoding(utf8).
% =====================================================================
%  web_ui.pl
%  SME Business Risk Assessment Expert System - USER INTERFACE
%
%  Web pages served by SWI-Prolog's built-in HTTP server. The pages only
%  collect answers and display results: all reasoning is done by
%  engine.pl and all wording of explanations comes from explanation.pl.
%
%    /            home
%    /assess      full assessment form and result (forward chaining)
%    /check       pick a goal, then /check/ask one question at a time
%                 (backward chaining)
%    /rules       all rules and sources
%    /about       architecture and how the two chaining methods work
%
%  html_write escapes all text, so user input is never inserted as raw HTML.
% =====================================================================

:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_parameters)).
:- use_module(library(http/html_write)).
:- use_module(library(uri)).

:- prolog_load_context(directory, Dir),
   directory_file_path(Dir, static, Static),
   asserta(user:file_search_path(static_files, Static)).

:- http_handler(root(.),           home_page,      []).
:- http_handler(root(assess),      assess_page,    []).
:- http_handler(root(check),       check_page,     []).
:- http_handler(root('check/ask'), check_ask_page, []).
:- http_handler(root(rules),       rules_page,     []).
:- http_handler(root(about),       about_page,     []).
:- http_handler(root('static/style.css'), http_reply_file(static_files('style.css'), []), []).

start_server(Port) :-
    http_server(http_dispatch, [port(Port)]).

% ---------------------------------------------------------------------
% Page layout shared by every page
% ---------------------------------------------------------------------
show_page(Title, Class, Body0) :-
    tidy(Body0, Body),
    reply_html_page(
        [ title([Title, ' - SME Risk Check']),
          meta([name(viewport), content('width=device-width, initial-scale=1')]),
          link([rel(stylesheet), href('/static/style.css')])
        ],
        [ header(class('site-header'),
                 div(class(bar),
                     [ a([class(brand), href('/')], 'SME Risk Check'),
                       nav([ a(href('/assess'), 'Full assessment'),
                             a(href('/check'), 'Check a risk'),
                             a(href('/rules'), 'Rules and sources'),
                             a(href('/about'), 'How it works')
                           ])
                     ])),
          main(class(Class), Body),
          footer(class('site-footer'),
                 p('General risk screening for education. Not a professional financial audit.'))
        ]).

% html_write reads a list inside a list as a strange element, so pages
% built from smaller pieces are flattened first. Only element content is
% touched; attribute lists are left as they are.
tidy(Content, Flat) :-
    is_list(Content), !,
    flatten(Content, Items),
    maplist(tidy, Items, Flat).
tidy(Element, Tidy) :-
    compound(Element),
    Element =.. [Name, Content],
    \+ attribute_name(Name), !,
    tidy(Content, C),
    Tidy =.. [Name, C].
tidy(Element, Tidy) :-
    compound(Element),
    Element =.. [Name, Attrs, Content], !,
    tidy(Content, C),
    Tidy =.. [Name, Attrs, C].
tidy(Other, Other).

attribute_name(Name) :-
    memberchk(Name, [class, id, href, type, name, value, for, role, scope, rel,
                     action, method, placeholder, inputmode, autocomplete,
                     checked, onclick, novalidate, content,
                     'aria-label', 'aria-invalid', 'aria-describedby']).

form_data(Request, Data) :-
    http_parameters(Request, [], [form_data(Data)]).

param(Data, Name, Value) :-
    ( memberchk(Name=V, Data) -> Value = V ; Value = '' ).

to_text(V, T) :- format(atom(T), '~w', [V]).

% ---------------------------------------------------------------------
% Home
% ---------------------------------------------------------------------
home_page(_Request) :-
    show_page('Home', narrow,
         [ h1('Check the financial risk of a small business'),
           p(class(lead),
             'This expert system screens Sri Lankan small and medium businesses for financial risk. It applies 39 published rules to your figures and shows every step of its reasoning.'),
           p('Many Sri Lankan SMEs struggled or closed after the 2022 economic crisis, and most owners cannot afford a financial consultant. This tool gives a first, general risk screening.'),
           div(class(choices),
               [ section(class(choice),
                         [ h2('Full assessment'),
                           p('Answer all 14 questions and see every risk found.'),
                           a([class(button), href('/assess')], 'Start full assessment')
                         ]),
                 section(class(choice),
                         [ h2('Check a specific risk'),
                           p('Pick one question about your business and answer only what is needed.'),
                           a([class([button, secondary]), href('/check')], 'Check a specific risk')
                         ])
               ]),
           p(class(links),
             [ a(href('/about'), 'How it works'), ' · ',
               a(href('/rules'), 'Rules and sources') ])
         ]).

% ---------------------------------------------------------------------
% Full assessment form
% ---------------------------------------------------------------------
form_section(1, 'About the business',              [sector, employees, turnover]).
form_section(2, 'Balance sheet',                   [current_assets, inventory, current_liabilities,
                                                    total_liabilities, equity]).
form_section(3, 'Cash and profit',                 [cash, monthly_expenses, net_profit]).
form_section(4, 'Customers, imports and records',  [largest_customer_pct, imports, audited_statements]).

field_hint(employees,            'Full-time and part-time staff, including the owner if paid.').
field_hint(turnover,             'Rs. million - total sales for a year, e.g. 8 for Rs. 8,000,000.').
field_hint(current_assets,       'Rs. - include cash, stock, and money customers owe you.').
field_hint(inventory,            'Rs. - raw materials and goods ready to sell.').
field_hint(current_liabilities,  'Rs. - bills, short loans and overdrafts due within 12 months.').
field_hint(total_liabilities,    'Rs. - everything owed, short-term and long-term.').
field_hint(equity,               'Rs. - can be negative if debts are larger than assets.').
field_hint(cash,                 'Rs. - cash in hand and in bank accounts today.').
field_hint(monthly_expenses,     'Rs. - rent, wages, utilities and supplies in a normal month.').
field_hint(net_profit,           'Rs. - enter a negative number, e.g. -50000, for a loss.').
field_hint(largest_customer_pct, 'Percent, 0 to 100.').

field_placeholder(employees,            'e.g. 12').
field_placeholder(turnover,             'e.g. 40').
field_placeholder(current_assets,       'e.g. 2,000,000').
field_placeholder(inventory,            'e.g. 500,000').
field_placeholder(current_liabilities,  'e.g. 1,000,000').
field_placeholder(total_liabilities,    'e.g. 3,000,000').
field_placeholder(equity,               'e.g. 1,500,000').
field_placeholder(cash,                 'e.g. 600,000').
field_placeholder(monthly_expenses,     'e.g. 250,000').
field_placeholder(net_profit,           'e.g. 300,000').
field_placeholder(largest_customer_pct, 'e.g. 15').

% Example businesses from the test cases, for quick demonstrations.
example(t1, [sector-manufacturing, employees-6, turnover-8,
             current_assets-800000, inventory-300000, current_liabilities-1000000,
             total_liabilities-3000000, equity-1000000, cash-350000,
             monthly_expenses-400000, largest_customer_pct-40, net_profit-(-50000),
             imports-yes, audited_statements-no]).
example(t2, [sector-service, employees-25, turnover-120,
             current_assets-5000000, inventory-1000000, current_liabilities-2500000,
             total_liabilities-3000000, equity-6000000, cash-3000000,
             monthly_expenses-800000, largest_customer_pct-8, net_profit-2000000,
             imports-no, audited_statements-yes]).
example(t4, [sector-service, employees-8, turnover-12,
             current_assets-900000, inventory-100000, current_liabilities-1000000,
             total_liabilities-2500000, equity-1000000, cash-500000,
             monthly_expenses-300000, largest_customer_pct-60, net_profit-100000,
             imports-yes, audited_statements-yes]).

assess_page(Request) :-
    memberchk(method(Method), Request),
    form_data(Request, Data),
    (   Method == post
    ->  handle_assessment(Data)
    ;   starting_values(Data, Values),
        assessment_form(Values, [])
    ).

% A GET request can pre-fill the form from an example or from answers
% already given in "Check a specific risk".
starting_values(Data, Values) :-
    param(Data, example, Ex),
    (   example(Ex, Pairs)
    ->  findall(N-T, (member(N-V, Pairs), to_text(V, T)), Values)
    ;   findall(N-T, (input_name(_, N), memberchk(N=T, Data)), Values)
    ).

handle_assessment(Data) :-
    findall(Name-Text, (input_name(_, Name), param(Data, Name, Text)), Pairs),
    validate_form(Pairs, Inputs, Errors),
    (   Errors == []
    ->  assess(Inputs, Result),
        result_page(Inputs, Result)
    ;   assessment_form(Pairs, Errors)
    ).

assessment_form(Values, Errors) :-
    findall(S, form_section_html(Values, Errors, S), Sections),
    error_summary(Errors, Summary),
    show_page('Full assessment', form_page,
         [ h1('Full risk assessment'),
           p(class(lead),
             'Answer all 14 questions. Use figures from your latest accounts; amounts are in Sri Lankan rupees.'),
           p(class(examples),
             [ 'Fill with example: ',
               a(href('/assess?example=t1'), 'Nimal''s Bakery'), ' (critical) · ',
               a(href('/assess?example=t2'), 'Healthy service business'), ' (low) · ',
               a(href('/assess?example=t4'), 'Busy trading shop'), ' (high)'
             ]),
           Summary,
           form([method(post), action('/assess'), novalidate(novalidate)],
                [ Sections,
                  div(class(actions),
                      button([type(submit), class(button)], 'Assess my business'))
                ])
         ]).

form_section_html(Values, Errors, section(class('form-section'), [h2(Heading)|Fields])) :-
    form_section(N, Title, Names),
    format(atom(Heading), '~w. ~w', [N, Title]),
    maplist(field_html(Values, Errors), Names, Fields).

field_html(Values, Errors, Name, Html) :-
    input_name(Q, Name),
    question(Q, Question, Type),
    ( memberchk(Name-V, Values) -> true ; V = '' ),
    ( memberchk(Name-Msg, Errors) -> Error = Msg ; Error = none ),
    field_control(Type, Name, Question, V, Error, Html).

% Number field: label, hint, text box and (if any) the error message.
field_control(number, Name, Question, Value, Error, div(class(Class), [label(for(Name), Question), Hint, input(Attrs), ErrorHtml])) :-
    atom_concat(Name, '_hint', HintId),
    atom_concat(Name, '_error', ErrorId),
    ( field_hint(Name, H) -> Hint = p([class(hint), id(HintId)], H) ; Hint = '' ),
    ( field_placeholder(Name, P) -> true ; P = '' ),
    ( Name == employees -> Mode = numeric ; Mode = decimal ),
    Base = [type(text), id(Name), name(Name), value(Value), inputmode(Mode),
            placeholder(P), autocomplete(off)],
    (   Error == none
    ->  Class = field, ErrorHtml = '',
        append(Base, ['aria-describedby'(HintId)], Attrs)
    ;   Class = [field, invalid],
        ErrorHtml = p([class(error), id(ErrorId)], Error),
        atomic_list_concat([HintId, ErrorId], ' ', Described),
        append(Base, ['aria-invalid'(true), 'aria-describedby'(Described)], Attrs)
    ).
field_control(yes_no, Name, Question, Value, Error, Html) :-
    field_control(choice([yes, no]), Name, Question, Value, Error, Html).
field_control(choice(Options), Name, Question, Value, Error,
              fieldset([class(Class), id(Name)], [legend(Question), div(class(options), Radios), ErrorHtml])) :-
    maplist(radio(Name, Value), Options, Radios),
    (   Error == none
    ->  Class = field, ErrorHtml = ''
    ;   Class = [field, invalid], ErrorHtml = p(class(error), Error)
    ).

radio(Name, Value, Option, span(class(option), [input(Attrs), label(for(Id), Label)])) :-
    atomic_list_concat([Name, '_', Option], Id),
    capitalise(Option, Label),
    Base = [type(radio), id(Id), name(Name), value(Option)],
    ( Value == Option -> Attrs = [checked(checked)|Base] ; Attrs = Base ).

error_summary([], '').
error_summary(Errors, div([class('error-summary'), role(alert)],
                          [h2('Fix these answers to continue'), ul(Items)])) :-
    Errors \== [],
    findall(li(a(href(Anchor), [Label, ': ', Msg])),
            ( member(Name-Msg, Errors),
              input_label(Name, Label),
              atom_concat('#', Name, Anchor) ),
            Items).

% ---------------------------------------------------------------------
% Result page (forward chaining)
% ---------------------------------------------------------------------
result_page(Inputs, Result) :-
    Result = result(_, OutOfScope, _, _, _, _, _, _, _, _),
    (   OutOfScope == yes
    ->  out_of_scope_page(Inputs, Result)
    ;   full_result_page(Inputs, Result)
    ).

full_result_page(Inputs, result(Size, _, Ratios, Facts, Fired, Level, Present, Advice, Notes, NotFired)) :-
    risk_block(Level, Present, Fired, Block),
    size_section(Size, Fired, SizeHtml),
    advice_section(Advice, AdviceHtml),
    answers_table(Inputs, AnswersHtml),
    ratios_table(Ratios, Fired, RatiosHtml),
    notes_html(Notes, NotesHtml),
    facts_section(Facts, FactsHtml),
    fired_list(Fired, FiredHtml),
    not_fired_section(NotFired, NotFiredHtml),
    conclusion_text(Fired, Level, Conclusion),
    result_actions(Actions),
    show_page('Assessment result', report,
         [ h1('Risk assessment report'),
           Block,
           section([h2('Business size'), SizeHtml]),
           section([h2('Advice'), AdviceHtml]),
           section(class(how),
                   [ h2('How this was decided'),
                     p('The system worked from your answers to its conclusion in the order below.'),
                     h3('1. Your answers'), AnswersHtml,
                     h3('2. Calculated ratios'), RatiosHtml, NotesHtml,
                     h3('3. Facts derived'), FactsHtml,
                     h3('4. Rules applied, in firing order'), FiredHtml,
                     h3('5. Rules checked but not fired'), NotFiredHtml,
                     h3('6. Conclusion'), p(class(conclusion), Conclusion)
                   ]),
           Actions
         ]).

result_actions(div(class([actions, 'no-print']),
                   [ a([class(button), href('/assess')], 'Start a new assessment'),
                     button([type(button), class([button, secondary]), onclick('window.print()')],
                            'Print this report')
                   ])).

% The bold element: the level in large type and a strip with the 7 risk
% categories, each written as "Risk" or "Clear" (never colour alone).
risk_block(Level, Present, Fired,
           div(class(['risk-block', Level]),
               [ p(class('risk-label'), 'Overall risk level'),
                 p(class('risk-level'), Word),
                 p(class('risk-count'), [CountText, ' ', Reason]),
                 ul([class(strip), 'aria-label'('Risk categories')], Segments)
               ])) :-
    capitalise(Level, Word),
    length(Present, N),
    format(atom(CountText), '~w of 7 risk categories present.', [N]),
    conclusion_text(Fired, Level, Reason),
    findall(li(class([seg, State]), [span(class('seg-name'), Label), span(class('seg-state'), StateWord)]),
            ( risk_category(Cat, _),
              category_label(Cat, Label),
              (   memberchk(Cat, Present)
              ->  State = risk, StateWord = 'Risk'
              ;   State = clear, StateWord = 'Clear'
              )
            ),
            Segments).

size_section(Size, Fired, [p(class(size), ['This business is ', strong(Size), '.']), ul(Items), Note]) :-
    findall(li([strong(Label), ': ', Because]),
            ( member(F, Fired),
              F = fired(_, Id, _, _),
              rule(Id, size, _, _, _, _, _),
              how_step(F, step(_, Label, _, _, Evidence, _, _, _)),
              atomic_list_concat(Evidence, '; ', Because) ),
            Items),
    (   memberchk(fired(_, r11, _, _), Fired)
    ->  Note = p(class(note), 'The employee and turnover categories differ. The National SME Policy Framework uses employment to decide, so rule R11 applied.')
    ;   Note = ''
    ).

advice_section([], p('No advice rules fired. Review these figures again when your next accounts are ready.')).
advice_section(Ids, ul(class(advice), Items)) :-
    Ids \== [],
    findall(li([ p(Text), p(class(meta), ['From ', Label, '. Source: ', Sources]) ]),
            ( member(Id, Ids),
              advice_text(Id, Text),
              rule_label(Id, Label),
              rule(Id, _, _, _, SourceIds, _, _),
              maplist(source_text, SourceIds, SourceTexts),
              atomic_list_concat(SourceTexts, '; ', Sources) ),
            Items).

answers_table(Inputs, table(class(ledger), [tbody(Rows)])) :-
    findall(tr([th(scope(row), Label), td(class(num), Value)]),
            ( input_name(_, Name),
              memberchk(Name-V, Inputs),
              input_label(Name, Label),
              value_text(Name, V, Value) ),
            Rows).

ratios_table(Ratios, Fired,
             table(class(ledger),
                   [ thead(tr([th('Ratio'), th(class(num), 'Value'), th('Threshold met'), th('Meaning')])),
                     tbody(Rows)
                   ])) :-
    maplist(ratio_row(Ratios, Fired), [cr, qr, de, cm], Rows).

ratio_row(Ratios, Fired, R, tr([th(scope(row), [Label, span(class(formula), Formula)]), td(class(num), Value), td(Threshold), td(Meaning)])) :-
    ratio_label(R, Label),
    ratio_formula(R, Formula),
    (   memberchk(R-V, Ratios)
    ->  ratio_text(V, Value),
        ratio_findings(R, Fired, Threshold, Meaning)
    ;   Value = 'Not applicable',
        Threshold = '-',
        not_applicable_reason(R, Meaning)
    ).

% The limits and meaning come from whichever rule fired on this ratio.
ratio_findings(R, Fired, Threshold, Meaning) :-
    findall(Id-C, ( member(fired(_, Id, C, Ev), Fired), memberchk(cmp(ratio(R), _, _, _), Ev) ), Hits),
    (   Hits = [Id-Conclusion|_]
    ->  memberchk(fired(_, Id, _, Ev), Fired),
        findall(T, ( member(cmp(ratio(R), _, Op, L), Ev), op_text(Op, O), number_text(L, LT),
                     format(atom(T), '~w ~w', [O, LT]) ), Ts),
        atomic_list_concat(Ts, ' and ', Limits),
        rule_label(Id, RL),
        format(atom(Threshold), '~w (~w)', [Limits, RL]),
        ( description(Conclusion, Meaning) -> true ; fact_name(Conclusion, Meaning) )
    ;   Threshold = '-', Meaning = '-'
    ).

notes_html([], '').
notes_html(Notes, ul(class(notes), Items)) :-
    Notes \== [],
    findall(li(Text), ( member(N, Notes), note_text(N, Text) ), Items).

note_text(no_current_liabilities, 'No short-term liabilities, so liquidity ratios do not apply. Rules R13 to R18 were skipped.').
note_text(no_positive_equity, 'Equity is zero or negative, so debt-to-equity was not calculated. Rules R20 to R22 were skipped and R19 applies.').

risk_fact(F) :- risk_category(_, Facts), memberchk(F, Facts), !.
risk_fact(F) :- memberchk(F, [balance_sheet_insolvency, acute_liquidity_crisis, debt_distress, refinancing_difficulty]).

facts_section(Facts, [h4('Risks found'), RiskHtml, h4('Other findings'), OtherHtml]) :-
    findall(li([strong(Name), ' - ', Desc]),
            ( member(F, Facts), risk_fact(F), description(F, Desc), fact_name(F, Name) ),
            Risks),
    findall(li([strong(Name), ' - ', Desc]),
            ( member(F, Facts), \+ risk_fact(F), description(F, Desc), fact_name(F, Name) ),
            Others),
    ( Risks == [] -> RiskHtml = p('No risk indicators were found.') ; RiskHtml = ul(class(facts), Risks) ),
    ( Others == [] -> OtherHtml = p('None.') ; OtherHtml = ul(class(facts), Others) ).

fired_list(Fired, ol(class(steps), Items)) :-
    maplist(step_html, Fired, Items).

step_html(F, li([ p(class('step-head'), [strong(Label), ' ', span(class(group), Group), ' ', span(class(rating), ['Rating: ', Rating])]),
                  p(class(ifthen), Text),
                  p(['Because: ', Because]),
                  p(['Adds: ', Adds]),
                  p(class(sources), ['Source: ', Sources])
                ])) :-
    how_step(F, step(_, Label, Group, Text, Evidence, SourceTexts, Rating, Adds)),
    atomic_list_concat(Evidence, '; ', Because),
    atomic_list_concat(SourceTexts, '; ', Sources).

not_fired_section([], p('No combined or advice rule was partly matched.')).
not_fired_section(Misses, ul(class(notes), Items)) :-
    Misses \== [],
    findall(li(Text), ( member(M, Misses), near_miss_text(M, Text) ), Items).

out_of_scope_page(Inputs, result(_, _, _, _, Fired, _, _, _, _, _)) :-
    memberchk(sector-Sector, Inputs),
    memberchk(employees-E, Inputs),
    memberchk(turnover-T, Inputs),
    employee_limit(Sector, medium, _, MaxE),
    turnover_limit(medium, _, MaxT),
    number_text(T, TT),
    format(atom(Msg),
           'This system only assesses small and medium enterprises. A ~w business with ~w employees and a turnover of Rs. ~w million is above the SME limits (up to ~w employees and Rs. ~w million turnover). No risk level is given.',
           [Sector, E, TT, MaxE, MaxT]),
    fired_list(Fired, FiredHtml),
    result_actions(Actions),
    show_page('Outside SME scope', report,
         [ h1('Risk assessment report'),
           div(class(['risk-block', outside]),
               [ p(class('risk-label'), 'Result'),
                 p(class('risk-level'), 'Outside SME scope'),
                 p(Msg)
               ]),
           section(class(how),
                   [ h2('How this was decided'),
                     FiredHtml,
                     p(class(note), 'Rule R12 stopped the assessment here, so no risk rules were run.')
                   ]),
           Actions
         ]).

% ---------------------------------------------------------------------
% Check a specific risk (backward chaining)
% ---------------------------------------------------------------------
goal_key(Goal, Key) :- format(atom(Key), '~w', [Goal]).

goal_from_key(Key, Goal) :-
    goal_option(Goal, _),
    goal_key(Goal, Key), !.

check_page(_Request) :-
    findall(G, goal_option(G, _), Goals),
    findall(span(class(option), [input(Attrs), label(for(Id), Label)]),
            ( nth1(I, Goals, G),
              goal_option(G, Label),
              goal_key(G, Key),
              format(atom(Id), 'goal_~w', [I]),
              Base = [type(radio), id(Id), name(goal), value(Key)],
              ( I =:= 1 -> Attrs = [checked(checked)|Base] ; Attrs = Base ) ),
            Radios),
    show_page('Check a specific risk', form_page,
         [ h1('Check a specific risk'),
           p(class(lead),
             'Pick one question. The system starts from that goal, works backwards through the rules, and asks only for the figures it needs.'),
           form([method(post), action('/check/ask')],
                [ fieldset(class(field),
                           [ legend('What do you want to check?'),
                             div(class([options, stacked]), Radios) ]),
                  div(class(actions), button([type(submit), class(button)], 'Check this risk'))
                ])
         ]).

% Each POST carries the goal and every answer given so far (as hidden
% fields). The engine is asked again with all known answers and replies
% with the next question it needs, or with its final verdict.
check_ask_page(Request) :-
    form_data(Request, Data),
    param(Data, goal, Key),
    (   goal_from_key(Key, Goal)
    ->  known_answers(Data, Known, Errors),
        prove_goal(Goal, Known, Outcome),
        (   Outcome = need_input(Name, Why)
        ->  ( memberchk(Name-Msg, Errors) -> Error = Msg ; Error = none ),
            question_page(Goal, Known, Name, Why, Error)
        ;   check_result_page(Goal, Known, Outcome)
        )
    ;   check_page(Request)
    ).

known_answers(Data, Known, Errors) :-
    findall(Name-Result,
            ( input_name(_, Name), memberchk(Name=Text, Data), validate_answer(Name, Text, Result) ),
            Checked),
    findall(Name-V, member(Name-ok(V), Checked), Known),
    findall(Name-M, member(Name-error(M), Checked), Errors0),
    param(Data, asking, Asking),
    (   Asking \== '', \+ memberchk(Asking=_, Data)       % radio left unselected
    ->  Errors = [Asking-'This field is required.'|Errors0]
    ;   Errors = Errors0
    ).

question_page(Goal, Known, Name, Why, Error) :-
    length(Known, K),
    N is K + 1,
    format(atom(Progress), 'Question ~w - the system asks only what it needs', [N]),
    input_name(Q, Name),
    question(Q, Text, Type),
    field_control(Type, Name, Text, '', Error, Control),
    why_text(Name, Why, WhyText),
    goal_option(Goal, GoalLabel),
    goal_key(Goal, Key),
    findall(input([type(hidden), name(N1), value(T1)]),
            ( member(N1-V1, Known), to_text(V1, T1) ),
            Hidden),
    known_list(Known, KnownHtml),
    show_page('Check a specific risk', form_page,
         [ p(class(progress), Progress),
           h1(GoalLabel),
           form([method(post), action('/check/ask'), novalidate(novalidate)],
                [ input([type(hidden), name(goal), value(Key)]),
                  input([type(hidden), name(asking), value(Name)]),
                  Hidden,
                  Control,
                  details(class(why), [summary('Why is this asked?'), p(WhyText)]),
                  div(class(actions), button([type(submit), class(button)], 'Continue'))
                ]),
           KnownHtml
         ]).

known_list([], '').
known_list(Known, section(class(answered), [h2('Answers so far'), table(class(ledger), tbody(Rows))])) :-
    Known \== [],
    findall(tr([th(scope(row), Label), td(class(num), Value)]),
            ( member(Name-V, Known), input_label(Name, Label), value_text(Name, V, Value) ),
            Rows).

check_result_page(Goal, Known, Outcome) :-
    (   Outcome = proven(Trace)
    ->  Class = proven, Word = 'Yes - proven'
    ;   Outcome = disproven(Trace),
        Class = disproven, Word = 'No - not proven'
    ),
    goal_option(Goal, GoalLabel),
    trace_tree(Trace, Tree),
    tree_html(Tree, TreeHtml),
    trace_rules(Trace, RuleIds),
    findall(S, ( member(Id, RuleIds), rule(Id, _, _, _, Ss, _, _), member(S, Ss) ), Sources0),
    sort(Sources0, Sources),
    maplist(source_text, Sources, SourceTexts),
    findall(li(T), member(T, SourceTexts), SourceItems),
    length(Known, K),
    format(atom(CountText),
           'You answered ~w questions. A full assessment asks 14.', [K]),
    findall(Name=T, ( member(Name-V, Known), to_text(V, T) ), Query),
    uri_query_components(QS, Query),
    atom_concat('/assess?', QS, Href),
    known_list(Known, KnownHtml),
    show_page('Check result', report,
         [ h1(GoalLabel),
           div(class([verdict, Class]),
               [ p(class('risk-label'), 'Answer'),
                 p(class('risk-level'), Word),
                 p(CountText)
               ]),
           section(class(how),
                   [ h2('Proof trace'),
                     p('Each goal was tried with the rules that can conclude it. Failed branches are kept so you can see why they failed.'),
                     ul(class(trace), TreeHtml)
                   ]),
           section([h2('Sources of the rules used'), ul(class(sources), SourceItems)]),
           KnownHtml,
           div(class([actions, 'no-print']),
               [ a([class(button), href(Href)], 'Continue with a full assessment'),
                 a([class([button, secondary]), href('/check')], 'Check another risk')
               ])
         ]).

tree_html(node(Text, Status, Children), li(class(State), [span(class(node), Text), Sub])) :-
    ( Status == true -> State = ok ; State = fail ),
    (   Children == []
    ->  Sub = ''
    ;   maplist(tree_html, Children, ChildHtml),
        Sub = ul(ChildHtml)
    ).

% ---------------------------------------------------------------------
% Rules and sources
% ---------------------------------------------------------------------
rules_page(_Request) :-
    findall(Section, group_table(Section), Sections),
    findall(li([strong(Id), ' ', Citation]), source(Id, Citation), SourceItems),
    show_page('Rules and sources', report,
         [ h1('Rules and sources'),
           p(class(lead),
             'All 39 rules the system uses, generated from rules.pl. Every limit is read from knowledge_base.pl.'),
           dl(class(ratings),
              [ dt('Direct'),  dd('The source states the rule.'),
                dt('Applied'), dd('The source supports the rule with a small interpretation.'),
                dt('Design'),  dd('A combination designed by the knowledge engineer.')
              ]),
           Sections,
           section([h2('Sources'), ul(class(sources), SourceItems)])
         ]).

group_table(section([h2(Heading),
                     table(class([ledger, rules]),
                           [ thead(tr([th('Rule'), th('IF … THEN …'), th('Sources'), th('Rating')])),
                             tbody(Rows)
                           ])])) :-
    group_info(Group, Letter, Title),
    format(atom(Heading), '~w. ~w', [Letter, Title]),
    findall(tr([th(scope(row), Label), td(Text), td(SourceList), td(Rating)]),
            ( rule(Id, Group, _, _, Sources, R, Text),
              rule_label(Id, Label),
              atomic_list_concat(Sources, ', ', SourceList),
              rating_label(R, Rating) ),
            Rows).

% ---------------------------------------------------------------------
% How it works
% ---------------------------------------------------------------------
about_page(_Request) :-
    show_page('How it works', narrow,
         [ h1('How it works'),
           p(class(lead),
             'The system follows the classic expert system architecture. Knowledge is kept apart from the reasoning, so a threshold can change without touching any rule.'),
           div([class(arch), role(img), 'aria-label'('Architecture diagram')],
               [ div(class(['arch-box', user]),
                     [strong('User'), span('Business owner using a web browser')]),
                 div(class('arch-link'), span('answers and results')),
                 div(class('arch-box'),
                     [strong('User interface'), span('web_ui.pl - forms and report pages')]),
                 div(class('arch-link'), span('validated answers')),
                 div(class('arch-row'),
                     [ div(class('arch-box'),
                           [strong('Knowledge base'),
                            span('knowledge_base.pl - thresholds, limits, sources'),
                            span('rules.pl - 39 IF-THEN rules')]),
                       div(class('arch-side'), span('reads')),
                       div(class(['arch-box', engine]),
                           [strong('Inference engine'),
                            span('engine.pl - forward and backward chaining')]),
                       div(class('arch-side'), span('reads and writes')),
                       div(class('arch-box'),
                           [strong('Working memory'),
                            span('wm_input, wm_ratio, wm_fact, wm_fired')])
                     ]),
                 div(class('arch-link'), span('fired rules and proof traces')),
                 div(class('arch-box'),
                     [strong('Explanation facility'),
                      span('explanation.pl - HOW and WHY explanations')])
               ]),
           section([ h2('Forward chaining'),
                     p('Used by the full assessment. The system starts from all 14 answers and fires every rule whose conditions are met, adding new facts to working memory. It runs in five phases: size, risk indicators, combined conditions, overall level, and advice. For example, a current ratio of 0.80 fires R13 (liquidity risk high); cash for 0.9 months fires R23 (critical cash risk); those two facts then fire R30 (acute liquidity crisis), which fires R33 and sets the level to CRITICAL.')
                   ]),
           section([ h2('Backward chaining'),
                     p('Used by "Check a specific risk". The system starts from a goal, such as "acute liquidity crisis", and looks for a rule that concludes it (R30). R30 needs "liquidity risk high", which needs R13, which needs the current ratio, so the system asks for current assets and current liabilities. It asks only for what the proof needs, and each question has a "Why is this asked?" explanation. If a branch fails, it tries the next rule and keeps the failed branch in the trace.')
                   ]),
           section([ h2('Explanations'),
                     p('After a full assessment, the HOW explanation lists every rule that fired, in order, with the actual values, the source and the rating. During backward chaining, the WHY explanation shows the chain of rules that led to each question.')
                   ])
         ]).
