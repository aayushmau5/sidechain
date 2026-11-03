-module(sidechain_restarts).
-behaviour(logger_handler).
-moduledoc "Logger handler that turns supervisor child_terminated reports into restart events.".

-export([log/2]).

log(#{msg := {report, #{label := {supervisor, child_terminated}, report := Report}}}, _Config) ->
    Offender = proplists:get_value(offender, Report, []),
    Id = proplists:get_value(id, Offender),
    sidechain_conductor:event({restart, Id});
log(_Event, _Config) ->
    ok.
