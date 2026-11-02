-module(sidechain_osc).
-export([encode_message/2, pad/1, encode_arg/1, type_tag/1, timetag/1, encode_bundle/2]).

-type arg() :: integer() | float() | binary().

-define(NTP_EPOCH_OFFSET, 2_208_988_800).

-spec encode_message(binary(), [arg()]) -> binary().
encode_message(Path, Args) ->
    Pairs = [encode_arg(X) || X <- Args],
    {Types, Bins} = lists:unzip(Pairs),
    Tag = type_tag(Types),
    list_to_binary([pad(Path), Tag, Bins]).

% FYI: If the integer is big, squishing them into 32-bit results in wrap around or truncation
-spec encode_arg(arg()) -> {char(), binary()}.
encode_arg(Arg) when is_integer(Arg) -> {$i, <<Arg:32/big-signed-integer>>};
encode_arg(Arg) when is_float(Arg) -> {$f, <<Arg:32/float>>};
encode_arg(Arg) when is_binary(Arg) -> {$s, pad(Arg)}.

-spec type_tag([char()]) -> binary().
type_tag(Types) ->
    L = list_to_binary(Types),
    pad(<<",", L/binary>>).

-doc "Pads the binary (string) with zero bytes".
-spec pad(binary()) -> binary().
pad(Bin) ->
    Size = byte_size(Bin),
    ZeroBits = (4 - (Size rem 4)) * 8,
    <<Bin/binary, 0:ZeroBits>>.

% Converts Unix Epoch time(until microseconds) into NTP Epoch Time
-spec timetag(integer()) -> binary().
timetag(UnixMicros) ->
    Seconds = UnixMicros div 1_000_000 + ?NTP_EPOCH_OFFSET,
    Fraction = (UnixMicros rem 1_000_000) * (1 bsl 32) div 1_000_000,
    <<Seconds:32, Fraction:32>>.

% OSC messages can form a bundle
% We use timetag to tell OSC controller to play a synth at a particular time.
% We also bundle for chords(multiple /s_new).
-spec encode_bundle(binary(), [{binary(), [arg()]}]) -> binary().
encode_bundle(TimeTag, Messages) ->
    Elements = [encode_element(Path, Args) || {Path, Args} <- Messages],
    list_to_binary([<<"#bundle", 0>>, TimeTag, Elements]).

encode_element(Path, Args) ->
    Msg = encode_message(Path, Args),
    <<(byte_size(Msg)):32, Msg/binary>>.
