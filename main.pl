% =====================================================================
%  main.pl
%  SME Business Risk Assessment Expert System - ENTRY POINT
%
%  Loads every part of the expert system and starts the web server.
%
%     swipl main.pl          (port 8080)
%     swipl main.pl 8081     (another port)
% =====================================================================

:- initialization(main, main).

:- ensure_loaded(knowledge_base).   % knowledge base: facts
:- ensure_loaded(rules).            % knowledge base: rules
:- ensure_loaded(engine).           % inference engine + working memory
:- ensure_loaded(explanation).      % explanation facility
:- ensure_loaded(web_ui).           % user interface

main :-
    current_prolog_flag(argv, Argv),
    (   member(Arg, Argv), atom_number(Arg, Port), integer(Port)
    ->  true
    ;   Port = 8080
    ),
    catch(start_server(Port), Error,
          ( print_message(error, Error),
            format("Could not start on port ~w. Try another port, e.g. swipl main.pl 8081~n", [Port]),
            halt(1) )),
    format("SME Risk Expert System running at http://localhost:~w - open this in your browser. Press Ctrl+C to stop.~n", [Port]),
    thread_get_message(_).          % keep running until stopped
