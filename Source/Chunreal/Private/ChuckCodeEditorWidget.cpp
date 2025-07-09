// Fill out your copyright notice in the Description page of Project Settings.


#include "ChuckCodeEditorWidget.h"

void UChuckCodeEditorWidget::NativeConstruct()
{
	if (ChuckCode)
	{
		CodeEditor->SetText(FText::FromString(ChuckCode->Code));
	}

}

 TSharedRef<SWidget> UChuckCodeEditorWidget::RebuildWidget()
{


	auto CompileIcon = FSlateIcon(FAppStyle::GetAppStyleSetName(), "LevelEditor.Recompile");

	if (CompileButton)
	{
		//compile button icon

		CompileButton->SetStyle(
			FButtonStyle().SetNormal(*CompileIcon.GetIcon()));
	}

	auto Hierarchy = SNew(SBorder)
		.BorderImage(FAppStyle::Get().GetBrush("ToolPanel.GroupBorder"))
		.BorderBackgroundColor(BackgroundColor)
		[
			SNew(SVerticalBox)
				+ SVerticalBox::Slot()
				.FillHeight(0.95f)
				[
					SAssignNew(CodeEditorBox, SBox)
						//.MinDesiredWidth(Size.X)
						//.MinDesiredHeight(Size.Y)
						[
							SAssignNew(CodeEditor, SBkCodeEditableText)
								.Text(GetCode())

								.Marshaller(FChucKSyntaxHighlighterMarshaller::Create())
						]
				]
			+ SVerticalBox::Slot()
				.FillHeight(0.05f)
				[
					SNew(SBox)
						.MaxDesiredHeight(15.0f)
						.HeightOverride(15.0f)
						[
							SNew(SHorizontalBox)

								//spacer
								+ SHorizontalBox::Slot()
								.FillWidth(0.8f)
								[
									SNew(SSpacer)
								]
								+ SHorizontalBox::Slot()
								.FillWidth(0.2f)
								[
									SNew(SButton)
										.ButtonStyle(FAppStyle::Get(), "FlatButton.Success")
										.Text(FText::FromString("Compile"))
										.OnClicked_Lambda([this]() -> FReply
											{
												OnChuckCodeChanged.Broadcast();
												return FReply::Handled();
											})
								]
							+ SHorizontalBox::Slot()
								.FillWidth(0.2f)
								[
									SNew(SButton)
										.Text(FText::FromString("X"))
										.OnClicked_Lambda([this]() -> FReply
											{
												OnChuckWidgetUnfocus.Broadcast();
												return FReply::Handled();
											})
								]

						]

				]
		];


	return Hierarchy;
}

void UChuckCodeEditorWidget::ReleaseSlateResources(bool bReleaseChildren)
{
	Super::ReleaseSlateResources(bReleaseChildren);

	CodeEditor.Reset();
}

void UChuckCodeEditorWidget::SetBoxSize(FIntPoint InSize)
{
	if (CodeEditorBox.IsValid())
	{
		//CodeEditorBox->SetWidthOverride(InSize.X);
		//CodeEditorBox->SetHeightOverride(InSize.Y);
	}

}


 FText UChuckCodeEditorWidget::GetCode() const
{
	if (ChuckCode)
	{
		return FText::FromString(ChuckCode->Code);
	}

	return INVTEXT("// sad but rue");
}


 void UChuckCodeEditorWidget::SetCode(UChuckCode* InNewCodeObject)
{
	ChuckCode = InNewCodeObject;
	if (CodeEditor.IsValid())
	{
		if (InNewCodeObject)
		{
			CodeEditor->SetText(FText::FromString(InNewCodeObject->Code));
		}
		else {
			CodeEditor->SetText(FText::FromString(ChuckCodeEditorWidget::DefaultCode));
		}
	}

	OnChuckCodeChanged.Broadcast();

	//CodeEditor->SetText(InCode);
}

 //Use this to create a transient code object from an existing code file, useful to let the user modify chucks without affecting the original object

 void UChuckCodeEditorWidget::CopyCodeFromObject(UChuckCode* InCodeObject)
 {
	 if (InCodeObject)
	 {
		 ChuckCode = NewObject<UChuckCode>(this);
		 SetCode(InCodeObject);
	 }
 }

 //TODO: remove?

 UChuckCode* UChuckCodeEditorWidget::SpawnNewChuckCodeObjectFromWidget()
 {
	 FString Code = GetCode().ToString();
	 UChuckCode* ChuckInstance = NewObject<UChuckCode>();
	 ChuckInstance->Code = Code;
	 //ChuckInstance->ChuckGuid = FGuid();
	 return ChuckInstance;
 }
