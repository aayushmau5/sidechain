-module(sidechain_signal).
-moduledoc "Turns raw readings into a level, a slow baseline and their difference.".

-export([new/1, new/2, update/2]).

-define(ALPHA, 0.02).

-type scale() :: {log, number(), number()} | {linear, number(), number()}.
-type signal() :: #{
    scale := scale(),
    alpha := float(),
    level := float() | undefined,
    baseline := float() | undefined,
    delta := float()
}.

-export_type([scale/0, signal/0]).

-spec new(scale()) -> signal().
new(Scale) ->
    new(Scale, ?ALPHA).

-spec new(scale(), float()) -> signal().
new(Scale, Alpha) ->
    #{scale => Scale, alpha => Alpha, level => undefined, baseline => undefined, delta => 0.0}.

-spec update(number(), signal()) -> signal().
update(Reading, #{scale := Scale, baseline := undefined} = Signal) ->
    Level = level(Reading, Scale),
    Signal#{level := Level, baseline := Level, delta := 0.0};
update(Reading, #{scale := Scale, alpha := Alpha, baseline := Baseline} = Signal) ->
    Level = level(Reading, Scale),
    Signal#{
        level := Level,
        baseline := Baseline + Alpha * (Level - Baseline),
        delta := Level - Baseline
    }.

level(Reading, {log, Lo, Hi}) ->
    normalize(math:log10(1 + max(Reading, 0)), Lo, Hi);
level(Reading, {linear, Lo, Hi}) ->
    normalize(Reading, Lo, Hi).

normalize(X, Lo, Hi) ->
    min(max((X - Lo) / (Hi - Lo), 0.0), 1.0).
