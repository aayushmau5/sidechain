-module(sidechain_load_sup).
-behaviour(supervisor).

-export([start_link/0, worker_names/0]).
-export([init/1]).

-define(SERVER, ?MODULE).
-define(WORKERS, 4).

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

init([]) ->
    SupFlags = #{
        strategy => one_for_one,
        intensity => 3,
        period => 5
    },
    ChildSpecs = [child(N) || N <- lists:seq(1, ?WORKERS)],
    {ok, {SupFlags, ChildSpecs}}.

child(N) ->
    #{
        id => sidechain_load_worker:name(N),
        start => {sidechain_load_worker, start_link, [N, ?WORKERS]}
    }.

worker_names() ->
    [sidechain_load_worker:name(N) || N <- lists:seq(1, ?WORKERS)].
