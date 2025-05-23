//UCHUCK();

//UINCLUDE("JA-TimbreLibrary/intqueue.ck");
//UINCLUDE("JA-TimbreLibrary/voicebankvoice.ck");
//UINCLUDE("JA-TimbreLibrary/voicebank.ck");
//UINCLUDE("ABK-HmxMidi/HmxMidi.ck");

//credit : © Jack Atherton 2020.  https://ccrma.stanford.edu/~lja/timbre-library/ 


@import "chugins-win64/GVerb.chug"

class RetroVoice extends VoiceBankVoice
{
    // override
    0.5 => gainAtZeroVelocity;
    0.3 => highCutoffSensitivity;
    -0.65 => lowCutoffSensitivity;
    
    1 => int unison;

    float myFreqWaver;
    400 => float myLPFCutoff;
    400 => float myHPFCutoff;
    DelayA chorus => LPF lpf => adsr;
    
    SawOsc osc1[unison];
    SinOsc root => lpf;
    0.1 => root.gain;
    
    // oscs, gain, widths
    for( int i; i < unison; i++ )
    {
        1.0 / unison => osc1[i].gain;
        osc1[i] => lpf;
        osc1[i] => chorus;
    }
    
    // chorus 0.24Hz, "8%" intensity
    5::ms => chorus.max;
    SinOsc chorusLFO => blackhole;
    0.24 => chorusLFO.freq;
    0.13 => chorus.gain;
    
    fun void doChorus()
    {
        3::ms => dur baseDelay;
        
        while( true )
        {
            0.3::ms * chorusLFO.last() + baseDelay => chorus.delay;
            5::ms => now;
        }
        
    }
    spork ~ doChorus();
    
    // pitch lfo
    TriOsc lfo1 => Envelope lfo1env => blackhole;
    270::ms => lfo1env.duration;
    7.9 => lfo1.freq;
    fun void startLFO1()
    {
        1 => lfo1env.keyOn;
        -0.25 => lfo1.phase;
        while( true )
        {
            // TODO scale and hook up
            0.02 * lfo1env.last() + 1 => myFreqWaver;
            5::ms => now;
        }
    }
    
    null @=> Shred startLFO1Shred;

    
    
    fun void sync()
    {
        for( int i; i < unison; i++ )
        {
            // TODO: necessary?
            // 0 => osc1[i].phase => osc2[i].phase;
        }
        if( startLFO1Shred != null )
        {
            startLFO1Shred.exit();
        }
        spork ~ startLFO1() @=> startLFO1Shred;
    }
    
    
    // analog: randomly alter pitch and cutoff (0 to 1: 1. units?)
    0.005 => float analog;
    float analogs[unison + 1];
    fun void calculateAnalog()
    {
        for( int i; i < analogs.size(); i++ )
        {
            Math.random2f( 1 - analog, 1 + analog ) => analogs[i];
        }
    }
    
    
    
    // lpf cutoff
    fun float cutoffToHz( float cutoff )
    {
        return Math.min( Std.scalef( Math.pow( Std.clampf( cutoff, 0, 1 ), 3 ), 0, 1, myFreq, 18000 ), 18000 );
    }
    
    // LPF cutoff envelope
    ADSR lpfEnv => blackhole;
    0.0001 => float lpfSustain;
    410::ms => dur lpfDecay;
    lpfEnv.set( 1::ms, lpfDecay, lpfSustain, 5400::ms );
    
    fun void triggerLPFEnv()
    {
        // reset
        0 => lpfEnv.value;
        lpfSustain => lpfEnv.sustainLevel;
        // bounds
        0.74 => float minCutoff;
        // higher cutoff at higher pitch and at higher velocity
        Std.scalef( Math.pow( myVelocity, 1.6 ), 0, 1, 0.34, 0.64 )
            + Std.scalef( myMidi, 0, 128, 0, 0.6 ) => float maxCutoff;
        
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
    1300::ms => rTime;
    adsr.set( 1::ms, 99::ms, 0.99, rTime );
    
    // osc1: freq
    fun void applyFreqs()
    {
        float f1;
        while( true )
        {
            Math.min( myLPFCutoff * analogs[unison], 21000 ) => lpf.freq;
            
            // myFreq
            myFreq * myFreqWaver => f1;
            
            for( int i; i < unison; i++ )
            {
                f1 * analogs[i] => osc1[i].freq;
            }
            
            f1 => root.freq;

            10::ms => now;
        }
    }
    spork ~ this.applyFreqs();
    
        
    // trigger note on
    fun void noteOn()
    {
        // sync
        sync();
        // key on
        adsr.keyOn( 1 );
        triggerLPFEnvShred.exit();
        spork ~ this.triggerLPFEnv() @=> triggerLPFEnvShred;
        calculateAnalog();
        
    }
    
    // trigger note off
    fun void noteOff()
    {
        adsr.keyOff( 1 );
        endLPFEnv();
    }
    
}


class SquarePluckVoice extends VoiceBankVoice
{
    // override
    0.5 => gainAtZeroVelocity;
    0.3 => highCutoffSensitivity;
    -0.55 => lowCutoffSensitivity;
    
    2 => int unison;

    400 => float myLPFCutoff;
    LPF lpf => adsr;
    
    SqrOsc osc1[unison];
    
    // oscs, gain, widths
    for( int i; i < unison; i++ )
    {
        1.0 / unison => osc1[i].gain;
        osc1[i] => lpf;
    }
    

    
    
    fun void sync()
    {
        for( int i; i < unison; i++ )
        {
            // TODO: necessary?
            0 => osc1[i].phase;
        }
    }
    
    
    // analog: randomly alter pitch and cutoff (0 to 1: 1. units?)
    0.002 => float analog;
    float analogs[unison + 1];
    fun void calculateAnalog()
    {
        for( int i; i < analogs.size(); i++ )
        {
            Math.random2f( 1 - analog, 1 + analog ) => analogs[i];
        }
    }
    
    

    fun float cutoffToHz( float cutoff )
    {
        return Math.min( Std.scalef( Math.pow( Std.clampf( cutoff, 0, 1 ), 3 ), 0, 1, myFreq, 18000 ), 18000 );
    }
    
    // LPF cutoff envelope 
    ADSR lpfEnv => blackhole;
    0.209 => float lpfSustain;
    730::ms => dur lpfDecay;
    lpfEnv.set( 1::ms, lpfDecay, lpfSustain, 820::ms );
    
    fun void triggerLPFEnv()
    {
        // reset
        0 => lpfEnv.value;
        lpfSustain => lpfEnv.sustainLevel;
        // bounds
        Math.pow( myVelocity, 1.6 ) => float v;
        0.2 + Std.scalef( myMidi, 0, 128, 0, 0.25 ) 
              + Std.scalef( v, 0, 1, 0, 0.35 ) => float minCutoff;
        Std.scalef( v, 0, 1, 0.25, 0.5 ) => float cutoffDiff;
        minCutoff => float currentCutoff;
        
        //<<< minCutoff, minCutoff + cutoffDiff >>>;
                
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
    440::ms => rTime;
    adsr.set( 1::ms, 99::ms, 0.99, rTime );
    
    // osc1: freq
    fun void applyFreqs()
    {
        while( true )
        {
            Math.min( myLPFCutoff * analogs[unison], 21000 ) => lpf.freq;
            
            for( int i; i < unison; i++ )
            {
                myFreq * analogs[i] => osc1[i].freq;
            }

            5::ms => now;
        }
    }
    spork ~ this.applyFreqs();
        
    // trigger note on
    fun void noteOn()
    {
        // sync
        sync();
        // key on
        adsr.keyOn( 1 );
        triggerLPFEnvShred.exit();
        spork ~ this.triggerLPFEnv() @=> triggerLPFEnvShred;
        calculateAnalog();
        
    }
    
    // trigger note off
    fun void noteOff()
    {
        adsr.keyOff( 1 );
        endLPFEnv();
    }
        
}


class SquarePluck extends VoiceBank
{
    8 => numVoices;
    
    // voices
    SquarePluckVoice myVoices[numVoices];
    // assign to superclass
    v.size( myVoices.size() );
    for( int i; i < myVoices.size(); i++ )
    {
        myVoices[i] @=> v[i];
    }
    // connect
    init( true );
}

GVerb rev;
SquarePluck s => LPF l =>  dac;
0.15 => s.gain;
//0.0 => rev.mix;
15000 => l.freq;

// knobs
0.2 => global float gReverb;
12000 => global float gCutoff;
3000 =>global float gLowpass;

fun void ApplyGlobals()
{
    while( true )
    {
        10::ms => now;
       // gReverb => rev.mix;
        gLowpass => l.freq;
        gCutoff => s.cutoff;
    }
}
spork ~ ApplyGlobals();

// end knobs




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



