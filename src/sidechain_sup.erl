%%%-------------------------------------------------------------------
%% @doc sidechain top level supervisor.
%% @end
%%%-------------------------------------------------------------------

-module(sidechain_sup).

-behaviour(supervisor).

-export([start_link/0]).

-export([init/1]).

-define(SERVER, ?MODULE).

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

%% sup_flags() = #{strategy => strategy(),         % optional
%%                 intensity => non_neg_integer(), % optional
%%                 period => pos_integer()}        % optional
%% child_spec() = #{id => child_id(),       % mandatory
%%                  start => mfargs(),      % mandatory
%%                  restart => restart(),   % optional
%%                  shutdown => shutdown(), % optional
%%                  type => worker(),       % optional
%%                  modules => modules()}   % optional
init([]) ->
    SupFlags = #{
        strategy => one_for_one,
        intensity => 5,
        period => 1
    },
    ChildSpecs = [
        #{
            id => sidechain_sender,
            start => {sidechain_sender, start_link, [[]]}
        },
        #{
            id => sidechain_conductor,
            start => {sidechain_conductor, start_link, [[]]}
        },
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

%% internal functions
