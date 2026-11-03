-module(sidechain_ambient).
-behaviour(sidechain_mode).
-moduledoc "Background mode: loose chimes over a drone.".

-export([init/1, handle_event/2, tick/1]).
-define(SCALE, [440.0, 523.25, 587.33, 659.25, 783.99]).

init(Group) ->
    {[{<<"/s_new">>, [<<"pulse">>, 1000, 0, Group, <<"rate">>, 1.0]}], #{
        group => Group, breath_until => 0
    }}.

handle_event({levels, #{utilization := W}}, State) ->
    Rate = utilization_to_rate(W),
    {[{<<"/n_set">>, [1000, <<"rate">>, Rate]}], State};
handle_event({spawns, N}, #{group := Group} = State) ->
    {[play(N, 1.0, Group)], State};
handle_event({exits, N}, #{group := Group} = State) ->
    {[play(N, 0.5, Group)], State};
handle_event(long_gc, #{group := Group, breath_until := BreathUntil} = State) when
    BreathUntil =:= 0
->
    {[{<<"/s_new">>, [<<"breath">>, -1, 0, Group]}], State#{breath_until := 24}};
handle_event(_Event, State) ->
    {[], State}.

tick(#{breath_until := BreathUntil} = State) ->
    if
        BreathUntil > 0 ->
            {[], State#{breath_until := BreathUntil - 1}};
        true ->
            {[], State}
    end.

-spec utilization_to_rate(float()) -> float().
utilization_to_rate(W) ->
    Clamped = min(W, 1.0),
    Bpm = 50 + Clamped * 70,
    Bpm / 60.

play(Count, Octave, Group) ->
    Freq = lists:nth(count_to_step(Count) + 1, ?SCALE) * Octave,
    {<<"/s_new">>, [<<"ping">>, -1, 0, Group, <<"freq">>, Freq]}.

count_to_step(Count) ->
    min(trunc(math:log10(Count)), 4).
