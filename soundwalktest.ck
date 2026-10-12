@import "sound.ck"
SinOsc sin1 => UGen collect;
SinOsc sin2 => collect;
SinOsc sin3 => collect;
collect => dac;
[sin1, sin2, sin3] @=> Osc inputs[];

spork ~ SoundWalk.runSound(inputs);

while (true)
{
    1::second => now;
}


