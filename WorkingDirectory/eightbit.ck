
//credit : © Jack Atherton 2020.  https://ccrma.stanford.edu/~lja/timbre-library/ 

//UCHUCK();
//UINSTRUMENT();
//UINCLUDE("JA-TimbreLibrary/intqueue.ck");
//UINCLUDE("JA-TimbreLibrary/voicebankvoice.ck");
//UINCLUDE("JA-TimbreLibrary/voicebank.ck");
//UINCLUDE("ABK-HmxMidi/HmxMidi.ck");

@import "chugins-win64/GVerb.chug"

class EightBitVoice extends VoiceBankVoice
{
    // override
    0.5 => gainAtZeroVelocity;
    0.1 => highCutoffSensitivity;
    -0.8 => lowCutoffSensitivity;
    
    1 => int unison;

    400 => float myLPFCutoff;
    Gain drive => LPF lpf => adsr;
    1.5 => drive.gain;
    1.0 / drive.gain() => lpf.gain;
    
    SqrOsc osc1[unison];
    
    // oscs, gain
    for( int i; i < unison; i++ )
    {
        1.0 / unison => osc1[i].gain;
        osc1[i] => drive;
    }
    
    
    fun void sync()
    {
        for( int i; i < unison; i++ )
        {
            0 => osc1[i].phase;
        }
    }
    
    
    // cubic scale
    fun float cutoffToHz( float cutoff )
    {
        return Math.min( Std.scalef( Math.pow( Std.clampf( cutoff, 0, 1 ), 3 ), 0, 1, myFreq, 18000 ), 18000 );
    }
    
    // LPF cutoff envelope
    ADSR lpfEnv => blackhole;
    0.995 => float lpfSustain;
    99::ms => dur lpfDecay;
    lpfEnv.set( 1::ms, lpfDecay, lpfSustain, 99::ms );
    
    fun void triggerLPFEnv()
    {
        // reset
        0 => lpfEnv.value;
        lpfSustain => lpfEnv.sustainLevel;
        // bounds
        0.5 => float minCutoff;
        // higher cutoff at higher velocity
        Std.scalef( Math.pow( myVelocity, 1.6 ), 0, 1, 0.75, 1.0 ) => float maxCutoff;
        
        minCutoff => float currentCutoff;
        maxCutoff - minCutoff => float cutoffDiff;
                
        lpfEnv.keyOn( 1 );
        
        5::ms => dur delta;
                        
        while( true )
        {
            // set
            minCutoff + cutoffDiff * Math.pow( lpfEnv.value(), 3 ) => currentCutoff;
            // Math.pow( currentCutoff, 3 ) => currentCutoff;
            currentCutoff + myCutoff => this.cutoffToHz => myLPFCutoff;
                                    
            // wait
            delta => now;
        }        
    }
    spork ~ this.triggerLPFEnv() @=> Shred triggerLPFEnvShred;
    
    fun void endLPFEnv()
    {
        lpfEnv.keyOff( 1 );
    }
    

    
    // resonances
    1.0 => lpf.Q;
    
    // then ADSR on volume
    99::ms => rTime;
    adsr.set( 1::ms, 65::ms, 0.001, rTime );
    
    // osc1: freq
    fun void applyFreqs()
    {
        while( true )
        {
            Math.min( myLPFCutoff, 21000 ) => lpf.freq;
            
            for( int i; i < unison; i++ )
            {
                myFreq => osc1[i].freq;
            }
            
            0.5::ms => now;
        }
    }
    spork ~ this.applyFreqs();
    
    // trigger note on
    fun void noteOn()
    {
        // funsies: make it longer the harder you press
        Std.scalef( Math.pow( myVelocity, 2 ), 0, 1, 65, 160 )::ms => adsr.decayTime;
        
        // key on
        adsr.keyOn( 1 );
        triggerLPFEnvShred.exit();
        spork ~ this.triggerLPFEnv() @=> triggerLPFEnvShred;
        sync();
    }
    
    // trigger note off
    fun void noteOff()
    {
        adsr.keyOff( 1 );
        endLPFEnv();
    }    
}


class EightBit extends VoiceBank
{
    8 => numVoices;
    
    // voices
    EightBitVoice myVoices[numVoices];
    // assign to superclass
    v.size( myVoices.size() );
    for( int i; i < myVoices.size(); i++ )
    {
        myVoices[i] @=> v[i];
    }
    // connect
    init( true );    
}

EightBit e => LPF l =>  dac;
0.3 => e.gain;
//0.0 => rev.mix;
15000 => l.freq;

// knobs
global float gReverb;
0.5 => global float gCutoff;
20000 => global float gLowpass;

fun void ApplyGlobals()
{
    while( true )
    {
        10::ms => now;
      //  gReverb => rev.mix;
        gLowpass => l.freq;
        gCutoff => e.cutoff;
    }
}
spork ~ ApplyGlobals();
// end knobs



global Event midiMessage;
global int midiCommand;
global int midiNote;
global int midiVelocity;

fun void NoteOn( int m, int v )
{
    v * 1.0 / 128 => float velocity;
    e.noteOn( m, velocity );
    //<<< "on", m, v >>>;
}


fun void NoteOff( int m )
{
    spork ~ e.noteOff( m );
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
