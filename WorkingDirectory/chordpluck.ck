//UCHUCK();
//UINSTRUMENT();

//UINCLUDE("JA-TimbreLibrary/intqueue.ck");
//UINCLUDE("JA-TimbreLibrary/stereovoicebankvoice.ck");
//UINCLUDE("JA-TimbreLibrary/stereovoicebank.ck");
//UINCLUDE("ABK-HmxMidi/HmxMidi.ck");

//credit : © Jack Atherton 2020.  https://ccrma.stanford.edu/~lja/timbre-library/ 

@import "chugins-win64/GVerb.chug"

class ChordPluckVoice extends StereoVoiceBankVoice
{
    // override
    0.5 => gainAtZeroVelocity;
    0.7 => highCutoffSensitivity;
    -0.2 => lowCutoffSensitivity;
    
    2 => int unison;

    400 => float myLPFCutoff;
    DelayA chorusL => LPF lpfL => adsrL;
    DelayA chorusR => LPF lpfR => adsrR;
    
    SawOsc osc1[unison];
    SawOsc osc2[unison];
    Pan2 pans[unison];
    SinOsc root => lpfL;
    root => lpfR;
    0.2 => root.gain;
    
    // oscs, gain, widths
    for( int i; i < unison; i++ )
    {
        0.5 / unison => osc1[i].gain;
        0.5 / unison => osc2[i].gain;
        osc1[i] => pans[i];
        osc2[i] => pans[i];
        pans[i].left => chorusL;
        pans[i].left => lpfL;
        pans[i].right => chorusR;
        pans[i].right => lpfR;
        Std.scalef( i, 0, unison - 1, -1, 1 ) => pans[i].pan;
    }
    
    // chorus 3.2Hz, 15% intensity
    0.2::second => chorusL.max => chorusR.max;
    SinOsc chorusLFO => blackhole;
    3.2 => chorusLFO.freq;
    0.15 => chorusL.gain => chorusR.gain;
    
    fun void doChorus()
    {
        3::ms => dur baseDelay;
        
        while( true )
        {
            0.3::ms * chorusLFO.last() + baseDelay => chorusL.delay => chorusR.delay;
            5::ms => now;
        }
        
    }
    spork ~ doChorus();

    
    // analog: randomly alter pitch and cutoff (0 to 1: 1. units?)
    0.01 => float analog;
    float analogs[unison + 1];
    fun void calculateAnalog()
    {
        for( int i; i < analogs.size(); i++ )
        {
            Math.random2f( 1 - analog, 1 + analog ) => analogs[i];
        }
    }
    
    fun void antiSync()
    {
        for( int i; i < unison; i++ )
        {
            Math.random2f( 0, 1 ) => osc1[i].phase;
            Math.random2f( 0, 1 ) => osc2[i].phase;
        }
    }
    
    
    
    // cutoff
    fun float cutoffToHz( float cutoff )
    {
        return Math.min( Std.scalef( Math.pow( Std.clampf( cutoff, 0, 1 ), 3 ), 0, 1, myFreq, 18000 ), 18000 );
    }
    
    // LPF cutoff envelope
    ADSR lpfEnv => blackhole;
    0.0001 => float lpfSustain;
    260::ms => dur lpfDecay;
    lpfEnv.set( 1::ms, lpfDecay, lpfSustain, 13::ms );
    
    fun void triggerLPFEnv()
    {
        // reset
        0 => lpfEnv.value;
        lpfSustain => lpfEnv.sustainLevel;
        // bounds
        0.09 => float minCutoff;
        // higher cutoff at higher pitch and at higher velocity
        Std.scalef( Math.pow( myVelocity, 1.6 ), 0, 1, 0.2, 0.4 )
            + Std.scalef( myMidi, 0, 128, 0, 0.2 ) => float maxCutoff;
        
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
    1.0 => lpfL.Q => lpfR.Q;
    
    // then ADSR on volume
    13::ms => rTime;
    adsrL.set( 1::ms, 100::ms, 0.05, rTime );
    adsrR.set( 1::ms, 100::ms, 0.05, rTime );
    
    // osc1: freq
    // osc2: +3
    fun void applyFreqs()
    {
        float f1, f2;
        while( true )
        {
            Math.min( myLPFCutoff * analogs[unison], 21000 ) => lpfL.freq => lpfR.freq;
            
            // myFreq
            myFreq => f1;
            f1 * 1.001734 => f2;
            
            for( int i; i < unison; i++ )
            {
                f1 * analogs[i] => osc1[i].freq;
                f2 * analogs[i] => osc2[i].freq;
            }
            
            f1 => root.freq;

            10::ms => now;
        }
    }
    spork ~ this.applyFreqs();
    
    // trigger note on
    fun void noteOn()
    {
        // key on
        adsrL.keyOn( 1 );
        adsrR.keyOn( 1 );
        triggerLPFEnvShred.exit();
        spork ~ this.triggerLPFEnv() @=> triggerLPFEnvShred;
        calculateAnalog();
        antiSync();
    }
    
    // trigger note off
    fun void noteOff()
    {
        adsrL.keyOff( 1 );
        adsrR.keyOff( 1 );
        endLPFEnv();
    }
}


class ChordPluck extends StereoVoiceBank
{
    8 => numVoices;
    
    // voices
    ChordPluckVoice myVoices[numVoices];
    // assign to superclass
    v.size( myVoices.size() );
    for( int i; i < myVoices.size(); i++ )
    {
        myVoices[i] @=> v[i];
    }
    // connect
    init( true );
}

ChordPluck c;
LPF lpfL => JCRev revL => dac.left;
LPF lpfR => JCRev revR => dac.right;
0.6 => c.gain;
c.connect( lpfL, lpfR );
0.05 => revL.mix => revR.mix;
15000 => lpfL.freq => lpfR.freq;

// knobs
global float gReverb;
1 => global float gCutoff;
2000 => global float gLowpass;

fun void ApplyGlobals()
{
    while( true )
    {
        10::ms => now;
        gReverb => revL.mix => revR.mix; 
        gLowpass => lpfL.freq => lpfR.freq;
        gCutoff => c.cutoff;
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
    c.noteOn( m, velocity );
    //<<< "on", m, v >>>;
}


fun void NoteOff( int m )
{
    spork ~ c.noteOff( m );
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
