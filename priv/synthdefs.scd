(
 SynthDef(\ping, { |freq = 880, amp = 0.2|
	var sig, env;
	sig = SinOsc.ar(freq);
	env = EnvGen.kr(Env.perc(0.01, 1), doneAction: 2);
	Out.ar(0, sig * env * amp ! 2);
 }).add;
)