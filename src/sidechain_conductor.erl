-module(sidechain_conductor).
-behaviour(gen_server).
-moduledoc "Passes collector events to the current mode and plays the notes it returns.".
% Grid: 125ms = a sixteenth note at 120 BPM

-export([start_link/1, event/1, switch/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

-define(SERVER, ?MODULE).
-define(MODE, sidechain_ambient).
-define(GROUP, 100).
-define(INTERVAL, 125).
-define(LOOKAHEAD, 100).
-define(START_MARGIN, 200).

-record(state, {
    mode,
    mode_state,
    next_tick,
    signals,
    pending,
    sampled_at
}).

start_link(Args) ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, Args, []).

event(Event) ->
    Node = application:get_env(sidechain, conductor_node, node()),
    gen_server:cast({?SERVER, Node}, {event, Event}).

switch(Mode) ->
    gen_server:call(?SERVER, {switch_mode, Mode}).

init(_Args) ->
    % restart begins from silence
    sidechain_sender:send(<<"/n_free">>, [?GROUP]),
    sidechain_sender:send(<<"/g_new">>, [?GROUP, 0, 1]),
    {Notes, ModeState} = ?MODE:init(?GROUP),
    Now = erlang:monotonic_time(millisecond),
    play(Now + ?LOOKAHEAD, Notes),
    Next = Now + ?START_MARGIN,
    schedule_wake(Next),
    {ok, #state{
        mode = ?MODE,
        mode_state = ModeState,
        next_tick = Next,
        signals = new_signals(),
        pending = zero_pending(),
        sampled_at = Now
    }}.

handle_call({switch_mode, Mode}, _From, State) ->
    case code:ensure_loaded(Mode) of
        {module, M} ->
            case erlang:function_exported(M, init, 1) of
                true ->
                    {Notes, ModeState} = M:init(?GROUP),
                    play(erlang:monotonic_time(millisecond) + ?LOOKAHEAD, [
                        {<<"/g_freeAll">>, [?GROUP]} | Notes
                    ]),
                    {reply, ok, State#state{mode = M, mode_state = ModeState}};
                false ->
                    {reply, {error, unknown_mode}, State}
            end;
        {error, _Reason} ->
            {reply, {error, unknown_mode}, State}
    end;
handle_call(_Msg, _From, State) ->
    {reply, {error, unsupported_call}, State}.

handle_cast({event, Event}, #state{mode = Mode, mode_state = ModeState} = State) ->
    {Notes, NewModeState} = Mode:handle_event(Event, ModeState),
    play(erlang:monotonic_time(millisecond) + ?LOOKAHEAD, Notes),
    {noreply, track(Event, State#state{mode_state = NewModeState})};
handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(tick, #state{mode = Mode, mode_state = ModeState, next_tick = Next} = State) ->
    {Notes, NewModeState} = Mode:tick(ModeState),
    play(Next, Notes),
    NewNext = Next + ?INTERVAL,
    schedule_wake(NewNext),
    {noreply, State#state{mode_state = NewModeState, next_tick = NewNext}};
handle_info(_Msg, State) ->
    {noreply, State}.

%% Internal

schedule_wake(BeatTime) ->
    % ticks 100ms early
    erlang:send_after(BeatTime - ?LOOKAHEAD, self(), tick, [{abs, true}]).

play(_At, []) ->
    ok;
play(At, Notes) ->
    sidechain_sender:send_bundle(unix_micros(At), Notes).

unix_micros(MonotonicMs) ->
    (MonotonicMs + erlang:time_offset(millisecond)) * 1000.

track({levels, Levels}, #state{signals = Signals, pending = Pending, sampled_at = Then} = State) ->
    Now = erlang:monotonic_time(millisecond),
    Readings = maps:merge(Levels, rates(Pending, max(Now - Then, 1))),
    NewSignals = update_signals(Readings, Signals),
    sidechain_visuals:signals(NewSignals),
    State#state{
        signals = NewSignals,
        pending = zero_pending(),
        sampled_at = Now
    };
track({spawns, N}, State) ->
    add_pending(spawns, N, State);
track({exits, N}, State) ->
    add_pending(exits, N, State);
track(_Event, State) ->
    State.

rates(Pending, ElapsedMs) ->
    maps:map(fun(_Name, Count) -> Count * 1000 / ElapsedMs end, Pending).

new_signals() ->
    maps:map(fun(_Name, Scale) -> sidechain_signal:new(Scale) end, scales()).

update_signals(Readings, Signals) ->
    maps:map(
        fun(Name, Signal) ->
            case Readings of
                #{Name := Reading} -> sidechain_signal:update(Reading, Signal);
                #{} -> Signal
            end
        end,
        Signals
    ).

add_pending(Name, N, #state{pending = Pending} = State) ->
    State#state{pending = maps:update_with(Name, fun(Old) -> Old + N end, Pending)}.

zero_pending() -> #{spawns => 0, exits => 0}.

scales() ->
    #{
        utilization => {linear, 0, 1},
        run_queue => {log, 0, 3},
        processes => {log, 1, 6},
        reductions => {log, 4, 9},
        gc => {log, 1, 5},
        gc_words => {log, 4, 9},
        io => {log, 3, 8},
        memory => {log, 7, 10},
        memory_processes => {log, 7, 10},
        memory_binary => {log, 5, 9},
        memory_ets => {log, 5, 9},
        spawns => {log, 0, 5},
        exits => {log, 0, 5}
    }.
