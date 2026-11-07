-module(sidechain_collectors_sup).
-behaviour(supervisor).

-export([start_link/0]).

-export([init/1]).

-define(SERVER, ?MODULE).

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

init([]) ->
    SupFlags = #{
        strategy => one_for_one,
        intensity => 5,
        period => 1
    },
    ChildSpecs = [
        #{
            id => sidechain_sampler,
            start => {sidechain_sampler, start_link, [[]]}
        },
        #{
            id => sidechain_tracer,
            start => {sidechain_tracer, start_link, [[]]}
        },
        #{
            id => sidechain_sysmon,
            start => {sidechain_sysmon, start_link, [[]]}
        }
    ],
    {ok, {SupFlags, ChildSpecs}}.
