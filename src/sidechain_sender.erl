-module(sidechain_sender).
-behaviour(gen_server).

-include_lib("kernel/include/logger.hrl").

-export([start_link/1, ping/0, send/2, send_bundle/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

-define(SERVER, ?MODULE).
-define(HOST, {127, 0, 0, 1}).
-define(PORT, 57110).

-record(state, {
    socket
}).

-type args() :: [binary() | integer() | float()].

start_link(Args) ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, Args, []).

ping() ->
    send(<<"/s_new">>, [<<"ping">>, -1, 0, 1]).

-spec send(binary(), args()) -> ok.
send(Path, Args) ->
    gen_server:cast(?SERVER, {osc, Path, Args}).

-spec send_bundle(integer(), [{binary(), args()}]) -> ok.
send_bundle(UnixMicros, Messages) ->
    gen_server:cast(?SERVER, {osc_bundle, UnixMicros, Messages}).

%% Internal

init(_Args) ->
    {ok, Socket} = gen_udp:open(0, [binary, {active, true}]),
    {ok, #state{socket = Socket}}.

handle_call(_Msg, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast({osc, Path, Args}, #state{socket = Socket} = State) ->
    ok = gen_udp:send(Socket, ?HOST, ?PORT, sidechain_osc:encode_message(Path, Args)),
    {noreply, State};

handle_cast({osc_bundle, UnixMicros, Messages}, #state{socket = Socket} = State) ->
    ok = gen_udp:send(Socket, ?HOST, ?PORT, sidechain_osc:encode_bundle(sidechain_osc:timetag(UnixMicros), Messages)),
    {noreply, State}.

handle_info({udp, Socket, _IP, _Port, Data}, #state{socket = Socket} = State) ->
    ?LOG_WARNING("~p", [Data]),
    {noreply, State};

handle_info(_Msg, State) ->
    {noreply, State}.
