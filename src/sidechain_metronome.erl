-module(sidechain_metronome).
-behaviour(gen_server).
-moduledoc "A gen_server that pings on every beat at 120 BPM.".
% 120 beat per minute = 120 / 60 = 2 beats per second
% 1 beat every 500ms
% Lookahead: 100ms == Send pings 100ms early

-export([start_link/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

-define(SERVER, ?MODULE).
-define(INTERVAL, 500).
-define(LOOKAHEAD, 100).
-define(START_MARGIN, 200).

start_link(Args) ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, Args, []).

init(_Args) ->
    Next = erlang:monotonic_time(millisecond) + ?START_MARGIN,
    schedule_wake(Next),
    {ok, #{beat => 0, next_beat => Next}}.

handle_call(_Msg, _From, State) ->
    {reply, {error, not_allowed}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(tick, #{next_beat := Next, beat := Beat} = State) ->
    UnixMicros = (Next + erlang:time_offset(millisecond)) * 1000,
    sidechain_sender:send_bundle(UnixMicros, [
        {<<"/s_new">>, [<<"ping">>, -1, 0, 1, <<"freq">>, freq(Beat)]}
    ]),
    NewNext = Next + ?INTERVAL,
    schedule_wake(NewNext),
    {noreply, State#{next_beat := NewNext, beat := Beat + 1}};
handle_info(_Msg, State) ->
    {noreply, State}.

schedule_wake(BeatTime) ->
    % ticks 100ms early
    erlang:send_after(BeatTime - ?LOOKAHEAD, self(), tick, [{abs, true}]).

% marks every 4th beat with a higher ping: a bar
freq(Beat) when Beat rem 4 =:= 0 -> 1760.0;
freq(_Beat) -> 880.0.
