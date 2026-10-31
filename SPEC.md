# sidechain design

sidechain listens to a running BEAM node and turns its activity into music. You hear the system breathe: an idle node hums, a load spike quickens the pulse, a crash loop sounds wrong before you read a log line.

The name comes from audio: a sidechain is one signal controlling another. Here the BEAM's activity controls the music.

## Decisions

| Topic | Decision |
|---|---|
| Modes | Two: ambient (background companion) and instrument |
| Target node | Start by observing the local node; design so the target can later be a remote node |
| Sound engine | SuperCollider. Erlang talks to `scsynth` directly over OSC; `sclang` is only used to define and load SynthDefs |
| Who composes | Erlang. It turns BEAM activity into notes and timing. scsynth only plays what it is told |

## Prerequisites

- OTP 27 or newer, for the `trace` module and trace sessions. This machine has OTP 29.
- rebar3.
- SuperCollider, which provides `scsynth` and `sclang`.
- liblo, which provides the `oscsend` and `oscdump` CLIs for poking OSC by hand.
- Wireshark, which decodes OSC packets, for checking encoder output.

## Architecture

### Processes

- **Sampler** - a `gen_server` that wakes on a timer (around every 100ms) and reads levels: scheduler utilization, run queue lengths, memory.
- **Tracer** - receives trace messages for spawns, exits and links, using a trace session from the `trace` module. Counts events instead of forwarding them.
- **System monitor** - receives `long_gc`, `long_schedule` and `busy_port` events from `erlang:system_monitor/2`. Only one system monitor can exist per node.
- **Conductor** - the composer. Receives summaries from the collectors, holds the musical state (current mode, tempo, scale, active voices) and decides what plays and when.
- **Modes** - each mode is a module implementing a `sidechain_mode` behaviour. The conductor delegates "events in, notes out" to the current mode.
- **OSC encoder** - a module of pure functions that turn Erlang terms into OSC binaries.
- **OSC sender** - a `gen_server` that owns the `gen_udp` socket, sends to scsynth and listens for replies.

Later additions:

- **Load generator** - for instrument mode. Spawns, crashes and floods on purpose so the VM can be performed.
- **Remote agent** - for observing another node. See "Going remote".

### Flow

1. Collectors (sampler, tracer, system monitor) send summaries to the conductor as plain Erlang messages.
2. The conductor passes them to the current mode, which returns notes and parameter changes.
3. The conductor hands those to the sender, stamped with the time they should play.
4. The sender encodes them as OSC bundles and sends them over UDP to scsynth.

### Supervision

`one_for_one`. Each process can fail without the others needing a restart. The conductor finds the sender by registered name, so a restarted sender does not affect it.

The scaffold's supervisor currently uses `one_for_all` with intensity 0, which is wrong for this design. Choosing the restart intensity (how many crashes per period mean "give up") is left as an exercise.

## Events and time

### Two kinds of signal

- **Levels** change smoothly: scheduler utilization, memory, run queue length. They drive long-running synths whose parameters change with `/n_set`, like turning a knob.
- **Events** happen at a moment: spawn, exit, crash, long GC. They start new notes with `/s_new`.

The sampler produces levels. The tracer and system monitor produce events.

### Counting instead of forwarding

Collectors never forward one message per event. A busy node can spawn thousands of processes a second, and forwarding each one would flood the conductor's mailbox. An unbounded mailbox is a classic way for a BEAM node to die.

Each collector counts within a short window and sends a summary, such as "340 spawns, 2 crashes in the last 50ms". The conductor's mailbox stays small however busy the node gets.

### The clock

The conductor runs a musical tick, for example sixteenth notes at a set BPM.

- **Instrument mode** quantizes events to the next tick, so chaos lands on the beat.
- **Ambient mode** ignores the grid. Events drift in loosely, like wind chimes.

### Drift

Scheduling each tick as "now + interval" lets small delays pile up, and the tempo slows. Each tick is computed from a fixed start time using `erlang:monotonic_time`, so errors never accumulate.

### Jitter

Erlang timers can fire a few milliseconds late, and the ear hears that. The conductor sends notes about 100ms ahead in OSC bundles whose timetag is the exact time to play. scsynth plays them on time. This needs a conversion from BEAM time to the NTP format OSC timetags use.

## Modes

| Signal | Ambient | Instrument |
|---|---|---|
| Scheduler utilization | Heartbeat rate, 50 to 120 bpm | Tempo and kick density |
| Memory | Warmth of a drone (filter brightness) | Bass line register |
| Long GC | A slow breath swell | A reverse cymbal into the next bar |
| Spawn count | Sparse chimes | Hi-hat density |
| Exit count | Chimes fade out | Snare and clicks |
| Messages between watched processes | Off | Melodic notes |
| Crash | One out-of-key note | Distorted stab |
| Supervisor restart | That note resolves into the key | Chord change |

### Mapping rules

- **Log scaling.** Rates range from a handful to tens of thousands per second. Map the log of the rate, so each tenfold jump adds one step.
- **Pentatonic chimes.** A pentatonic scale has five notes that never clash, so random picks from it always sound fine.
- **One pitch per process.** In instrument mode, `erlang:phash2` of a pid picks a scale degree. A process keeps its note for life.
- **Only watched processes make melodies.** Tracing every send is too expensive. The user chooses a few processes, for example by registered name.

### Switching modes

The conductor holds the current mode module and its state. Modes switch at runtime with a message. Each mode places its synths in its own scsynth group, and switching frees the whole group with `/g_freeAll`, so no drones are left playing.

## OSC contract with scsynth

### Message anatomy

An OSC message is an address (such as `/s_new`), a type tag string (such as `,sii`) and the arguments in big-endian binary. Each part is padded to a multiple of 4 bytes.

A bundle is the string `#bundle`, a 64-bit timetag (seconds since 1900 plus a fraction of a second), then each message prefixed with its size.

### Commands used

| Command | Purpose |
|---|---|
| `/s_new` | Start a synth from a SynthDef, with parameters |
| `/n_set` | Change a running synth's parameters (drives all levels) |
| `/n_free` | Stop one synth |
| `/g_new` | Create a group (one per mode) |
| `/g_freeAll` | Free every synth in a group |
| `/status` | Check scsynth is alive; it replies to the sending socket |

scsynth listens on UDP port 57110 by default.

### Node IDs

Every running synth has a numeric ID.

- Short notes (chimes, hats, stabs) free themselves when their envelope ends, so they use ID -1, meaning "assign one, I won't need it".
- Long-lived synths (drones, heartbeat) receive `/n_set` calls, so the conductor assigns and tracks their IDs.

### SynthDefs

One `.scd` file in the repo defines the instruments: drone, pulse, chime, kick, hat, snare, stab, bass. They are loaded into scsynth once from sclang. Erlang refers to them by name.

### Failures

UDP never confirms delivery. If scsynth is down, sends vanish and nothing crashes. scsynth reports bad commands with a `/fail` reply, so the sender listens for replies and logs them.

## Safety

sidechain must never hurt the node it observes.

### Circuit breaker

Every trace event is a message to the tracer. A spawn storm can outrun it. The tracer checks its own mailbox size with `process_info(self(), message_queue_len)`. Past a threshold it turns tracing off for a second, then back on. The music goes quiet during the overload.

### Feedback loop

sidechain's own processes spawn, send and garbage-collect too. The tracer ignores any process that belongs to the sidechain application, checked with `application:get_application/1`.

### Stuck drones

If the conductor crashes, its synths keep playing in scsynth. The conductor's startup always frees its groups first, then builds fresh ones, so every restart begins from silence.

### Going remote

Tracing must happen on the node being traced. Remote mode adds a small agent, started on the target node over distribution, that runs the collectors there and sends only summaries back. Because collectors already count instead of forwarding, only a few small messages cross the network.

## Build order

| # | Milestone | You learn | Done when |
|---|---|---|---|
| 0 | Drive scsynth by hand | What scsynth is, OSC basics | `oscsend` from the terminal plays a ping |
| 1 | OSC encoder | Erlang syntax, binaries, EUnit | Tests match bytes captured in Wireshark |
| 2 | Sender and supervisor | `gen_udp`, registered names, strategies | The shell plays a ping; killing the sender restarts it |
| 3 | Sampler and heartbeat | Timers, scheduler utilization, `/n_set` | A busy loop in the shell speeds up the heartbeat |
| 4 | Drift-free clock | Monotonic time, timetags, bundles | A metronome stays on time for 10 minutes |
| 5 | Tracer | Trace sessions, counting, circuit breaker | Spawning 100,000 processes plays a burst instead of crashing |
| 6 | System monitor | `system_monitor`, GC | A huge allocation triggers a breath |
| 7 | Conductor, mode behaviour, ambient mode | Behaviours, hot code loading | It runs in the background while you work |
| 8 | Instrument mode | Pid hashing, crash and restart signals | Killing a supervised process plays a stab, then a chord change |
| 9 | Load generator | Deliberate stress, OTP failure patterns | You can perform a short piece |
| 10 | Remote agent | Distribution, remote spawn | sidechain on one node plays another |

## Testing

- **EUnit** for pure functions: the OSC encoder, timetag conversion, log scaling, and mode callbacks ("these events in, these notes out").
- **Wireshark** to compare encoder output with known-good packets from `oscsend`.
- **Ears** for everything else.

## Open topics

- **Music basics.** Scales, pentatonic, keys, resolution, register, quantizing. Cover these in plain terms before milestone 7.
- **Collector death.** Look up in the docs what the VM does with a trace session when its tracer process dies, and with the system monitor when its receiver dies. The answer decides what a restarted collector must set up again.
- **Restart intensity.** Choose how many crashes per period the supervisor tolerates.
- **Tick rate and window size.** Pick the sampler interval, counting window and lookahead by ear once milestones 3 to 5 work.
