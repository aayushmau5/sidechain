-module(sidechain_mode).

% One OSC message
-type note() :: {binary(), [integer() | float() | binary()]}.
-type event() ::
    {levels, map()}
    | {spawns, non_neg_integer()}
    | {exits, non_neg_integer()}
    | {crashes, non_neg_integer()}
    | {sends, #{pid() => pos_integer()}}
    | {restart, term()}
    | long_gc.

-export_type([note/0, event/0]).

-callback init(Group :: integer()) -> {[note()], State :: term()}.
-callback handle_event(event(), State :: term()) -> {[note()], State :: term()}.
-callback tick(State :: term()) -> {[note()], State :: term()}.
