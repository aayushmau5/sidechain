-module(sidechain_sampler).
-behaviour(gen_server).

-export([start_link/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

-define(SERVER, ?MODULE).
-define(TICK_RATE, 100). % 100ms
-define(OSC_NEW, <<"/s_new">>).
-define(OSC_DEF, <<"pulse">>).
-define(OSC_FREE, <<"/n_free">>).
-define(OSC_UPDATE, <<"/n_set">>).
-define(OSC_NODE_ID, 1000).

start_link(Args) ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, Args, []).

init(_Args) ->
    sidechain_sender:send(?OSC_FREE, [?OSC_NODE_ID]),
    sidechain_sender:send(?OSC_NEW, [?OSC_DEF, ?OSC_NODE_ID, 0, 1, <<"rate">>, 1.0]),
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
    Rate = utilization_to_rate(W),
    sidechain_sender:send(?OSC_UPDATE, [?OSC_NODE_ID, <<"rate">>, Rate]),
    erlang:send_after(?TICK_RATE, self(), tick),
    {noreply, State#{scheduler_sample := S2}};

handle_info(_Msg, State) ->
    {noreply, State}.

-spec utilization_to_rate(float()) -> float().
utilization_to_rate(W) ->
    Clamped = min(W, 1.0),
    Bpm = 50 + Clamped * 70,
    Bpm / 60.
