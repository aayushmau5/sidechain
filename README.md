sidechain
=====

![Logo](logo.jpg)

Hear your BEAM.

Sidechain converts your BEAM's metrics into sounds using OSC.

## How it works

```
sampler ─┐
tracer  ─┼─> conductor ─> mode ─> OSC ─> sender -> scsynth (UDP 127.0.0.1:57110)
sysmon  ─┘
```

- **Collectors** count what the node does in short windows and send small summaries. The sampler reads scheduler utilization and memory every 100ms. The tracer counts spawns, exits and crashes. Sysmon reports long garbage collections.
- **The conductor** keeps a clock of sixteenth notes at 120 bpm and passes each summary to the current mode.
- **A mode** turns summaries into notes. Ambient is a calm background. Instrument is a beat you play by stressing the node.
- **The sender** sends the notes to scsynth as OSC bundles, timed about 100ms ahead so they play on time.

### Working with remote node

Tracing only works from inside the node being traced, so the collectors move to the target. The conductor and sender stay on your machine.

```
observer                                 target
--------                                 ------
attach(target)
  - push collector code ─────────────────> loaded in memory, nothing on disk
  - stop local collectors
  - start agent ─────────────────────────> agent starts the collectors
               <───────────────────────── ok

conductor <──────── summaries ─────────── collectors

detach()
  - stop ────────────────────────────────> agent stops the collectors and
                                         removes its handler, env and code
  - restart local collectors
```

If the observer stops or the network drops, the agent cleans up the target by itself.

## Installations

- SuperCollider, for `scsynth` and `sclang`.
- liblo, for `oscsend` (optional).

```bash
brew install --cask supercollider # scsynth & sclang

brew install liblo # oscsend
```

## Build

    $ rebar3 compile

## SuperCollider

Supercollider synthdefs are present in `priv/synthdefs_ambient.scd` & `priv/synthdefs_instrument.scd`

```bash
oscsend 127.0.0.1 57110 /s_new siii ping -1 0 1
```

## Usage

```bash
rebar3 shell
```

Ambient mode starts on its own. To switch modes:

```erlang
sidechain_conductor:switch(sidechain_instrument).
sidechain_conductor:switch(sidechain_ambient).
```

## What you hear

| Signal | Ambient | Instrument |
|---|---|---|
| Scheduler utilization | Heartbeat speed | More kicks per bar |
| Memory | Drone gets brighter | Not yet |
| Long GC | A slow breath | Not yet |
| Spawns | Chimes | Hi-hat |
| Exits | Lower chimes | Snare on the backbeat |
| Crash | One out-of-key note | Distorted stab |
| Supervisor restart | That note resolves | Chord change |
| Messages from watched processes | Off | One note per process |

## Perform

```erlang
sidechain_load:start().              % start 4 supervised workers
sidechain_load:kill(1).              % crash worker 1: stab, then chord change
sidechain_load:burst(100000).        % spawn 100,000 short processes
sidechain_load:busy(2000).           % keep every scheduler busy for 2s
sidechain_load:crash_loop(5, 2000).  % kill worker 1 five times, 2s apart
sidechain_load:ring(8, 250).         % pass a token around the workers, a note per hop
sidechain_load:alloc(10000000).      % hold about 300MB for 2s, triggers a long GC
sidechain_tracer:watch(my_server).   % give a registered process a melody
```

`kill/1` and `ring/2` need `start/0` first.

## Remote node

```bash
rebar3 shell --sname observer
```

```bash
erl -sname target
```

In the observer's shell, use the name the target's prompt shows:

```erlang
sidechain_remote:attach('target@yourhost').
sidechain_remote:detach().
```

- Both nodes need the same cookie. On one machine they share `~/.erlang.cookie`.
- The target needs `runtime_tools`. A plain `erl` has it. A release must include it.

## Supercollider OSC commands

```bash
$ oscsend 127.0.0.1 57110 

$ oscsend 127.0.0.1 57110 /dumpOSC i 1 # direct dump what it received

$ oscsend 127.0.0.1 57110 /s_new siii default 1000 0 1
$ oscsend 127.0.0.1 57110 /n_set isf 1000 freq 220.0
$ oscsend 127.0.0.1 57110 /n_set isf 1000 gate 0.0
$ oscsend 127.0.0.1 57110 /n_free i 1000
$ oscsend 127.0.0.1 57110 /g_freeAll i 1
```

## Ambitions

- Use with supersonic (wasm based oscsynth) to run this thing on a website over LV
- Visuals on browser
- Integrate with Touchdesigner for visuals (local)
