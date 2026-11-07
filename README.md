sidechain
=====

![Logo](logo.jpg)

Hear your BEAM.

Sidechain converts your BEAM's metrics into sounds (& visuals) using OSC.

https://github.com/user-attachments/assets/4d2162a3-0cf7-4be3-8e23-18dcf711a629

*sidechain + touchdesigner via osc*

## How it works

```
sampler ─┐
tracer  ─┼─> conductor ─> mode ─> OSC ─> sender ─> scsynth (UDP 127.0.0.1:57110)
sysmon  ─┘
```

Collectors count what the node does and send short summaries. The conductor ticks at 120 bpm and asks the current mode what to play: ambient hums in the background, instrument is played by stressing the node.

### Working with remote node

Tracing must run inside the traced node, so `attach` pushes the collector code to the target and runs it there. The sound stays on your machine.

```
observer                        target
attach(target)
  push code, start agent ─────> agent starts collectors
conductor <──── summaries ───── collectors
detach()
  stop ───────────────────────> agent removes its code and leaves
```

## Setup

```bash
brew install --cask supercollider # scsynth & sclang
brew install liblo                # oscsend
rebar3 compile
```

Boot the server in the SuperCollider IDE and run `priv/synthdefs_ambient.scd` and `priv/synthdefs_instrument.scd`. This should ping:

```bash
oscsend 127.0.0.1 57110 /s_new siii ping -1 0 1
```

## Usage

```bash
rebar3 shell
```

```erlang
sidechain_conductor:switch(sidechain_instrument).
sidechain_load:start().              % workers for kill and ring
sidechain_load:kill(1).              % stab, then a chord change
sidechain_load:burst(100000).        % hi-hats
sidechain_load:ring(8, 250).         % melody
sidechain_load:alloc(10000000).      % long GC
```

## Remote node

```bash
rebar3 shell --sname observer
erl -sname target                    # in another terminal
```

```erlang
sidechain_remote:attach('target@yourhost').
sidechain_remote:detach().
```

Both nodes need the same cookie. The target needs `runtime_tools`, which a plain `erl` has.

## SuperCollider OSC commands

```bash
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
