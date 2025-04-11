
https://www.youtube.com/watch?v=xoehdKIyygc


https://github.com/user-attachments/assets/78d9cc17-8722-41b2-9c60-9562cfec594b


# Purpose of fork -
This fork encapsulates the chunreal repo as a plugin and makes some changes to the way the ChucK classes interact with Unreal.

The UChuckProcessor is a UObject that can be created as an asset in the editor where ChucK code can be input (with a work in progress syntax highlighter), this object has an audio object proxy and a registered meta sound data type and can be passed directly to the new Chuck Midi Renderer metasound node, the ChucK is compiled when the object proxy is created and thus should be able to play once assigned to the metasound node.

This repo is a work in progress and some aspects are still not working really well and might require redesign.

The end result should be reusable chuck assets that can be used inside metasounds with no BP setup and without needing to trigger compilation on the audio thread, making it simple to use ChucK components as instruments or effects in metasounds or in unDAW: https://github.com/Amir-BK/unDAW



## New workflow!

I split the Chuck asset into two asset types, one is UChuckCode which represents a block of chuck code, either as a proxy to a file on disk (automatically created via the editor module) or just a text block, this asset can spawn a transient UChuckInstantiation object which is compiled upon its creation, the UChuckInstantiation actually owns the ChucK vm pointer and is used to render audio, there are BP methods that compile a UChuckCode to a UChuckInstantiation as well as a metasound node that does the same thing, thus allowing the user to create the chuck instance either fully inside metasounds or in BP/CPP, the chuck instance can then be manipulated via set/get parameter calls and will automatically recompile when the code in the UChuckCode object it was created from is updated.

As well as the metasound nodes a UChuckSynth component and  ChuckSourceEffect and ChuckSubmixEffect classes are provided that can play chucks and manipulate them. 

### Automatic monitoring of chuck source files
The ChunrealEditor module monitors the working directory (inside the plugin folder) for .ck files and will automatically create chuck processor assets for these sources, changes to the source files are tracked and will trigger recompilation of chuck vms using these proxies, this is still a work in progress but there are many advantages to keeping the chucks as source files outside unreal, primarily being able to add them to source control and easily editing them from text editors outside unreal.

At the moment (a matter of days if not hours) it is the 'Chuck Project Editor' that monitors the directory rather than the module itself, the plan is not to have any dependencies on Editor Only functionality so that these chuck sources can also potentially be exposed and modified in packaged games at runtime.

This system also allows keeping the .ck files as source files outside unreal, for more easily working with revision control, right now the Chuck working directory is set to a directory inside the plugin folder, it can be changed in code, eventually I'll expose it in the project settings. 

### pseudo-includes and unreal discovery

As before ChucK 1.5.4 the only way to import files was using the machine.add command inside chuck I created a rudimentary framework to include chuck files and discover them in unreal, to make the chuck compiler ignore these directives they are marked in comments in the .ck file, as the plugin is still not updated to the new chuck version and as the new @import directive is not fully equivalent to the old machine.add for now these psuedo-includes are still used.

```
//UCHUCK(); -- Marks the chuck file for discovery in unreal
//UINSTRUMENT(); -- marks the file as an instrument, right now this doesn't make much of a difference but might help with categorization and search within unreal
//UINCLUDE("ABK-HmxMidi/HmxMidi.ck"); -- an example of an include directive that executes 'machine add' before the the main chuck file is executed.

```

### Receiving harmonix midi streams in chuck instruments 

The HmxMidi.ck is a simple chuck class that exposes three global int arrays and some methods for interactions with the harmonix midi stream similar to the standard MidiIn object, it needs to be included as a UINCLUDE in the chuck file, afterwards it can be used like this in order to trigger notes in the:

```
//UINCLUDE("ABK-HmxMidi/HmxMidi.ck");

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
        //Do note on stuff 
       }
       else if(HarmonixMidi.IsStdNoteOff(msg))
        {
        //NoteOff(msg.data2);
        //Do note off stuff 
        }
    }

}

```

The polyphonic instrument framework uses Jack Atherton's TimbreLibrary classes as a framework and several of his instruments are included. 

### Chugins
Chugins should be added to the appropriate folder in the working directory, I included the compiled chugins for win64 but for other platforms they needed to be added, some of the instruments use GVerb so they might not work on Macos unless you add the mac chugins to the build.cs file for the chunreal module. 


