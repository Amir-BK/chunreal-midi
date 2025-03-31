// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "UObject/NoExportTypes.h"
#include "IAudioProxyInitializer.h"
#include "MetasoundDataTypeRegistrationMacro.h"
#include "Chunreal.h"
#include <unordered_map>
//#include "Chunreal/chuck/chuck.h"
#include "Sound/SoundGenerator.h"
#include "Sound/SoundBase.h"
#include "Components/SynthComponent.h"
#include "ChuckInstance.generated.h"

DECLARE_MULTICAST_DELEGATE(FOnChuckNeedsRecompile);
DECLARE_DYNAMIC_DELEGATE_OneParam(FOnGlobalEventExecuted, FString, GlobalEventName);
DECLARE_DELEGATE_OneParam(FOnGlobalEventExecutedNative, const FString&);

namespace ChunrealMetasound
{
	template<typename ValueType>
	struct TChunrealValue;


	template<>
	struct TChunrealValue<int32>
	{
		static int32 GetValueFromChuck(ChucK* ChuckRef, const FString& ParamName)
		{
			//UE_LOG(LogTemp, Warning, TEXT("Getting int value from Chuck"));

			return ChuckRef->globals()->get_global_int_value(TCHAR_TO_ANSI(*ParamName));
		}

		static void SetValueToChuck(ChucK* ChuckRef, const FString& ParamName, int32 Value)
		{
			//UE_LOG(LogTemp, Warning, TEXT("Setting int value to Chuck"));
			ChuckRef->globals()->setGlobalInt(TCHAR_TO_ANSI(*ParamName), Value);
		}
	};

	template<>
	struct TChunrealValue<float>
	{
		static float GetValueFromChuck(ChucK* ChuckRef, const FString& ParamName)
		{
			//UE_LOG(LogTemp, Warning, TEXT("Getting float value from Chuck"));
			return ChuckRef->globals()->get_global_float_value(TCHAR_TO_ANSI(*ParamName));
		}

		static void SetValueToChuck(ChucK* ChuckRef, const FString& ParamName, float Value)
		{
			//UE_LOG(LogTemp, Warning, TEXT("Setting float value to Chuck"));
			ChuckRef->globals()->setGlobalFloat(TCHAR_TO_ANSI(*ParamName), Value);
		}
	};

	template<>
	struct TChunrealValue<FString>
	{
		static FString GetValueFromChuck(ChucK* ChuckRef, const FString& ParamName)
		{
			const char* string = ChuckRef->globals()->get_global_string(TCHAR_TO_ANSI(*ParamName))->str().c_str();
			return ANSI_TO_TCHAR(string);

		}

		static void SetValueToChuck(ChucK* ChuckRef, const FString& ParamName, const FString& Value)
		{
			ChuckRef->globals()->setGlobalString(TCHAR_TO_ANSI(*ParamName), TCHAR_TO_ANSI(*Value));
		}
	};

	//array types
	template<>
	struct TChunrealValue<TArray<int32>>
	{
		static TArray<int32> GetValueFromChuck(ChucK* ChuckRef, const FString& ParamName)
		{
			t_CKUINT result = 0;
			TArray<int32> Array;
			Chuck_Object* CkArray = ChuckRef->globals()->get_global_array(TCHAR_TO_ANSI(*ParamName));
			if (CkArray != NULL)
			{
				Chuck_ArrayInt* intArray = (Chuck_ArrayInt*)CkArray;
				for (t_CKUINT i = 0; i < intArray->size(); i++)
				{

					intArray->get(i, &result);
					Array.Add(result);
				}
			}

			return Array;


		}

		static void SetValueToChuck(ChucK* ChuckRef, const FString& ParamName, const TArray<int32>& Value)
		{
			ChuckRef->globals()->setGlobalIntArray(TCHAR_TO_ANSI(*ParamName), (t_CKINT*)Value.GetData(), Value.Num());
		}
	};

	template<>
	struct TChunrealValue<TArray<float>>
	{
		static TArray<float> GetValueFromChuck(ChucK* ChuckRef, const FString& ParamName)
		{
			t_CKFLOAT result = 0;
			TArray<float> Array;
			Chuck_Object* CkArray = ChuckRef->globals()->get_global_array(TCHAR_TO_ANSI(*ParamName));
			if (CkArray != NULL)
			{
				Chuck_ArrayFloat* floatArray = (Chuck_ArrayFloat*)CkArray;
				for (t_CKUINT i = 0; i < floatArray->size(); i++)
				{
					floatArray->get(i, &result);
					Array.Add(result);
				}
			}

			return Array;
		}

		static void SetValueToChuck(ChucK* ChuckRef, const FString& ParamName, const TArray<float>& Value)
		{

			ChuckRef->globals()->setGlobalFloatArray(TCHAR_TO_ANSI(*ParamName), (double*)Value.GetData(), Value.Num());

		}
	};
};

class UChuckInstantiation;

//class FChuckInstanceProxy;
/**
 * A chuck processor really represents the CODE for a chuck, not the actual running instance of a chuck,
 * So it's more of a template and I might rename it to reflect this
 */
UCLASS(ClassGroup = (Chunreal), BlueprintType)
class CHUNREAL_API UChuckCode : public UObject, public IAudioProxyDataFactory
{
	GENERATED_BODY()

	// Inherited via IAudioProxyDataFactory
	virtual TSharedPtr<Audio::IProxyData> CreateProxyData(const Audio::FProxyDataInitParams& InitParams) override;

public:

	//indicates that an audio managed asset is orphaned and is no longer synced to a source file on disk
	UPROPERTY(VisibleAnywhere, Category = "Chuck")
	bool bIsStale = false;

	UPROPERTY()
	bool bIsAutoManaged = false; //for chucks that are automatically created by the system from .ck files in the working directory

	UPROPERTY(VisibleAnywhere, Category = "Chuck")
	FDateTime LastModifiedTimestamp;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Chuck")
	FString SourcePath;



	UPROPERTY(BlueprintReadWrite, VisibleAnywhere, Category = "Chuck", meta = (MultiLine = true, ExposeOnSpawn = true))
	FString Code;

	//spawn chuck vm, should probably be in the instantiation class rather than code class 
	ChucK* CreateChuckVm(int32 InNumChannels = 2);

	UFUNCTION(BlueprintCallable, Category = "ChucK")
	UChuckInstantiation* SpawnChuckInstance();

	void CompileChuckAsset(ChucK* chuckRef);

	//TMap<FString, Chuck*> ChuckInstances;

	FOnChuckNeedsRecompile OnChuckNeedsRecompile;

	// extra chuck files that need to be compiled with this chuck code, critical for things like the midi renderer and other libraries
	UPROPERTY(VisibleAnywhere, Category = "ChucK")
	TArray<FString> Dependencies;

	const TArray<FString>& GetDependencies() const { return Dependencies; }
protected:





private:



	//none of these are used 
	ChucK* Chuck = nullptr;

	bool bChuckCompiled = false;
	bool bHasSporkedOnce = false;
	std::shared_ptr<ChucK*> ChuckPtr = nullptr;

	
};

UCLASS(BlueprintType)
class CHUNREAL_API UChuckInstrumentCode : public UChuckCode
{
	GENERATED_BODY()

public:

	FString Test;

};

class CHUNREAL_API FChuckCodeProxy : public Audio::TProxyData<FChuckCodeProxy>
{
public:
	IMPL_AUDIOPROXY_CLASS(FChuckCodeProxy);

	explicit FChuckCodeProxy(UChuckCode* InChuckProcessor)
		: 
		ChuckProcessor(InChuckProcessor)
	{
	}

	FChuckCodeProxy(const FChuckCodeProxy& Other) = default;

	UChuckCode* ChuckProcessor = nullptr;
	//FString ChuckCode;


};

//so lazy so let's add the Chuck Synth Component here
UCLASS(ClassGroup = Synth, meta = (BlueprintSpawnableComponent))
class CHUNREAL_API UChuckSynthComponent : public USynthComponent
{
	GENERATED_BODY()

public:
	//this just needs init and on generate audio
	ChucK* ChuckVm = nullptr;

	UFUNCTION(BlueprintCallable, Category = "Chuck")
	void InitWithChuckInstance(UChuckInstantiation* InChuckInstance);

	//in theory we may want to actual call the chuck init from here, but we'll see, this object must have a chuck to process so if no chuck return false?
	virtual bool Init(int32& SampleRate) override {
		NumChannels = 2;
		if (ChuckVm) return true;

		return false;
	};

	virtual int32 OnGenerateAudio(float* OutAudio, int32 NumSamples) override {
		//we assume chuck vm exists here
		
		if (!bBuffersInitialized)
		{
			//this hard coding to stereo ain't great, we know the number of channels and can support multi channel if we want.
			DummyInputBuffer = new float[NumSamples];
			bBuffersInitialized = true;
		}
		 
		//will probably crash right away if we destroy the underlying instance, maybe we can create a delegate for that
		// in metasounds we usually use the 'BlockFrameSize' which refersto one channel, here we receive num samples, which is for all channels, ergo, divide by numchannels.
		FChunrealModule::RunChuck(ChuckVm, DummyInputBuffer, OutAudio, NumSamples / 2);

		return NumSamples;
	};

	~UChuckSynthComponent()
	{
		//no need to clear chuck VM cause it isn't 'owned' by this class, but we do need to delete the dummy buffer
		if (bBuffersInitialized)
		{
			delete DummyInputBuffer;
		}
	}

private:
	bool bBuffersInitialized = false;

	//for now dummy buffer but in theory we can also receive audio busses, or the microphone, or whatever.
	float* DummyInputBuffer = nullptr;



};

//this should represent a live instance of a chuck vm, it is not meant to be shared by sound generators as this will corrupt the buffers
//Differentiating between the two kind of objects lets us use Chucks as templates while also having access to their parameters, from metasound as well as BP and code.
//this class allows communicating events to a chuck instance that produces audio (and data) inside a metasound
// while you can pull data and events from this class anywhere you should only connect it to one sound producer, in fact it must be connected to one to work
// if you need a chuck instance that doesn't produce audio just output the chuck audio to a "blackhole" or something.
UCLASS(BlueprintType, Transient, Within = ChuckCode)
class CHUNREAL_API UChuckInstantiation : public UObject, public IAudioProxyDataFactory
{
	GENERATED_BODY()


public:

	UChuckInstantiation();

	~UChuckInstantiation();
public:

	UFUNCTION(BlueprintCallable, Category = "Chuck")
	UChuckSynthComponent* SpawnChuckSynthComponent() {
		UE_LOG(LogTemp, Warning, TEXT("Spawning Chuck Synth Component"));
		UChuckSynthComponent* ChuckSynthComponent = NewObject<UChuckSynthComponent>(this, NAME_None, RF_Transient);
		ChuckSynthComponent->ChuckVm = ChuckVm;
		return ChuckSynthComponent;
	};

	//subscribe to a global event executed by the chuck VM, returns the event ID that can be used for unsubscribing
	UFUNCTION(BlueprintCallable, Category = "Chuck", meta = (AutoCreateRefTerm = "InDelegate", Keywords = "Event, Quantization, DAW"))
	int SubscribeToGlobalEvent(FString EventName, const FOnGlobalEventExecuted& InDelegate);

	int SubscribeToGlobalEventNative(FString EventName, const FOnGlobalEventExecutedNative& InDelegate);

	UFUNCTION(BlueprintAuthorityOnly, Category = "Chuck")
	void ExecuteGlobalEvent(FString EventName) {
		// I think we don't need to check if is valid... we'll see
		ChuckVm->globals()->broadcastGlobalEvent(TCHAR_TO_ANSI(*EventName));

	};

	UFUNCTION(BlueprintCallable, Category = "Chuck")
	void SetGlobalFloat(FString ParamName, float Value) {
		ChuckVm->globals()->setGlobalFloat(TCHAR_TO_ANSI(*ParamName), Value);
	};

	UFUNCTION(BlueprintCallable, Category = "Chuck")
	void SetGlobalInt(FString ParamName, int Value) {
		ChuckVm->globals()->setGlobalInt(TCHAR_TO_ANSI(*ParamName), Value);
	};

	UFUNCTION(BlueprintCallable, Category = "Chuck")
	void SetGlobalString(FString ParamName, FString Value) {
		ChuckVm->globals()->setGlobalString(TCHAR_TO_ANSI(*ParamName), TCHAR_TO_ANSI(*Value));
	};

	UFUNCTION(BlueprintCallable, Category = "Chuck")
	void SetGlobalFloatArray(FString ParamName, TArray<float> Value) {
		ChuckVm->globals()->set_global_float_array(TCHAR_TO_ANSI(*ParamName), (double*) Value.GetData(), Value.Num());
	};

	UFUNCTION(BlueprintCallable, Category = "Chuck")
	void SetGlobalIntArray(FString ParamName, TArray<int32> Value) {
		ChuckVm->globals()->set_global_int_array(TCHAR_TO_ANSI(*ParamName), (t_CKINT*)Value.GetData(), Value.Num());
	};

	

	UFUNCTION(BlueprintCallable, Category = "Chuck")
	float GetGlobalFloat(FString ParamName) {
		return ChunrealMetasound::TChunrealValue<float>::GetValueFromChuck(ChuckVm, ParamName);
	};

	UFUNCTION(BlueprintCallable, Category = "Chuck")
	int GetGlobalInt(FString ParamName) {
		return ChunrealMetasound::TChunrealValue<int32>::GetValueFromChuck(ChuckVm, ParamName);
	};

	UFUNCTION(BlueprintCallable, Category = "Chuck")
	FString GetGlobalString(FString ParamName) {
		return ChunrealMetasound::TChunrealValue<FString>::GetValueFromChuck(ChuckVm, ParamName);
	};

	UFUNCTION(BlueprintCallable, Category = "Chuck")
	TArray<float> GetGlobalFloatArray(FString ParamName) {
		return ChunrealMetasound::TChunrealValue<TArray<float>>::GetValueFromChuck(ChuckVm, ParamName);
	};

	UFUNCTION(BlueprintCallable, Category = "Chuck")
	TArray<int32> GetGlobalIntArray(FString ParamName) {
		return ChunrealMetasound::TChunrealValue<TArray<int32>>::GetValueFromChuck(ChuckVm, ParamName);
	};

	//virtual ISoundGeneratorPtr CreateSoundGenerator(const FSoundGeneratorInitParams& InParams) { return ISoundGeneratorPtr(this); }

	//virtual int32 OnGenerateAudio(float* OutAudio, int32 NumSamples) override;

	TArray<FAudioParameter> InputParameters;
	TArray<FAudioParameter> OutputParameters;

	// Inherited via IAudioProxyDataFactory
	virtual TSharedPtr<Audio::IProxyData> CreateProxyData(const Audio::FProxyDataInitParams& InitParams) override;

	void CreateChuckVm(int32 InNumChannels = 2)
	{
		ChuckVm = ParentChuckCode->CreateChuckVm(InNumChannels);
		ChuckVm->init();
		ChuckVm->start();


		//CompileCode();
	}



	void CompileCode()
	{
		
		//is garbage?
		if (!IsValid(this)) return; 
		
		if (ChuckVm == nullptr)
		{
		
			CreateChuckVm();
		}


		if (bHasSporkedOnce)
		{
			Chuck_Msg* msg = new Chuck_Msg;
			msg->type = 3;  //MSG_REMOVEALL
			ChuckVm->vm()->process_msg(msg);
		}
		else
		{
			bHasSporkedOnce = true;
		}
		
		//when the editor is available it will update the code in the asset,
		//This will not completly prevent users from modifying the chuck sources on disk though, as chucks might refer to other chucks,
		//But if all the code in the chuck is self contained it can prevent undesired tempering.


		auto ChunrealModule = FModuleManager::Get().GetModuleChecked<FChunrealModule>("Chunreal");
		auto WorkingDir = ChunrealModule.workingDirectory;
		//add dependencies from code object
		for (auto& Dependency : ParentChuckCode->GetDependencies())
		{
			auto CombinedPath = FPaths::Combine(WorkingDir, Dependency);
			UE_LOG(LogTemp, Log, TEXT("CombPath %s"), *CombinedPath)
			FChunrealModule::CompileChuckFile(ChuckVm, TCHAR_TO_UTF8(*CombinedPath));
		}


		FChunrealModule::CompileChuckCode(ChuckVm, TCHAR_TO_UTF8(*ParentChuckCode->Code));




	}

	void OnChuckCodeAssetChanged()
	{
		UE_LOG(LogTemp, Warning, TEXT("Chuck Code Asset Changed"));
		if (ChuckVm != nullptr)
		{
			CompileCode();
		}
	}


	// the chuck code object used to spawn this instance, 
	UPROPERTY()
	TObjectPtr<UChuckCode> ParentChuckCode;

	bool bHasSporkedOnce = false;

	



public:
	//probably shoulnd't be public
	ChucK* ChuckVm = nullptr;

};

//proxy for Instantiations
class CHUNREAL_API FChuckInstanceProxy : public Audio::TProxyData<FChuckInstanceProxy>
{
public:
	IMPL_AUDIOPROXY_CLASS(FChuckInstanceProxy);

	explicit FChuckInstanceProxy(UChuckInstantiation* InChuckInstance)
		:
		ChuckInstance(InChuckInstance)
	{
	}

	FChuckInstanceProxy(const FChuckInstanceProxy& Other) = default;

	UChuckInstantiation* ChuckInstance = nullptr;
	//FString ChuckCode;


};

namespace Metasound
{
	class CHUNREAL_API FChuckProcessor
	{
	public:
		FChuckProcessor() = default;
		FChuckProcessor(const FChuckProcessor&) = default;
		FChuckProcessor& operator=(const FChuckProcessor& Other) = default;
		FChuckProcessor(const TSharedPtr<Audio::IProxyData>& InInitData)
		{
			ChuckProxy = StaticCastSharedPtr<FChuckCodeProxy>(InInitData);
		}

		bool IsInitialized() const { return ChuckProxy.IsValid(); }

		//void RegenerateInputs() const { ChuckProxy->RegenerateInputs(); }

		const FChuckCodeProxy* GetProxy() const { return ChuckProxy.Get(); }

	private:
		TSharedPtr<FChuckCodeProxy, ESPMode::ThreadSafe> ChuckProxy;
	};

	DECLARE_METASOUND_DATA_REFERENCE_TYPES(FChuckProcessor, CHUNREAL_API, FChuckProcessorTypeInfo, FChuckProcessorReadRef, FChuckProcessorWriteRef)

	class CHUNREAL_API FChuckInstance
	{
	public:
		FChuckInstance() = default;
		FChuckInstance(const FChuckInstance&) = default;
		FChuckInstance& operator=(const FChuckInstance& Other) = default;
		FChuckInstance(const TSharedPtr<Audio::IProxyData>& InInitData)
		{
			ChuckProxy = StaticCastSharedPtr<FChuckInstanceProxy>(InInitData);
		}

		bool IsInitialized() const { return ChuckProxy.IsValid(); }

		//void RegenerateInputs() const { ChuckProxy->RegenerateInputs(); }

		const FChuckInstanceProxy* GetProxy() const { return ChuckProxy.Get(); }

	private:
		TSharedPtr<FChuckInstanceProxy, ESPMode::ThreadSafe> ChuckProxy;
	};

	DECLARE_METASOUND_DATA_REFERENCE_TYPES(FChuckInstance, CHUNREAL_API, FChuckInstanceTypeInfo, FChuckInstanceReadRef, FChuckInstanceWriteRef)
	
}


