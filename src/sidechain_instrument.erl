-module(sidechain_instrument).
-behaviour(sidechain_mode).
-moduledoc "Instrument mode.".

-export([init/1, handle_event/2, tick/1]).

-define(PAD, 2000).
-define(SCALE, [440.0, 523.25, 587.33, 659.25, 783.99]).
-define(CHORDS, [
    {220.0, 261.63, 329.63},
    {174.61, 220.0, 261.63},
    {196.0, 261.63, 329.63},
    {196.0, 246.94, 293.66}
]).

init(Group) ->
    {[{<<"/s_new">>, [<<"pad">>, ?PAD, 0, Group]}], #{
        group => Group,
        step => 0,
        utilization => 0,
        spawns => 0,
        exits => 0,
        chord => 0,
        stab_pending => false,
        chord_pending => false,
        pending_sends => #{}
    }}.

handle_event({levels, #{utilization := W}}, State) ->
    {[], State#{utilization := W}};
handle_event({spawns, N}, #{spawns := Spawns} = State) ->
    {[], State#{spawns := Spawns + N}};
handle_event({exits, N}, #{exits := Exits} = State) ->
    {[], State#{exits := Exits + N}};
handle_event({sends, Counts}, #{pending_sends := Pending} = State) ->
    {[], State#{pending_sends := maps:merge(Pending, Counts)}};
handle_event({crashes, _N}, State) ->
    {[], State#{stab_pending := true}};
handle_event({restart, _Id}, State) ->
    {[], State#{chord_pending := true}};
handle_event(_Event, State) ->
    {[], State}.

tick(#{step := Step} = State) ->
    KickNotes = kick(State),
    {HatNotes, State1} = hat(State),
    {SnareNotes, State2} = snare(State1),
    {StabNotes, State3} = stab(State2),
    {ChordNotes, State4} = chord(State3),
    {MelodyNotes, State5} = melody(State4),
    Notes = KickNotes ++ HatNotes ++ SnareNotes ++ StabNotes ++ ChordNotes ++ MelodyNotes,
    {Notes, State5#{step := (Step + 1) rem 16}}.

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

stab(#{stab_pending := true, group := Group} = State) ->
    {[{<<"/s_new">>, [<<"stab">>, -1, 0, Group]}], State#{stab_pending := false}};
stab(State) ->
    {[], State}.

chord(#{step := 0, chord_pending := true, chord := Chord} = State) ->
    Next = (Chord + 1) rem length(?CHORDS),
    {F1, F2, F3} = lists:nth(Next + 1, ?CHORDS),
    Note = {<<"/n_set">>, [?PAD, <<"f1">>, F1, <<"f2">>, F2, <<"f3">>, F3]},
    {[Note], State#{chord := Next, chord_pending := false}};
chord(State) ->
    {[], State}.

melody(#{pending_sends := Pending, group := Group} = State) ->
    Notes = [melody_note(Pid, Group) || Pid <- maps:keys(Pending)],
    {Notes, State#{pending_sends := #{}}}.

melody_note(Pid, Group) ->
    Freq = lists:nth(erlang:phash2(Pid, 5) + 1, ?SCALE),
    {<<"/s_new">>, [<<"ping">>, -1, 0, Group, <<"freq">>, Freq]}.
