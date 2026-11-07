-module(sidechain_remote).
-moduledoc "Moves the collectors onto another node.".

-export([attach/1, detach/0]).

-define(MODULES, [
    sidechain_agent,
    sidechain_collectors_sup,
    sidechain_sampler,
    sidechain_tracer,
    sidechain_sysmon,
    sidechain_restarts,
    sidechain_conductor
]).
-define(START_TIMEOUT, 5000).

attach(Node) ->
    case whereis(sidechain_collectors_sup) of
        undefined -> {error, already_attached};
        _Pid -> attach_to(Node)
    end.

detach() ->
    case application:get_env(sidechain, attached_to) of
        undefined ->
            {error, not_attached};
        {ok, Node} ->
            stop_agent(Node),
            application:unset_env(sidechain, attached_to),
            {ok, _Pid} = supervisor:restart_child(sidechain_sup, sidechain_collectors_sup),
            ok
    end.

attach_to(Node) ->
    case push(Node, ?MODULES) of
        ok -> move_collectors(Node);
        {error, _Reason} = Error -> Error
    end.

push(_Node, []) ->
    ok;
push(Node, [Module | Rest]) ->
    {Module, Binary, File} = code:get_object_code(Module),
    case rpc:call(Node, code, load_binary, [Module, File, Binary]) of
        {module, Module} -> push(Node, Rest);
        Other -> {error, {push_failed, Module, Other}}
    end.

move_collectors(Node) ->
    ok = supervisor:terminate_child(sidechain_sup, sidechain_collectors_sup),
    case start_agent(Node) of
        ok ->
            application:set_env(sidechain, attached_to, Node),
            ok;
        {error, _Reason} = Error ->
            {ok, _Pid} = supervisor:restart_child(sidechain_sup, sidechain_collectors_sup),
            Error
    end.

start_agent(Node) ->
    {Pid, Ref} = spawn_monitor(Node, sidechain_agent, run, [self(), node(), ?MODULES]),
    receive
        {Pid, Result} ->
            demonitor(Ref, [flush]),
            Result;
        {'DOWN', Ref, process, Pid, Reason} ->
            {error, Reason}
    after ?START_TIMEOUT ->
        demonitor(Ref, [flush]),
        {error, timeout}
    end.

stop_agent(Node) ->
    Ref = erlang:monitor(process, {sidechain_agent, Node}),
    {sidechain_agent, Node} ! stop,
    receive
        {'DOWN', Ref, process, _, _} -> ok
    after ?START_TIMEOUT ->
        demonitor(Ref, [flush]),
        ok
    end.
