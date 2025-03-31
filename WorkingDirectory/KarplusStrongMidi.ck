// tuned plucked string filter
// Ge Wang (gewang@cs.princeton.edu)
//UINCLUDE("ABK-HmxMidi/HmxMidi.ck");

//UCHUCK();


global Event noteEvent;
global float noteFreq;


me.dir() + "chant.ck" => string ShepFile;

//Machine.add(ShepFile);

36 => noteFreq;
<<< "Sample Rate:" , second/samp >>>;
// feedforward
Noise imp => OneZero lowpass => PoleZero allpass =>  dac;
// feedback
allpass => Delay delay => lowpass;
0 => imp.gain;
//0 => delay.gain;
// our radius
.99999 => float R;

global HmxMidiIn HarmonixMidi;
MidiMsg msg;

while( true )
{
    HarmonixMidi => now;

    while(HarmonixMidi.recv(msg))
    {
       if(HarmonixMidi.IsStdNoteOn(msg))
       {
        //NoteOn(msg.data2, msg.data3);
        //<<< "Received Note in Chuck!", noteFreq >>>;
        -1 => lowpass.zero;
        // fire excitation
        0.4 => imp.gain;
        // finding our (integer) delay order
        Std.mtof( msg.data2 ) => setFreq => float L;
        // set delay
        L::samp => delay.delay;
        // set dissipation factor
        Math.pow( R, L ) => delay.gain;
        // for one delay round trip
        L::samp => now;
        // done
        0 => imp.gain;
       }
       else if(HarmonixMidi.IsStdNoteOff(msg))
        {
        //NoteOff(msg.data2);

        }
    }

}

// advance time
//(Math.log(.0001) / Math.log(R))::samp => now; TEST WHATEVER 12

// set (fundamental) freq
fun int setFreq( float freq )
{
    // sample rate
    second / samp => float SR;
    // omega
    2 * pi * freq / SR => float omega;
    // figure total delay needed
    SR / freq - .5 => float D;
    // the integer part
    D $ int => int Di;
    // the fraction
    D - Di => float Df;
    // set allpass using fractional and fundamental
    polePos( Df, omega ) => allpass.allpass;
	//<<< "Karplus baby!" >>>;
    // return integer portion
    return Di;
}

// find pole location from delay and omega
fun float polePos( float D, float omega )
{
    // here it is (a la Jaffe & Smith)
    return Math.sin( (1-D) * omega / 2 ) / 
           Math.sin( (1+D) * omega / 2 );
}