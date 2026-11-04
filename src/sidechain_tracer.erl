-module(sidechain_tracer).
-behaviour(gen_server).

-include_lib("kernel/include/logger.hrl").

-export([start_link/1, watch/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

-define(SERVER, ?MODULE).
% 50ms
-define(WINDOW_TIME, 50).

start_link(Args) ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, Args, []).

watch(Name) ->
    gen_server:call(?SERVER, {watch_proc, Name}).

init(_Args) ->
    Session = trace:session_create(sidechain_tracer, self(), []),
    trace:process(Session, all, true, [procs]),
    erlang:send_after(?WINDOW_TIME, self(), window),
    {ok, #{
        session => Session,
        spawns => 0,
        exits => 0,
        crashes => 0,
        tripped => false,
        watched => #{},
        sends => #{}
    }}.

handle_call({watch_proc, Name}, _From, #{session := Session, watched := Watched} = State) ->
    case erlang:whereis(Name) of
        undefined ->
            {reply, {error, name_not_registered}, State};
        Pid ->
            case watch_pid(Session, Pid, true) of
                ok -> {reply, ok, State#{watched := Watched#{Name => Pid}}};
                {error, _Reason} = Error -> {reply, Error, State}
            end
    end;
handle_call(_Msg, _From, State) ->
    {reply, {error, not_allowed}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(window, State) ->
    #{spawns := Spawns, exits := Exits, crashes := Crashes, sends := Sends} = State,
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
    if
        map_size(Sends) > 0 -> sidechain_conductor:event({sends, Sends});
        true -> ok
    end,
    erlang:send_after(?WINDOW_TIME, self(), window),
    {noreply, State#{
        spawns := 0, exits := 0, crashes := 0, sends := #{}, watched := rewatch(State)
    }};
handle_info(resume, #{session := Session, watched := Watched} = State) ->
    trace:process(Session, all, true, [procs]),
    set_sends(Session, Watched, true),
    {noreply, State#{tripped := false}};
handle_info(
    {trace, _Parent, spawn, _Child, _MFA},
    #{spawns := Spawns, tripped := false} = State
) when Spawns rem 1000 =:= 0 ->
    check_mailbox(State#{spawns := Spawns + 1});
handle_info({trace, _Parent, spawn, _Child, _MFA}, #{spawns := Spawns} = State) ->
    {noreply, State#{spawns := Spawns + 1}};
handle_info({trace, _Child, exit, Reason}, #{exits := Exits, crashes := Crashes} = State) ->
    case is_crash(Reason) of
        true -> {noreply, State#{exits := Exits + 1, crashes := Crashes + 1}};
        false -> {noreply, State#{exits := Exits + 1}}
    end;
handle_info({trace, Pid, send, _Msg, _To}, #{sends := Sends} = State) ->
    Count = maps:get(Pid, Sends, 0) + 1,
    NewState = State#{sends := Sends#{Pid => Count}},
    if
        Count rem 1000 =:= 0 -> check_mailbox(NewState);
        true -> {noreply, NewState}
    end;
handle_info(_Msg, State) ->
    {noreply, State}.

is_crash(normal) -> false;
is_crash(shutdown) -> false;
is_crash({shutdown, _}) -> false;
% kill is a crash on purpose
is_crash(killed) -> true;
is_crash(_Reason) -> true.

check_mailbox(#{tripped := true} = State) ->
    {noreply, State};
check_mailbox(#{session := Session, watched := Watched} = State) ->
    {message_queue_len, Len} = process_info(self(), message_queue_len),
    if
        Len > 1_000 ->
            trace:process(Session, all, false, [procs]),
            set_sends(Session, Watched, false),
            ?LOG_WARNING("trace tripped mailbox=~p", [Len]),
            erlang:send_after(1000, self(), resume),
            {noreply, State#{tripped := true}};
        true ->
            {noreply, State}
    end.

rewatch(#{tripped := true, watched := Watched}) ->
    Watched;
rewatch(#{session := Session, watched := Watched}) ->
    maps:map(fun(Name, Pid) -> rewatch_name(Session, Name, Pid) end, Watched).

rewatch_name(Session, Name, OldPid) ->
    case erlang:whereis(Name) of
        OldPid ->
            OldPid;
        undefined ->
            OldPid;
        NewPid ->
            case watch_pid(Session, NewPid, true) of
                ok -> NewPid;
                {error, _Reason} -> OldPid
            end
    end.

set_sends(Session, Watched, How) ->
    maps:foreach(fun(_Name, Pid) -> watch_pid(Session, Pid, How) end, Watched).

watch_pid(Session, Pid, How) ->
    try trace:process(Session, Pid, How, [send]) of
        _Count -> ok
    catch
        error:badarg -> {error, noproc}
    end.
