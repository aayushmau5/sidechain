-module(sidechain_visuals).
-behaviour(gen_server).
-moduledoc "Sends plain OSC messages to TouchDesigner.".

-export([start_link/1, send/2, signals/1]).
-export([init/1, handle_call/3, handle_cast/2]).

-define(SERVER, ?MODULE).
-define(HOST, {127, 0, 0, 1}).
-define(PORT, 7000).

-record(state, {
    socket
}).

-type args() :: [binary() | integer() | float()].

start_link(Args) ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, Args, []).

-spec send(binary(), args()) -> ok.
send(Path, Args) ->
    gen_server:cast(?SERVER, {osc, Path, Args}).

signals(Signals) ->
    gen_server:cast(?SERVER, {signals, Signals}).

%% Internal

init(_Args) ->
    {ok, Socket} = gen_udp:open(0, [binary, {active, false}]),
    {ok, #state{socket = Socket}}.

handle_call(_Msg, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast({osc, Path, Args}, #state{socket = Socket} = State) ->
    send_message(Socket, Path, Args),
    {noreply, State};
handle_cast({signals, Signals}, #state{socket = Socket} = State) ->
    maps:foreach(fun(Name, Signal) -> send_signal(Socket, Name, Signal) end, Signals),
    {noreply, State}.

send_message(Socket, Path, Args) ->
    ok = gen_udp:send(Socket, ?HOST, ?PORT, sidechain_osc:encode_message(Path, Args)).

send_signal(_Socket, _Name, #{level := undefined}) ->
    ok;
send_signal(Socket, Name, #{level := Level, delta := Delta}) ->
    Prefix = <<"/sidechain/", (atom_to_binary(Name))/binary>>,
    send_message(Socket, <<Prefix/binary, "/level">>, [Level]),
    send_message(Socket, <<Prefix/binary, "/delta">>, [Delta]).
