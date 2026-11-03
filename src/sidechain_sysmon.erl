-module(sidechain_sysmon).
-behaviour(gen_server).

-export([start_link/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

-define(SERVER, ?MODULE).

start_link(Args) ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, Args, []).

init(_Args) ->
    erlang:system_monitor(self(), [{long_gc, 20}]),
    {ok, #{}}.

handle_call(_Msg, _From, State) ->
    {reply, {error, unsupported_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({monitor, _Pid, long_gc, _Info}, State) ->
    sidechain_conductor:event(long_gc),
    {noreply, State};
handle_info(_Msg, State) ->
    {noreply, State}.
