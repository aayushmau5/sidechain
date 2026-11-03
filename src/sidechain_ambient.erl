-module(sidechain_ambient).
-behaviour(sidechain_mode).
-moduledoc "Background mode: loose chimes over a drone.".

-export([init/1, handle_event/2, tick/1]).

-define(SCALE, [440.0, 523.25, 587.33, 659.25, 783.99]).
% 32MB
-define(MEMORY_BASE, (32 * 1024 * 1024)).
% Bb4: one semitone above A, out of key
-define(CRASH_FREQ, 466.16).
% A4: where Bb wants to fall
-define(RESOLVE_FREQ, 440.0).
% 8 ticks of 125ms = 1s between a crash and the verdict
-define(CRASH_WAIT, 8).

init(Group) ->
    {
        [
            {<<"/s_new">>, [<<"pulse">>, 1000, 0, Group, <<"rate">>, 1.0]},
            {<<"/s_new">>, [<<"drone">>, 1001, 0, Group, <<"freq">>, 55.0, <<"cutoff">>, 400.0]}
        ],
        #{
            group => Group, breath_until => 0, crash_check => 0, restarts => 0
        }
    }.

handle_event({levels, #{utilization := W, memory := M}}, State) ->
    {
        [
            {<<"/n_set">>, [1000, <<"rate">>, utilization_to_rate(W)]},
            {<<"/n_set">>, [1001, <<"cutoff">>, memory_to_cutoff(M)]}
        ],
        State
    };
handle_event({spawns, N}, #{group := Group} = State) ->
    {[play(N, 1.0, Group)], State};
handle_event({exits, N}, #{group := Group} = State) ->
    {[play(N, 0.5, Group)], State};
handle_event({crashes, _N}, #{group := Group} = State) ->
    {[ping(?CRASH_FREQ, Group)], State#{crash_check := ?CRASH_WAIT}};
handle_event({restart, _Id}, #{restarts := Restarts} = State) ->
    {[], State#{restarts := Restarts + 1}};
handle_event(long_gc, #{group := Group, breath_until := BreathUntil} = State) when
    BreathUntil =:= 0
->
    {[{<<"/s_new">>, [<<"breath">>, -1, 0, Group]}], State#{breath_until := 24}};
handle_event(_Event, State) ->
    {[], State}.

tick(State) ->
    {BreathNotes, State1} = breath_tick(State),
    {CrashNotes, State2} = crash_tick(State1),
    {BreathNotes ++ CrashNotes, State2}.

breath_tick(#{breath_until := BreathUntil} = State) when BreathUntil > 0 ->
    {[], State#{breath_until := BreathUntil - 1}};
breath_tick(State) ->
    {[], State}.

crash_tick(#{crash_check := 1, restarts := Restarts, group := Group} = State) when Restarts > 0 ->
    {[ping(?RESOLVE_FREQ, Group)], State#{crash_check := 0, restarts := 0}};
crash_tick(#{crash_check := 1} = State) ->
    {[], State#{crash_check := 0, restarts := 0}};
crash_tick(#{crash_check := Check} = State) when Check > 1 ->
    {[], State#{crash_check := Check - 1}};
crash_tick(State) ->
    {[], State}.

-spec utilization_to_rate(float()) -> float().
utilization_to_rate(W) ->
    Clamped = min(W, 1.0),
    Bpm = 50 + Clamped * 70,
    Bpm / 60.

-spec memory_to_cutoff(non_neg_integer()) -> float().
memory_to_cutoff(Bytes) ->
    Doublings = math:log2(max(Bytes, 1) / ?MEMORY_BASE),
    Clamped = min(max(Doublings, 0.0), 8.0),
    200 + Clamped * 400.

play(Count, Octave, Group) ->
    Freq = lists:nth(count_to_step(Count) + 1, ?SCALE) * Octave,
    ping(Freq, Group).

ping(Freq, Group) ->
    {<<"/s_new">>, [<<"ping">>, -1, 0, Group, <<"freq">>, Freq]}.

count_to_step(Count) ->
    min(trunc(math:log10(Count)), 4).
