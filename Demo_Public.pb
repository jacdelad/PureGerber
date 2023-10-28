EnableExplicit
XIncludeFile "PureGerber.pbi"
UseModule PureGerber

Runtime Enumeration Windows
  #W_Main
EndEnumeration
Runtime Enumeration Gadgets
  #G_Canvas
EndEnumeration
#D_Main =0
#XML = 0

Global *Gerber.Gerber,Temp$

Temp$="<window id='#W_Main' name='MainWindow' text='Gerbera' width='600' height='500' Minwidth='100' minheight='100' flags='#PB_Window_ScreenCentered | #PB_Window_SystemMenu | #PB_Window_MinimizeGadget | #PB_Window_MaximizeGadget | #PB_Window_SizeGadget'>"+
     "<canvas id='#G_Canvas' flags='#PB_Canvas_ClipMouse|#PB_Canvas_Keyboard'/>"+
     "</window>"

ParseXML(#XML,Temp$)
CreateDialog(#D_Main)
OpenXMLDialog(#D_Main,#XML,"MainWindow")
SetWindowState(#W_Main,#PB_Window_Maximize)
EnableGadgetDrop(#G_Canvas,#PB_Drop_Files,#PB_Drag_Copy|#PB_Drag_Link|#PB_Drag_Move)
GerberGadget(#G_Canvas,0,0,0,0,*Gerber,#Gerber_Flag_Canvas)

Repeat
  Select WaitWindowEvent()
    Case #PB_Event_CloseWindow
      Break
    Case #PB_Event_GadgetDrop
      If IsGerber(*Gerber)
        FreeGerber(*Gerber)
      EndIf
      *Gerber=CreateGerberDataFromFile(EventDropFiles())
      CompilerIf #PB_Compiler_OS=#PB_OS_Windows
        *Gerber\Colors\BackgroundColor=GetSysColor_(#COLOR_BTNFACE)
      CompilerElse
        *Gerber\Colors\BackgroundColor=#White
      CompilerEndIf
      *Gerber\Colors\ForegroundColor=#Black
      *Gerber\FillMode=#Gerber_FillMode_Fill
      AssignGerberToGadget(#G_Canvas,*Gerber)
      SetWindowTitle(#W_Main,"Gerbera - "+*Gerber\FileName$)
      If *Gerber=0 Or ListSize(*Gerber\Log\Errors())<>0
        Temp$=*Gerber\FileName$+#CRLF$
        ForEach *Gerber\Log\Errors()
          Temp$+#CRLF$+*Gerber\Log\Errors()
        Next
        MessageRequester("Error list",Temp$,#PB_MessageRequester_Error)
      EndIf
    Case #PB_Event_Gadget
      Select EventType()
        Case #PB_EventType_RightClick
          Select EventGadget()
            Case #G_Canvas
              ResetGerberGadgetData(#G_Canvas)
          EndSelect
      EndSelect
  EndSelect
ForEver

; IDE Options = PureBasic 6.03 LTS (Windows - x64)
; CursorPosition = 11
; Folding = 9-
; Optimizer
; EnableAsm
; EnableThread
; EnableXP
; EnableUser
; DPIAware
; EnableOnError
; CPU = 1
; CompileSourceDirectory
; Compiler = PureBasic 6.03 beta 4 LTS (Windows - x64)
; EnablePurifier
; EnableCompileCount = 8
; EnableBuildCount = 0