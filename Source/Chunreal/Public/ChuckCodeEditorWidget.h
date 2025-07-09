// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "Blueprint/UserWidget.h"
#include "Widgets/Text/SMultiLineEditableText.h"
#include "ChucKSyntaxHighlighter.h"
#include "SCodeEditableText.h"
#include "ChuckInstance.h"
#include "Components/Button.h"
#include "ChuckCodeEditorWidget.generated.h"

DECLARE_DYNAMIC_MULTICAST_DELEGATE(FOnChuckCodeChanged);
DECLARE_DYNAMIC_MULTICAST_DELEGATE(FOnChuckWidgetUnfocus);

namespace ChuckCodeEditorWidget
{
	//the default code that will be displayed in the editor
	static const FString DefaultCode = TEXT("<<<Hello World>>>;");
	static const FLinearColor DefaultBackgroundColor = //* dark green */
		FLinearColor(0.0f, 0.2f, 0.0f, 1.0f);
}

/**
 * 
 */
UCLASS(BlueprintType, Blueprintable)
class CHUNREAL_API UChuckCodeEditorWidget : public UUserWidget
{
	GENERATED_BODY()

public:

	TSharedPtr<SBkCodeEditableText> CodeEditor;
	TSharedPtr<SBox> CodeEditorBox;

	//if true, the code object controlled by this widget will be spawned as a copy of the original object, so edits won't affect the original object
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "ChucK", meta = (ExposeOnSpawn = "true"))
	bool bCreateAsCopy = false;

	// can be useful for examples and the such I guess
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "ChucK", meta = (ExposeOnSpawn = "true"))
	bool bReadOnly = false; 

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "ChucK", meta = (ExposeOnSpawn = "true"))
	FVector2D Size = FVector2D(300.0f, 500.0f);

	UPROPERTY(BlueprintAssignable, Category = "ChucK")
	FOnChuckCodeChanged OnChuckCodeChanged;

	UPROPERTY(BlueprintAssignable, Category = "ChucK")
	FOnChuckWidgetUnfocus OnChuckWidgetUnfocus;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "ChucK")
	TObjectPtr<UChuckCode> ChuckCode;


	//using namespace ChuckCodeEditorWidget;
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "ChucK")
	FLinearColor BackgroundColor = ChuckCodeEditorWidget::DefaultBackgroundColor;

	void NativeConstruct() override;

	virtual TSharedRef<SWidget> RebuildWidget() override;


	virtual void ReleaseSlateResources(bool bReleaseChildren) override;

	void SetBoxSize(FIntPoint InSize);;

public:
	UFUNCTION(BlueprintCallable, Category = "ChucK")
	FText GetCode() const;

	UFUNCTION(BlueprintCallable, Category = "ChucK")
	void SetCode(UChuckCode* InNewCodeObject);

	//Use this to create a transient code object from an existing code file, useful to let the user modify chucks without affecting the original object
	UFUNCTION(BlueprintCallable, Category = "ChucK")
	void CopyCodeFromObject(UChuckCode* InCodeObject);


	//TODO: remove?
	UFUNCTION(BlueprintCallable, Category = "ChucK")
	UChuckCode* SpawnNewChuckCodeObjectFromWidget();
	
	UPROPERTY(BlueprintReadWrite, Category = "ChucK", meta = (BindWidget))
	UButton* CompileButton;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "ChucK", meta = (ExposeOnSpawn = true, MultiLine = true))
	FString InitialCode = TEXT("<<<Hello World>>>;");


};
