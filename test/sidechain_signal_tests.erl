-module(sidechain_signal_tests).

-include_lib("eunit/include/eunit.hrl").

-define(LOG, {log, 3, 7}).

zero_reading_test() ->
    ?assertEqual(0.0, level(feed([0], ?LOG))).

above_range_test() ->
    ?assertEqual(1.0, level(feed([1.0e9], ?LOG))).

below_range_test() ->
    ?assertEqual(0.0, level(feed([10], ?LOG))).

log_midpoint_test() ->
    ?assert(near(0.5, level(feed([1.0e5], ?LOG)))).

linear_test() ->
    ?assert(near(0.25, level(feed([0.25], {linear, 0, 1})))).

first_delta_test() ->
    ?assertEqual(0.0, delta(feed([1.0e5], ?LOG))).

jump_test() ->
    ?assert(delta(feed([1.0e3, 1.0e7], ?LOG)) > 0.9).

settle_test() ->
    Readings = [1.0e3 | lists:duplicate(300, 1.0e7)],
    ?assert(abs(delta(feed(Readings, ?LOG))) < 0.01).

drop_test() ->
    ?assert(delta(feed([1.0e7, 1.0e3], ?LOG)) < -0.9).

feed(Readings, Scale) ->
    lists:foldl(fun sidechain_signal:update/2, sidechain_signal:new(Scale), Readings).

level(#{level := Level}) -> Level.

delta(#{delta := Delta}) -> Delta.

near(A, B) ->
    abs(A - B) < 0.001.
