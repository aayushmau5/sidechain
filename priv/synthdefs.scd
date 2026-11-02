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
)
