(
    SynthDef(\ping, { |freq = 880, amp = 0.2|
        var sig, env;
        sig = SinOsc.ar(freq);
        env = EnvGen.kr(Env.perc(0.01, 1), doneAction: 2);
        Out.ar(0, sig * env * amp ! 2);
    }).add;

    SynthDef(\pulse, { |rate = 1, amp = 0.4|
        var trig, env, sig;
        trig = Impulse.kr(rate.lag(0.5));
        env = EnvGen.kr(Env.perc(0.002, 0.25), trig);
        sig = SinOsc.ar(50 + (env * 100)) * env;
        Out.ar(0, sig * amp ! 2);
    }).add;

    SynthDef(\breath, { |amp = 0.3, dur = 3|
        var env, sig;
        env = EnvGen.kr(Env([0, 1, 0], [dur * 0.4, dur * 0.6], \sin), doneAction: 2);
        sig = LPF.ar(PinkNoise.ar, 400 + (env * 1600));
        Out.ar(0, sig * env * amp ! 2);
    }).add;
)
