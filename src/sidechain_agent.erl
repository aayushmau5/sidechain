-module(sidechain_agent).
-moduledoc "Runs the collectors on the target node, then removes itself.".

-export([run/3]).

% run(self(), node(), ?MODULES)
run(Caller, Observer, Modules) ->
    process_flag(trap_exit, true),
    register(?MODULE, self()),
    application:set_env(sidechain, conductor_node, Observer),
    logger:add_handler(sidechain_restarts, sidechain_restarts, #{}),
    case sidechain_collectors_sup:start_link() of
        {ok, Sup} ->
            Caller ! {self(), ok},
            wait(Sup, Observer),
            stop_collectors(Sup);
        {error, Reason} ->
            Caller ! {self(), {error, Reason}}
    end,
    logger:remove_handler(sidechain_restarts),
    application:unset_env(sidechain, conductor_node),
    unload(lists:delete(?MODULE, Modules)),
    unload_self().

wait(Sup, Observer) ->
    Ref = erlang:monitor(process, {sidechain_sup, Observer}),
    receive
        {'DOWN', Ref, process, _, _} -> ok;
        {'EXIT', Sup, _Reason} -> ok;
        stop -> ok
    end.

stop_collectors(Sup) ->
    Ref = erlang:monitor(process, Sup),
    exit(Sup, shutdown),
    receive
        {'DOWN', Ref, process, _, _} -> ok
    end.

unload(Modules) ->
    lists:foreach(fun unload_module/1, Modules).

unload_module(M) ->
    code:purge(M),
    code:delete(M),
    code:purge(M).

unload_self() ->
    code:purge(?MODULE),
    code:delete(?MODULE),
    spawn(code, purge, [?MODULE]).
