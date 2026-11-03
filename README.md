sidechain
=====

Hear your BEAM.

Build
-----

    $ rebar3 compile

# Installations

```bash
brew install --cask supercollider # scsynth & sclang

brew install liblo # oscsend
```

# Supercollider OSC commands

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
