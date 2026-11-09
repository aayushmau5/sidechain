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
    {ok, #{
        scheduler_sample => Sample,
        counters => read_counters(),
        time => erlang:monotonic_time(millisecond)
    }}.

handle_call(_Msg, _From, State) ->
    {reply, {error, unsupported_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(tick, State) ->
    {Rates, State1} = get_counters(State),
    {Guages, State2} = get_gauges(State1),
    sidechain_conductor:event({levels, maps:merge(Guages, Rates)}),
    erlang:send_after(?TICK_RATE, self(), tick),
    {noreply, State2};
handle_info(_Msg, State) ->
    {noreply, State}.

%% Internal

read_counters() ->
    {Reductions, _SinceLastCall} = erlang:statistics(reductions),
    {GCs, Words, _} = erlang:statistics(garbage_collection),
    {{input, In}, {output, Out}} = erlang:statistics(io),
    #{reductions => Reductions, gc => GCs, gc_words => Words, io => In + Out}.

get_counters(#{counters := C1, time := T1} = State) ->
    C2 = read_counters(),
    T2 = erlang:monotonic_time(millisecond),
    Rates = rates(C1, C2, T2 - T1),
    {Rates, State#{counters := C2, time := T2}}.

get_scheduler_utilization(#{scheduler_sample := Before} = State) ->
    Now = scheduler:sample(),
    Utilization = scheduler:utilization(Before, Now),
    {weighted, W, _} = lists:keyfind(weighted, 1, Utilization),
    {W, State#{scheduler_sample := Now}}.

get_gauges(State) ->
    {W, State1} = get_scheduler_utilization(State),
    Memory = maps:from_list(erlang:memory([total, processes, binary, ets])),
    Gauges = #{
        utilization => W,
        run_queue => erlang:statistics(total_run_queue_lengths_all),
        processes => erlang:system_info(process_count),
        memory => maps:get(total, Memory),
        memory_processes => maps:get(processes, Memory),
        memory_binary => maps:get(binary, Memory),
        memory_ets => maps:get(ets, Memory)
    },
    {Gauges, State1}.

rates(Before, After, ElapsedMs) ->
    maps:map(fun(Name, Now) -> (Now - maps:get(Name, Before)) * 1000 / ElapsedMs end, After).
