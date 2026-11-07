-module(sidechain_visuals).
-behaviour(gen_server).
-moduledoc "Sends plain OSC messages to TouchDesigner.".

-export([start_link/1, send/2, event/1]).
-export([init/1, handle_call/3, handle_cast/2]).

-define(SERVER, ?MODULE).
-define(HOST, {127, 0, 0, 1}).
-define(PORT, 7000).

-record(state, {
    socket,
    counts
}).

-type args() :: [binary() | integer() | float()].

start_link(Args) ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, Args, []).

-spec send(binary(), args()) -> ok.
send(Path, Args) ->
    gen_server:cast(?SERVER, {osc, Path, Args}).

event(Event) ->
    gen_server:cast(?SERVER, {event, Event}).

%% Internal

init(_Args) ->
    {ok, Socket} = gen_udp:open(0, [binary, {active, false}]),
    {ok, #state{socket = Socket, counts = zero_counts()}}.

handle_call(_Msg, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast({osc, Path, Args}, #state{socket = Socket} = State) ->
    send_message(Socket, Path, Args),
    {noreply, State};
handle_cast({event, {levels, #{utilization := W, memory := M}}}, State) ->
    #state{socket = Socket, counts = Counts} = State,
    send_message(Socket, <<"/sidechain/utilization">>, [float(W)]),
    send_message(Socket, <<"/sidechain/memory_mb">>, [M / 1048576]),
    maps:foreach(
        fun(Name, N) ->
            send_message(Socket, <<"/sidechain/", (atom_to_binary(Name))/binary>>, [N])
        end,
        Counts
    ),
    {noreply, State#state{counts = zero_counts()}};
handle_cast({event, Event}, #state{counts = Counts} = State) ->
    {noreply, State#state{counts = count(Event, Counts)}}.

send_message(Socket, Path, Args) ->
    ok = gen_udp:send(Socket, ?HOST, ?PORT, sidechain_osc:encode_message(Path, Args)).

zero_counts() ->
    #{spawns => 0, exits => 0, crashes => 0, long_gc => 0, restarts => 0, sends => 0}.

count({spawns, N}, Counts) -> add(spawns, N, Counts);
count({exits, N}, Counts) -> add(exits, N, Counts);
count({crashes, N}, Counts) -> add(crashes, N, Counts);
count(long_gc, Counts) -> add(long_gc, 1, Counts);
count({restart, _Id}, Counts) -> add(restarts, 1, Counts);
count({sends, PerPid}, Counts) -> add(sends, lists:sum(maps:values(PerPid)), Counts);
count(_Event, Counts) -> Counts.

add(Name, N, Counts) ->
    maps:update_with(Name, fun(Old) -> Old + N end, Counts).
