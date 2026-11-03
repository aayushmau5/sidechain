-module(sidechain_sampler).
-behaviour(gen_server).

-export([start_link/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

-define(SERVER, ?MODULE).
% 100ms
-define(TICK_RATE, 100).

start_link(Args) ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, Args, []).

init(_Args) ->
    Sample = scheduler:sample(),
    erlang:send_after(?TICK_RATE, self(), tick),
    {ok, #{scheduler_sample => Sample}}.

handle_call(_Msg, _From, State) ->
    {reply, {error, unsupported_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(tick, #{scheduler_sample := S1} = State) ->
    S2 = scheduler:sample(),
    Utilization = scheduler:utilization(S1, S2),
    {weighted, W, _} = lists:keyfind(weighted, 1, Utilization),
    sidechain_conductor:event({levels, #{utilization => W, memory => erlang:memory(total)}}),
    erlang:send_after(?TICK_RATE, self(), tick),
    {noreply, State#{scheduler_sample := S2}};
handle_info(_Msg, State) ->
    {noreply, State}.
