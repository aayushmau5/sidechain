%%%-------------------------------------------------------------------
%% @doc sidechain public API
%% @end
%%%-------------------------------------------------------------------

-module(sidechain_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    logger:add_handler(sidechain_restarts, sidechain_restarts, #{}),
    sidechain_sup:start_link().

stop(_State) ->
    logger:remove_handler(sidechain_restarts),
    ok.

%% internal functions
