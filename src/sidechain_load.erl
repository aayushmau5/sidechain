-module(sidechain_load).
-moduledoc "Commands for stressing the node on purpose.".

-export([start/0, kill/1, burst/1, busy/1, crash_loop/2, ring/2, alloc/1]).

-define(ALLOC_HOLD, 2000).

start() ->
    Spec = #{
        id => sidechain_load_sup,
        start => {sidechain_load_sup, start_link, []},
        restart => temporary,
        type => supervisor
    },
    supervisor:start_child(sidechain_sup, Spec).

kill(N) ->
    case whereis(sidechain_load_worker:name(N)) of
        undefined ->
            {error, not_running};
        Pid ->
            exit(Pid, kill),
            ok
    end.

burst(N) ->
    [spawn(fun() -> ok end) || _ <- lists:seq(1, N)],
    ok.

busy(Ms) ->
    Deadline = erlang:monotonic_time(millisecond) + Ms,
    N = erlang:system_info(schedulers_online),
    [spawn(fun() -> spin(Deadline) end) || _ <- lists:seq(1, N)],
    ok.

crash_loop(Times, Ms) ->
    spawn(fun() -> crash_step(Times, Ms) end),
    ok.

ring(Hops, Ms) ->
    case whereis(sidechain_load_sup) of
        undefined ->
            {error, not_running};
        _Pid ->
            [sidechain_tracer:watch(Name) || Name <- sidechain_load_sup:worker_names()],
            gen_server:cast(sidechain_load_worker:name(1), {token, Hops, Ms}),
            ok
    end.

alloc(Items) ->
    spawn(fun() -> hold(lists:seq(1, Items)) end),
    ok.

% Internal

spin(Deadline) ->
    case erlang:monotonic_time(millisecond) < Deadline of
        true -> spin(Deadline);
        false -> ok
    end.

crash_step(0, _Ms) ->
    ok;
crash_step(Times, Ms) ->
    case kill(1) of
        ok ->
            timer:sleep(Ms),
            crash_step(Times - 1, Ms);
        {error, not_running} ->
            ok
    end.

hold(List) ->
    timer:sleep(?ALLOC_HOLD),
    length(List).
