(
(thisProcess.nowExecutingPath.dirname+/+"crumbleNum.scd").load;
)

(
~figs = [
	[3, 5, 7],
	[3, 5, 6],
	[3, 4, 6],
	[2, 4, 6],
	[2, 5, 6],
	[4, 5, 7],
].deepCollect(5, {|i| i - 1});

~noteValues = [1/4 ,1/8, 1/16];
~repeats = [4 ,8, 12, 16];
~allTuples = [~noteValues, ~repeats].allTuples;
~allTupleDurs = ~allTuples.collect({ |i| i[0] * i[1] });

~getHighHatMeasure = {
	var chunkedHighHatMeasure, highHatMeasure;
	var crumbledMeasure = ~crumbleNum.value(16, ~allTupleDurs);
	var tupledMeasure = [];
	crumbledMeasure.do({ |crumb|
		var matchingTuples = [];

		~allTupleDurs.do({ |dur, i|
			if (crumb === dur, { matchingTuples = matchingTuples.add(~allTuples[i]) })
		});
		tupledMeasure = tupledMeasure.add(matchingTuples.choose);
	});
	chunkedHighHatMeasure = tupledMeasure.collect({ |tup| (tup[0]!tup[1]) });
	highHatMeasure = chunkedHighHatMeasure.flatten;
};

SynthDef(\harp, {
	arg freq = 50, out = 1, gate = 1, amp = 0.5, pan=0;
	var sig, env, envGen, vib;

	env = Env(
		[0, 0.5, 0.2, 0],
		[0.01, 0.1, 0.5],
		[3, 0, -3],
		releaseNode: 2
	).plot;
	envGen = EnvGen.ar(envelope: env, gate: gate, doneAction: Done.freeSelf);

	vib = SinOsc.ar(3, 0, 1.25);
	sig = Mix.ar([
		SinOsc.ar(freq: freq + vib, mul: amp),
		Pulse.ar(freq: freq + vib, mul: amp*Line.kr(1/4, 1/12, 0.1))
	]);
	sig = sig * envGen;
	sig = Pan2.ar(sig, pan);

	Out.ar(out, sig);
}).add;

SynthDef(\bassTone, {
	arg freq = 50, out = 1, gate = 1, amp = 0.5, pan=0;
	var sig, env, envGen, lagFreq;

	env = Env(
		levels: [0, 0.5, 0.2, 0],
		times: [0.0075, 0.05, 0.94],
		releaseNode: 2,
		curve: [3, -3, 0]
	);

	envGen = EnvGen.ar(envelope: env, gate: gate, doneAction: Done.freeSelf);

	sig = Mix.ar([
		SinOsc.ar(freq: freq/4, mul: amp*Line.kr(1/2, 1, 0.5)),
		SinOsc.ar(freq: freq/2, mul: amp*Line.kr(1/2, 1, 0.5)),
		SinOsc.ar(freq: freq, mul: amp),
		SinOsc.ar(freq: freq*2, mul: amp*Line.kr(1/3, 1/12, 0.5)),
	]);
	sig = sig * envGen;
	sig = Pan2.ar(sig, pan);

	Out.ar(out, sig);
}).add;

SynthDef(\kick, {
	arg freq = 500, pan = 0, out = 0, amp = 0.5;

	var freqSweep = Env(
		[freq/2, freq/2, freq/10, freq/50],
		[0.01, 0.02, 0.47],
		[0, 1, -1,]
	).ar;

	var env = EnvGen.kr(Env([0,0.4,0], [0.01, 0.49], [1, 6]), doneAction: Done.freeSelf);

	var sig = SinOsc.ar(freqSweep, pi/2);
	sig = sig * env;
	sig = Pan2.ar(sig, pan, amp);
	Out.ar(out, sig);
}).add;

SynthDef(\highHat, {
	arg out = 1, gate = 1, amp = 0.5, pan=0, freq=10000;
	var sig, env, envGen;

	env = Env([0, 0.4, 0], [0.0005, 0.05], releaseNode: 1);
	envGen = EnvGen.ar(envelope: env, gate: gate, doneAction: Done.freeSelf);

	sig = Mix.ar([ClipNoise.ar(amp,  0), BrownNoise.ar(amp, 0)]);
	sig = BPF.ar(sig, freq, 0.75) * envGen;
	sig = Pan2.ar(sig, pan);

	Out.ar(out, sig);
}).add;

SynthDef("snare", {arg out = 0, amp = 0.1, sinfreq = 175, att = 0.01, rel = 0.2, ffreq = 1750, pan = 0;
	var env, snd1, snd2, sum;
	env = Env.perc(att, rel, amp).kr(doneAction: 2);
	snd1 = HPF.ar(
		in: WhiteNoise.ar,
		freq: ffreq,
		mul: env
	);
	snd2 = SinOsc.ar(freq: sinfreq, mul: env);
	sum = snd1 + snd2;
	Out.ar(out, Pan2.ar(sum, pan));
}).add;

SynthDef(\reverb, {
	arg in=0, out=0;
	var sig = In.ar(in, 2);
	sig = FreeVerb2.ar(sig[0], sig[1], 0.0, 0.6, 0.2);
	Out.ar(out, sig);
}).add;

SynthDef(\delay, {
	arg in=0, out=0;

	var sig = In.ar(in, 2);
	sig = CombC.ar(sig, 3.5, 1/2, 5);
	Out.ar(out, sig);
}).add;
)


(
s.newBusAllocators;
~reverbBus = Bus.audio(numChannels: 2);
~delayThenReverbBus = Bus.audio(numChannels: 2);

~sourceGroup = Group.new;
~effectsGroup = Group.after(~sourceGroup);

~delayThenReverb = Synth.new(\delay, [\in, ~delayThenReverbBus, \out, ~reverbBus], ~effectsGroup, \addToHead);
~reverb = Synth.new(\reverb, [\in, ~reverbBus, \out, 0], ~effectsGroup, \addToTail);

~scaleOptions = [
	Scale.major,
	Scale.dorian,
	Scale.lydian,
	Scale.mixolydian,
	Scale.minor
];

~rootOptions = (-5..5);
~globals = Pbind(
	\event, \rest,
	\scale, Plet(\mode, Prand(~scaleOptions, inf), inf),
	\root, Plet(\pedal, Pxrand(~rootOptions, inf)),
	\tuning, Plet(\tuning, Tuning.pythagorean, inf),
	\arpOrder, Plet(\arpOrder, Pfunc({(0..5).scramble}), inf),
	\dur, Prand([ 2, 4, [3, 1], [1, 1] ], inf).flatten * 8,
	\amp, 0,
);

~bass = Pbind(
	\instrument, \bassTone,
	\root, Pget(\pedal, 0, inf),
	\scale, Pget(\mode, Scale.major, inf),
	\tuning, Pget(\tuning, Tuning.pythagorean, inf),
	\octave, Pwrand([3, 4], [0.75, 0.25], inf),
	\degree, 0,
	\delta, Pdup(4, Pfunc({ ~crumbleNum.value })).flatten,
	// \sustain, TempoClock.default.tempo/(Pkey(\delta)*2),
	\out, [0],
	\group, ~sourceGroup,
	\amp, 0.7,
	\pan, 0
);

~getKickMeasure = Pfunc({
	var getKickBeat = {[
		[\note, Rest()].wchoose([0.9, 0.1]),
		[\note, Rest()].wchoose([0.1, 0.9]),
		[\note, Rest()].wchoose([0.2, 0.8]),
		[\note, Rest()].wchoose([0.2, 0.8]),
	]};
	Array.fill(4, getKickBeat).flatten(1);
});
~kick = Pbind(
	\instrument, \kick,
	\type, Pdup(4, ~getKickMeasure).flatten(1),
	\freq, 300,
	\amp, 0.6,
	\group, ~sourceGroup,
	\out, [0, ~reverbBus],
	\dur, 0.25,
	\pan, -0.2
);

~arpsFigures = Pfuncn({ |e|

	var indices = (0..(~figs.size - 1)).scramble.keep(2);

	var figArr1 = ~figs[indices[0]];
	var figArr2 = ~figs[indices[1]];

	var arpArr1 = (figArr1++(7+figArr1));
	var arpArr2 = figArr2++(7+figArr2);

	var arpOrder = e[\arpOrder];
	var scrambledArpArr1 = arpOrder.collect({|i| arpArr1[i] });
	var scrambledArpArr2 = arpOrder.collect({|i| arpArr2[i] });

	[
		scrambledArpArr1++scrambledArpArr1.keep(2),
		scrambledArpArr2++scrambledArpArr2.keep(2)
	].flatten(0);
}, 1);

//set the first seven notes of the 8 note arpeggio to be of length "dur"
//and the final note to be the leftover time in a measure adding up to 2 beats (0.25*8)
//i.e 7 instances of 0.125, then one instance of 1.125
~durArr = {|dur| dur!7++[(0.25*8)-(dur*7)]};

//address to send OSC messages
~oscAddress = NetAddr.new("localhost", 8081);


~arps = Pbind(
	\instrument, \harp,
	\tuning, Pget(\tuning, Tuning.pythagorean, inf),
	\arpOrder, Pget(\arpOrder, (0..5), inf),
	\figures, Pdup(4, ~arpsFigures).flatten(1),
	\octave, 4,
	\scale, Pget(\mode, Scale.major, inf),
	\root, Pget(\pedal, 0, inf),
	\degree, Pkey(\figures),
	\delta, Pdup(16, (Prand([1/4, 1/8, 1/32].collect(~durArr), inf))).flatten(0),
	// \delta, Pdup(16, (Prand([1/8].collect(~durArr), inf))).flatten(0).trace,
	// \dur, Pfunc({TempoClock.beatDur/2}),
	\dur, 1.9,
	\sustain2, Pkey(\dur).trace,
	\amp, 0.2,
	\out, [0, ~delayThenReverbBus],
	// \out, [0],
	\group, ~sourceGroup,
	\pan, Pseq(([0.75, -0.75]!4).flatten.mirror2, inf),
	\callback, { |e|
		var minDegree = topEnvironment[\figs].flatten(1).minItem() + topEnvironment[\rootOptions][0];
		var absoluteDegree = e[\degree] + e[\root] - minDegree;
		topEnvironment[\oscAddress].sendMsg("/message", absoluteDegree);
	}
);

~arpsRepeater = Ptpar([
	0,
	~arps
], inf);

~highHat = Pbind(
	\instrument, \highHat,
	\sustain, Pwrand([0.01, 0.04], [0.75, 0.25], inf),
	\dur, Pdup(4, Pfunc(~getHighHatMeasure)).flatten,
	\freq, Pwrand(
		[
			10000 * (0.9**Pseq((0..7), 1)),
			Pseq(10000!4, 1)
		],
		[0.25, 0.75],
		inf
	),
	\amp, Pseq([0.2, 0.15, 0.15, 0.15], inf) * Pwrand([0.6, 0.3, 0], [0.7, 0.2, 0.1], inf),
	\out, [0, ~reverbBus],
	\group, ~sourceGroup,
	\pan, Pseq([0.2, 0.3], inf)
);

~snare = Pbind(
	\instrument, \snare,
	\input, Pdup(4, (Pfunc({
		var durs = ~crumbleNum.value(crumbles: [1/8, 1/4, 3/8, 1/2, 5/8, 3/4]);
		var types = Array.fill(durs.size, { [\note, Rest()].wchoose([0.8, 0.2]) });

		durs.collect({ |dur, i| (dur: dur, type: types[i] ) });
	}))).flatten,
	\type, Pkey(\input).collect({ |d| d[\type] }),
	\dur, Pkey(\input).collect({ |d| d[\dur] }),
	\sustain, Pkey(\dur) * TempoClock.default.tempo,
	\out, [0, ~reverbBus],
	\amp, 0.1
);

~changeTempo = {
	arg newTempo = 1, changeDur = 1, stepCount = 10;
	var delta = newTempo - TempoClock.default.tempo;
	var deltaSlice = delta/stepCount;
	var stepper = Routine.new({
		stepCount.do({
			TempoClock.default.tempo = TempoClock.default.tempo + deltaSlice;
			(changeDur/stepCount).wait;
		});
	}).play;
};
~tempo = Pbind(
	\amp, Rest(),
	\dur, Prand([64, 128, 256], inf),
	\tempoNum, Pxrand([0.75, 0.85, 1], inf), //0.2??????
	\callback, { |e| topEnvironment[\changeTempo].value(e.tempoNum, 2, 20) }
);

Plambda(Ppar([
	~globals,
	~bassDurs,
	~kick,
	~bass,
	~arpsRepeater,
	~highHat,
	// ~tempo,
	~snare
], inf)).play;
)

~changeTempo.value(0.2);