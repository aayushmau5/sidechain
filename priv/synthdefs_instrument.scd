(
    SynthDef(\kick, { |amp = 0.5|
        var env, sig;
        env = EnvGen.kr(Env.perc(0.002, 0.25), doneAction: 2);
        sig = SinOsc.ar(50 + (env * 100)) * env;
        Out.ar(0, sig * amp ! 2);
    }).add;

    SynthDef(\hat, { |amp = 0.15|
        var env, sig;
        env = EnvGen.kr(Env.perc(0.001, 0.05), doneAction: 2);
        sig = HPF.ar(WhiteNoise.ar, 8000);
        Out.ar(0, sig * env * amp ! 2);
    }).add;

    SynthDef(\snare, { |amp = 0.3|
        var env, noise, tone, sig;
        env = EnvGen.kr(Env.perc(0.001, 0.15), doneAction: 2);
        noise = WhiteNoise.ar;
        tone = SinOsc.ar(180);
        sig = (noise * 0.7) + (tone * 0.3);
        Out.ar(0, sig * env * amp ! 2);
    }).add;
)
