//UCHUCK();
//UINSTRUMENT();
//credit : © Jack Atherton 2020.  https://ccrma.stanford.edu/~lja/timbre-library/ 

//UINCLUDE("JA-TimbreLibrary/intqueue.ck");
//UINCLUDE("JA-TimbreLibrary/voicebankvoice.ck");
//UINCLUDE("JA-TimbreLibrary/voicebank.ck");
//UINCLUDE("JA-TimbreLibrary/tandistortion.ck");
//UINCLUDE("ABK-HmxMidi/HmxMidi.ck");

@import "chugins-win64/GVerb.chug"

class SailVoice extends VoiceBankVoice
{
    SawOsc osc1 => Gain common => LPF lpf => TanDistortion distortion => adsr;
    SawOsc osc2 => common;
    SqrOsc osc3 => common;
    0.35 => osc1.gain;
    0.45 => osc2.gain;
    0.20 => osc3.gain;
    1.2 => common.gain; // input to overdrive to distort...
    //1 => overdrive.sync; // SinOsc overdrive
    // dyno.compress();  // Dyno dyno
    13 => lpf.Q;
    staccato( true );    
    
    200 => float goalFreq;
    200 => float currentFreq;
    0.15 => float slewFreq;
    false => int noteIsOn;
    
    // maximum release time
    20::ms => rTime;
    
    fun void staccato( int doStaccato )
    {
        if( doStaccato )
        {
            adsr.set( 20::ms, 150::ms, 0.1, 1::ms );
        }
        else
        {
            adsr.set( 20::ms, 5::ms, 0.9, 20::ms );
        }
    }
    
    fun void SetFreq()
    {
        SinOsc pitchLfo => blackhole;
        1.1 => pitchLfo.freq;
        while( true )
        {
            slewFreq * ( goalFreq - currentFreq ) +=> currentFreq;
            // 0.5% of current frequency
            currentFreq + 0.005 * currentFreq * pitchLfo.last() => 
                float waveringFreq;
            waveringFreq => osc1.freq;
            waveringFreq / 2 => osc2.freq;
            waveringFreq => osc3.freq;
            
            // what is "80% of the way up"?
            Math.min( waveringFreq * 32, 20000 ) => lpf.freq;
            1::ms => now;
        }
    }
    spork ~ SetFreq();
    
    // override
    fun float note( float m )
    {
        m => myMidi;
        myMidi => Std.mtof => freq;
        return m;
    }
    
    fun float freq( float f )
    {
        f => goalFreq;
        if( noteIsOn )
        {
            0.026 => slewFreq;
        }
        else
        {
            0.15 => slewFreq;
        }
        

        // putting this only here instead of in the while loop
        // makes the attack sound harder because
        // the resonant filter doesn't glide
        //Math.min( goalFreq * 32, 20000 ) => lpf.freq;
        
        return f;
    }
    
    fun float freq()
    {
        return goalFreq;
    }
    
    fun void noteOn()
    {
        if( !noteIsOn )
        {
            1 => adsr.keyOn;
            goalFreq * 8 => currentFreq; // higher = harder attack
            true => noteIsOn;
        }
        
    }
    
    fun void noteOff()
    {
        1 => adsr.keyOff;
        false => noteIsOn;
    }
}

class Sail extends VoiceBank
{
    8 => numVoices;
    
    // voices
    SailVoice myVoices[numVoices];
    // assign to superclass
    v.size( myVoices.size() );
    for( int i; i < myVoices.size(); i++ )
    {
        myVoices[i] @=> v[i];
    }
    // connect
    init( true );
    
    fun void staccato( int yesorno )
    {
        for( int i; i < myVoices.size(); i++ )
        {
            yesorno => myVoices[i].staccato;
        }
    }
}

Sail s => LPF l => dac;
//0.02 => rev.mix;
15000 => l.freq;

// knobs
global float gReverb;
global int gStaccato;
global float gCutoff;
5000 => global float gLowpass;

fun void ApplyGlobals()
{
    while( true )
    {
        10::ms => now;
       // gReverb => rev.mix;
        gLowpass => l.freq;
		s.staccato(gStaccato);
        //gCutoff => s.common.gain;
    }
}
spork ~ ApplyGlobals();
// end knobs

// an option!



global Event midiMessage;
global int midiCommand;
global int midiNote;
global int midiVelocity;

fun void NoteOn( int m, int v )
{
    v * 1.0 / 128 => float velocity;
    s.noteOn( m, velocity );
    //<<< "on", m, v >>>;
}


fun void NoteOff( int m )
{
    spork ~ s.noteOff( m );
    //<<< "off", m >>>;
}




global HmxMidiIn HarmonixMidi;
MidiMsg msg;

while( true )
{
    HarmonixMidi => now;

    while(HarmonixMidi.recv(msg))
    {
       if(HarmonixMidi.IsStdNoteOn(msg))
       {
        NoteOn(msg.data2, msg.data3);
       }
       else if(HarmonixMidi.IsStdNoteOff(msg))
        {
        NoteOff(msg.data2);

        }
    }

}

