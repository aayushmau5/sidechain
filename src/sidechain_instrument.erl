-module(sidechain_instrument).
-behaviour(sidechain_mode).
-moduledoc "Instrument mode.".

-export([init/1, handle_event/2, tick/1]).

init(Group) ->
    {[], #{
        group => Group, step => 0, utilization => 0, spawns => 0, exits => 0
    }}.

handle_event({levels, #{utilization := W}}, State) ->
    {[], State#{utilization := W}};
handle_event({spawns, N}, #{spawns := Spawns} = State) ->
    {[], State#{spawns := Spawns + N}};
handle_event({exits, N}, #{exits := Exits} = State) ->
    {[], State#{exits := Exits + N}};
handle_event(_Event, State) ->
    {[], State}.

tick(#{step := Step} = State) ->
    KickNotes = kick(State),
    {HatNotes, State1} = hat(State),
    {SnareNotes, State2} = snare(State1),
    {KickNotes ++ HatNotes ++ SnareNotes, State2#{step := (Step + 1) rem 16}}.

kick(#{step := Step, utilization := W, group := Group}) ->
    case lists:member(Step, kick_steps(W)) of
        true -> [{<<"/s_new">>, [<<"kick">>, -1, 0, Group]}];
        false -> []
    end.

kick_steps(W) when W < 0.2 -> [0, 8];
kick_steps(W) when W < 0.6 -> [0, 4, 8, 12];
kick_steps(_W) -> [0, 4, 8, 12, 14].

hat(#{spawns := 0} = State) ->
    {[], State};
hat(#{spawns := Spawns, group := Group} = State) ->
    Amp = 0.05 + count_to_step(Spawns) * 0.04,
    {[{<<"/s_new">>, [<<"hat">>, -1, 0, Group, <<"amp">>, Amp]}], State#{spawns := 0}}.

count_to_step(Count) ->
    min(trunc(math:log10(Count)), 4).

snare(#{step := Step, exits := Exits, group := Group} = State) when
    Exits > 0, (Step =:= 4 orelse Step =:= 12)
->
    {[{<<"/s_new">>, [<<"snare">>, -1, 0, Group]}], State#{exits := 0}};
snare(State) ->
    {[], State}.
