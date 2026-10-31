-module(sidechain_osc_tests).
-include_lib("eunit/include/eunit.hrl").

empty_pad_test() ->
    Padded = sidechain_osc:pad(<<>>),
    ?assertEqual(<<0, 0, 0, 0>>, Padded),
    ?assertEqual(4, byte_size(Padded)).

single_pad_test() ->
    Padded = sidechain_osc:pad(<<"a">>),
    ?assertEqual(<<"a", 0, 0, 0>>, Padded),
    ?assertEqual(4, byte_size(Padded)).

default_pad_test() ->
    Padded = sidechain_osc:pad(<<"default">>),
    ?assertEqual(8, byte_size(Padded)).

ping_pad_test() ->
    Padded = sidechain_osc:pad(<<"ping">>),
    ?assertEqual(8, byte_size(Padded)).

encode_integer_test() ->
    Encoded = sidechain_osc:encode_arg(1000),
    ?assertEqual({$i, <<0, 0, 3, 232>>}, Encoded).

encode_neg_integer_test() ->
    Encoded = sidechain_osc:encode_arg(-1),
    ?assertEqual({$i, <<255, 255, 255, 255>>}, Encoded).

encode_float_test() ->
    Encoded = sidechain_osc:encode_arg(440.0),
    ?assertEqual({$f, <<67, 220, 0, 0>>}, Encoded).

encode_string_test() ->
    Encoded = sidechain_osc:encode_arg(<<"ping">>),
    ?assertEqual({$s, <<"ping", 0:32>>}, Encoded).

encode_error_test() ->
    ?assertError(function_clause, sidechain_osc:encode_arg(foo)).

type_tag_test() ->
    ?assertEqual(<<",", 0, 0, 0>>, sidechain_osc:type_tag([])),
    ?assertEqual(<<",siif", 0, 0, 0>>, sidechain_osc:type_tag([$s, $i, $i, $f])).

encode_message_test() ->
    Decoded1 = binary:decode_hex(<<"2f735f6e657700002c7369696900000064656661756c7400000003e80000000000000001">>),
    ?assertEqual(Decoded1, sidechain_osc:encode_message(<<"/s_new">>, [<<"default">>, 1000, 0, 1])),

    Decoded2 = binary:decode_hex(<<"2f735f6e657700002c7369696900000064656661756c7400ffffffff0000000000000001">>),
    ?assertEqual(Decoded2, sidechain_osc:encode_message(<<"/s_new">>, [<<"default">>, -1, 0, 1])),

    Decoded3 = binary:decode_hex(<<"2f735f6e657700002c7369696973660070696e6700000000ffffffff0000000000000001667265710000000043dc0000">>),
    ?assertEqual(Decoded3, sidechain_osc:encode_message(<<"/s_new">>, [<<"ping">>, -1, 0, 1, <<"freq">>, 440.0])),

    Decoded4 = binary:decode_hex(<<"2f6e5f66726565002c690000000003e8">>),
    ?assertEqual(Decoded4, sidechain_osc:encode_message(<<"/n_free">>, [1000])),

    Decoded5 = binary:decode_hex(<<"2f675f66726565416c6c00002c69000000000001">>),
    ?assertEqual(Decoded5, sidechain_osc:encode_message(<<"/g_freeAll">>, [1])),

    Decoded6 = binary:decode_hex(<<"2f737461747573002c000000">>),
    ?assertEqual(Decoded6, sidechain_osc:encode_message(<<"/status">>, [])).
