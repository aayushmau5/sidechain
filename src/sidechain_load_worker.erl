-module(sidechain_load_worker).
-behaviour(gen_server).

-export([start_link/2, name/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

start_link(N, Total) ->
    gen_server:start_link({local, name(N)}, ?MODULE, {N, Total}, []).

name(N) ->
    list_to_atom("sidechain_load_" ++ integer_to_list(N)).

init({N, Total}) ->
    {ok, #{n => N, total => Total}}.

handle_call(_Msg, _From, State) ->
    {reply, {error, not_allowed}, State}.

handle_cast({token, 0, _Ms}, State) ->
    {noreply, State};
handle_cast({token, Hops, Ms}, State) ->
    erlang:send_after(Ms, self(), {pass, Hops, Ms}),
    {noreply, State};
handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({pass, Hops, Ms}, #{n := N, total := Total} = State) ->
    gen_server:cast(name(N rem Total + 1), {token, Hops - 1, Ms}),
    {noreply, State};
handle_info(_Msg, State) ->
    {noreply, State}.
