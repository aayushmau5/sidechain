-module(sidechain_tracer).
-behaviour(gen_server).

-include_lib("kernel/include/logger.hrl").

-export([start_link/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

-define(SERVER, ?MODULE).
% 50ms
-define(WINDOW_TIME, 50).

start_link(Args) ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, Args, []).

init(_Args) ->
    Session = trace:session_create(sidechain_tracer, self(), []),
    trace:process(Session, all, true, [procs]),
    erlang:send_after(?WINDOW_TIME, self(), window),
    {ok, #{session => Session, spawns => 0, exits => 0, crashes => 0, tripped => false}}.

handle_call(_Msg, _From, State) ->
    {reply, {error, not_allowed}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(window, #{spawns := Spawns, exits := Exits, crashes := Crashes} = State) ->
    if
        max(Spawns, Exits) > 0 ->
            ?LOG_INFO("spawns=~p exits=~p crashes=~p", [Spawns, Exits, Crashes]);
        true ->
            ok
    end,
    if
        Spawns > 0 -> sidechain_conductor:event({spawns, Spawns});
        true -> ok
    end,
    if
        Exits > 0 -> sidechain_conductor:event({exits, Exits});
        true -> ok
    end,
    if
        Crashes > 0 -> sidechain_conductor:event({crashes, Crashes});
        true -> ok
    end,
    erlang:send_after(?WINDOW_TIME, self(), window),
    {noreply, State#{spawns := 0, exits := 0, crashes := 0}};
handle_info(resume, #{session := Session} = State) ->
    trace:process(Session, all, true, [procs]),
    {noreply, State#{tripped := false}};
handle_info(
    {trace, _Parent, spawn, _Child, _MFA},
    #{session := Session, spawns := Spawns, tripped := false} = State
) when Spawns rem 1000 =:= 0 ->
    {message_queue_len, Len} = process_info(self(), message_queue_len),
    if
        Len > 1_000 ->
            trace:process(Session, all, false, [procs]),
            ?LOG_WARNING("trace tripped mailbox=~p", [Len]),
            erlang:send_after(1000, self(), resume),
            {noreply, State#{spawns := Spawns + 1, tripped := true}};
        true ->
            {noreply, State#{spawns := Spawns + 1}}
    end;
handle_info({trace, _Parent, spawn, _Child, _MFA}, #{spawns := Spawns} = State) ->
    {noreply, State#{spawns := Spawns + 1}};
handle_info({trace, _Child, exit, Reason}, #{exits := Exits, crashes := Crashes} = State) ->
    case is_crash(Reason) of
        true -> {noreply, State#{exits := Exits + 1, crashes := Crashes + 1}};
        false -> {noreply, State#{exits := Exits + 1}}
    end;
handle_info(_Msg, State) ->
    {noreply, State}.

is_crash(normal) -> false;
is_crash(shutdown) -> false;
is_crash({shutdown, _}) -> false;
% kill is a crash on purpose
is_crash(killed) -> true;
is_crash(_Reason) -> true.
