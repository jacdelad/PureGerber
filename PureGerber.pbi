;{ PureGerber Module 1.0 WIP
;17.01.2024
;by Jac de Lad
;
;READ BEFORE USAGE:
;
;I'm not good with the legal stuff, so:
;Don't make me responsible for damage on your data or computer. Use at your own risk!
;Also, I do not guarantee errorfree Gerber file processing.
;This module is aimed to be 100% compatible with Gerber X3 (minus the missing features (see below) until they are done, plus some deprecated features)
;Use the Reference Gerber Viewer in case of doubt: https://gerber-viewer.ucamco.com/
;Gerber Layout Format Specification: https://www.ucamco.com/en/guest/downloads/gerber-format
;
;You are free to use this module in every noncommercial and commercial project as you like,
;as long as you only distribute compiled code. This explicitely excludes distributing wrappers
;(like a DLL) which only wrap the functionality of this module and which i explicitely don't allow.
;Include a declaration of my ownership as well as the used version into your projects!
;
;You are not allowed to distribute this source or parts of it! Refer to the official downloads instead.
;You are absolutely not allowed to make money with this source (this excludes compiled programs, do whatever you want with it).
;
;In case of questions contact me via PureBasic Forum: https://www.purebasic.fr/english/memberlist.php?mode=viewprofile&u=18168
;...or visit the release thread: https://www.purebasic.fr/english/viewtopic.php?t=82399
;...or create a new thread there.
;
;What is still missing:
;- Primitives: Moire (deprecated) and Thermal (code 6 and 7)
;- variables ($1..$n)
;- aperture blocks (AB)
;- step and repeat (SR)
;- Some transformations: LM, LR and LS -> development started
;
;This module/library does not really check for errors. Faulty Gerber files may be rendered incompletely without warning.
;
;This module uses parts of published code by other people:
;- SplitL/Split-function for high speed string splitting, published by wilbert: http://forums.purebasic.com/english/viewtopic.php?t=65159
;  Without this function I had rely on StringField which is pretty slow (or invent something faster by myself)
;}

DeclareModule PureGerber
  #Gerber_Version = "1.0 WIP 28.10.2023"  
  Enumeration Gerber_FillMode
    #Gerber_FillMode_Fill        ;Fill polygons
    #Gerber_FillMode_Skeleton    ;Draw Skeleton
  EndEnumeration
  Enumeration Gerber_Unit
    #Gerber_Unit_MM
    #Gerber_Unit_Inch
  EndEnumeration
  EnumerationBinary Gerber_Flags;Flags for GerberGadget
    #Gerber_Flag_Canvas         ;Reuse existing CanvasGadget
    #Gerber_Flag_NoDrawing      ;Don't draw on creation/assigment
  EndEnumeration
  EnumerationBinary Gerber_PureGerberFlags
    #Gerber_PGF_Fill
    #Gerber_PGF_Skeleton
  EndEnumeration
  #Gerber_PGF_All = #Gerber_PGF_Fill+#Gerber_PGF_Skeleton
  
  Structure Pos
    X.d
    Y.d
  EndStructure
  Structure Gerber_Vertex
    X.f
    Y.f
  EndStructure
  Structure Gerber_Primitive
    Type.a
    Exposure.a
    Diameter.f
    CenterX.f
    CenterY.f
    Rotation.f
    Radian.f;Precalculated
    Width.f
    Height.f
    StartX.f
    StartY.f
    EndX.f
    EndY.f
    OuterDiameter.f
    InnerDiameter.f
    Gap.f
    VertexCount.w
    RingThickness.f
    CrosshairThickness.f
    CrosshairLength.f
    List Vertices.Gerber_Vertex()
  EndStructure
  Structure Gerber_AM
    List Primitives.Gerber_Primitive()
  EndStructure
  Structure Gerber_Aperture
    Type.a
    ApertureMacro.s
    Diameter.d
    Vertex.a
    Rotation.f
    Radian.f;Precalculated
    X.d
    Y.d
    InnerX.d
    InnerY.d
    List ApertureBlock.s()
  EndStructure
  Structure Gerber_Colors
    BackgroundColor.l
    ForegroundColor.l
  EndStructure
  Structure Gerber_Header
    OmittedZeros.a
    CoordinateMode.a
    SequenceNumber.a
    PreparatoryFunctionCode.a
    X.d
    Y.d
    Z.d
    DraftCode.a
    MiscCode.a
    Digits.a
    ExposureMode.a
    Scaling.d
    List Names.s()
    List Comments.s()
    Map Attributes.s()
    Map Header.a()
  EndStructure
  Structure Gerber_Log
    LoadingTime.l    ;in ms
    LastRenderTime.l ;in ms
    List Errors.s()
  EndStructure
  Structure Gerber_Data
    Map ApertureMacro.Gerber_AM()
    Map Apertures.Gerber_Aperture()
    Polarity.a
    ScaleFactor.f
    Rotation.f
  EndStructure
  Structure Gerber_Pace
    ID.a
    X.d
    Y.d
    R.d
    I.d
    J.d
    F.l
  EndStructure
  Structure Gerber_Cache
    List Filled.Gerber_Pace()
    List Skeleton.Gerber_Pace()
  EndStructure
  Structure Gerber
    ;For internal use:
    Header.Gerber_Header
    Data.Gerber_Data
    Mutex.i
    Cache.Gerber_Cache
    ;For public use:
    FileName$;Initial filename if loaded from file
    Min.Pos
    Max.Pos
    Colors.Gerber_Colors
    FillMode.a
    BoardSize.Pos;always in mm
    DrawScaling.f
    Unit.a;mm/inch
    Log.Gerber_Log
  EndStructure
  
  Declare GerberGadget(Gadget.i,X.l,Y.l,Width.l,Height.l,*Gerber.Gerber,Flags.l=#False,Window.i=#Null)
  Declare PlotGerberToCanvas(Gadget.i,*Gerber.Gerber)
  Declare PlotGerberToImage(Image.i,*Gerber.Gerber,Width.l=0,Height.l=0);Specify width/height when using #PB_Any!
  Declare CreateGerberDataFromString(Gerber$)
  Declare CreateGerberDataFromFile(File$)
  Declare SetGerberCallback(*FunctionAddress,Timeout);Use 0 as address to disable callback, timeout is the minimum wait time between calls (in ms)
  Declare IsGerber(*Gerber.Gerber)
  Declare FreeGerber(*Gerber.Gerber)
  Declare CatchGerber(*Memory,Size=0)
  Declare AssignGerberToGadget(Gadget.i,*Gerber.Gerber,NoDrawing.a=#False)
  Declare CreatePureGerber(*Gerber.Gerber,Flags=#Gerber_PGF_All);Returns a PureGerber object (size via MemorySize(*Memory))
  Declare LoadPureGerber(*Memory,Size.l=0)                      ;Loads a PureGerber object, zero size means MemorySize(*Memory)
  Declare IsGerberValid(*Gerber.Gerber)
  Declare ResetGerberGadgetData(Gadget.i,ReDraw.a=#True);Resets movement and zoom, not the Gerber data!
  Declare RedrawGerberGadget(Gadget.i)
EndDeclareModule

Module PureGerber
  EnableExplicit
  #NewaysMode = #False ;Draws Contours and Fiducials in different colors (according to Neways standard)
  #Gerber_MagicNumber = $208E0EABE50B1EC7;PureGerberObject
  #Gerber_Gadget_StandardZoom = 0.1      ;Standardzoomvalue on GerberGadget (±0.2*CurrentZoom)
  #Gerber_DrawScaling = 0.98             ;Inital scaling factor, 1% of space on each side by default
  Enumeration OmittedZeros
    #Gerber_OZ_No
    #Gerber_OZ_Trailing
    #Gerber_OZ_Leading
  EndEnumeration
  Enumeration CoordinateMode
    #Gerber_Coord_Absolute
    #Gerber_Coord_Incremental
  EndEnumeration
  Enumeration ExposureMode
    #Gerber_EM_Positiv
    #Gerber_EM_Negativ
  EndEnumeration
  ;{ MacroTypes
  #Gerber_MT_Comment       =    0
  #Gerber_MT_Circle        =    1
  #Gerber_MT_LineVector    =    2;=#Gerber_MT_VectorLine
  #Gerber_MT_Outline       =    4
  #Gerber_MT_Polygon       =    5
  #Gerber_MT_Moire         =    6;WIP
  #Gerber_MT_Thermal       =    7;WIP
  #Gerber_MT_VectorLine    =   20
  #Gerber_MT_CenterLine    =   21
  #Gerber_MT_LowerLeftLine =   22
  ;}
  Enumeration Exposure
    #Gerber_Exp_Off
    #Gerber_Exp_On
  EndEnumeration
  Enumeration ApertureType
    #Gerber_AT_Circle
    #Gerber_AT_Rectangle
    #Gerber_AT_Obround
    #Gerber_AT_Polygon
    #Gerber_AT_ApertureMacro
    #Gerber_AT_ApertureBlock
  EndEnumeration
  Enumeration Polarity
    #Gerber_Polarity_Dark
    #Gerber_Polarity_Clear
  EndEnumeration
  Enumeration GMode
    #Gerber_GMode_Undefined
    #Gerber_GMode_G01
    #Gerber_GMode_G02
    #Gerber_GMode_G03
  EndEnumeration
  Enumeration PlotMode
    #Gerber_PlotMode_Draw
    #Gerber_PlotMode_Calculate
    #Gerber_PlotMode_Save
  EndEnumeration
  Enumeration Header
    #Gerber_Header_Missing
    #Gerber_Header_Error
    #Gerber_Header_OK
  EndEnumeration
  ;{ Create RegEx
  Global Gerber_RegEx_Header=CreateRegularExpression(#PB_Any,"^FS([L|T|D])([A|I])(\d?)(\d?)X(\d{2})Y(\d{2})(Z(\d{2}))?(D(\d+))?(M(\d+))?\*$")
  Global Gerber_RegEx_Names=CreateRegularExpression(#PB_Any,"^[IL]N([^\*]+)\*$")
  Global Gerber_RegEx_Unit=CreateRegularExpression(#PB_Any,"^MO(MM|IN)\*$")
  Global Gerber_RegEx_ExposureMode=CreateRegularExpression(#PB_Any,"^IP(POS|NEG)\*$")
  Global Gerber_RegEx_Macro=CreateRegularExpression(#PB_Any,"^AM([^\*]+)\*([^\%]+)$")
  Global Gerber_RegEx_Apertures=CreateRegularExpression(#PB_Any,"^ADD(\d+)([^\,\%]+)\,?(.*)\*$")
  Global Gerber_RegEx_Attributes=CreateRegularExpression(#PB_Any,"^TF\.(\w+)\,(.+)\*$")
  Global Gerber_RegEx_Omitter=CreateRegularExpression(#PB_Any,"[XYIJ][-?\d]+")
  Global Gerber_RegEx_LS=CreateRegularExpression(#PB_Any,"^LS([\d\.]+)\*$")
  Global Gerber_RegEx_LR=CreateRegularExpression(#PB_Any,"^LR(\d+)\*$")
  Global Gerber_RegEx_LM=CreateRegularExpression(#PB_Any,"^LP([XY]+)\*$")
  Global Gerber_RegEx_LP=CreateRegularExpression(#PB_Any,"^LP([CD])\*$")
  Global Gerber_RegEx_MI=CreateRegularExpression(#PB_Any,"^MI([AB][01])([B][01])?\*$")
  Global Gerber_RegEx_SF=CreateRegularExpression(#PB_Any,"^SF([AB][\d\.]+)([B][\d\.]+)?\*$")
  Global Gerber_RegEx_OF=CreateRegularExpression(#PB_Any,"^OF([AB]-?[\d\.]+)?(B-?[\d\.]+)?\*$")
  Global Gerber_RegEx_IR=CreateRegularExpression(#PB_Any,"^IR[0|90|180|270]\*$")
  Global Gerber_RegEx_AS=CreateRegularExpression(#PB_Any,"^ASAXBY|ASAYBX\*$")
  Global Gerber_RegEx_SR=CreateRegularExpression(#PB_Any,"^SRX(\d+)Y(\d+)I(-?[\d\.]+)J(-?[\d\.]+)\*$")
  Global Gerber_RegEx_ApertureBlock=CreateRegularExpression(#PB_Any,"^AB(D\d+)?\*$")
  Global Gerber_RegEx_PreprocessX=CreateRegularExpression(#PB_Any,"X(-?\d+)")
  Global Gerber_RegEx_PreprocessY=CreateRegularExpression(#PB_Any,"Y(-?\d+)")
  Global Gerber_RegEx_Pace=CreateRegularExpression(#PB_Any,"^([XYIJDGM]-?\d+)([XYIJD]-?\d+)?([XYIJD]-?\d+)?([XYIJD]-?\d+)?([XYIJD]-?\d+)?([XYIJD]-?\d+)?([XYIJD]-?\d+)?$")
  Global Gerber_Command_SelectAperture=CreateRegularExpression(#PB_Any,"^((G54D|D)(\d+))$")
  Global Gerber_Command_D01=CreateRegularExpression(#PB_Any,"^([XYIJ])(-?\d+)(([XYIJ])(-?\d+))?(([XYIJ])(-?\d+))?(([XYIJ])(-?\d+))?D01$")
  Global Gerber_Command_D02=CreateRegularExpression(#PB_Any,"^([XY])(-?\d+)(([XY])(-?\d+))?D02$")
  Global Gerber_Command_D03=CreateRegularExpression(#PB_Any,"^(G55)?([XY])(-?\d+)(([XY])(-?\d+))?D03$")
  Global Gerber_Command_Single=CreateRegularExpression(#PB_Any,"^G(\d{2})$")
  Global Gerber_Command_G01=CreateRegularExpression(#PB_Any,"^G01([XY])(-?\d+)(([XY])(-?\d+))?(D0[12])?$")
  Global Gerber_Command_G23=CreateRegularExpression(#PB_Any,"^G0[23]([XYIJ]-?\d+)([XYIJ]-?\d+)?([XYIJ]-?\d+)?([XYIJ]-?\d+)?(D01)?$")
  Global Gerber_Command_G04=CreateRegularExpression(#PB_Any,"^G04.*\*$")
  Global Gerber_Command_FollowUp=CreateRegularExpression(#PB_Any,"^([XYIJ]-?\d+){1,4}$")
  Global Gerber_Command_LP=CreateRegularExpression(#PB_Any,"^LP([CD])$")
  Global Gerber_Command_LS=CreateRegularExpression(#PB_Any,"^LS([\d\.]+)$")
  Global Gerber_Command_LR=CreateRegularExpression(#PB_Any,"^LR(\d+)$")
  Global Gerber_Command_LM=CreateRegularExpression(#PB_Any,"^LM([XY]+)$")
  Global Gerber_Command_End=CreateRegularExpression(#PB_Any,"^M0[012]$")
  ;}
  Enumeration PaceID
    #Gerber_PID_Invalid
    #Gerber_PID_Draw
    #Gerber_PID_Color
    #Gerber_PID_Fill
    #Gerber_PID_End
    #Gerber_PID_Move
    #Gerber_PID_Line
    #Gerber_PID_Circle
    #Gerber_PID_Box
    #Gerber_PID_Close
  EndEnumeration
  Enumeration VectorSourceColor
    #Gerber_VSC_Background
    #Gerber_VSC_Foreground
    #Gerber_VSC_Fiducial
    #Gerber_VSC_Contour
  EndEnumeration
  Structure GerberGadget
    Gerber.i
    X.l
    Y.l
    LastX.l
    LastY.l
    Zoom.f
    ZoomFactor.f
    LeftLock.a
    LastActiveGadget.i
    SizeX.l
    SizeY.l
    UserData.i
    Window.i
    Rotation.f
  EndStructure
  
  UseLZMAPacker()
  Global NewMap GerberList.i(),*Callback,CallbackTimeout.l
  
  ;{ Draw from cache and override functions/macros
  Procedure PlotFromCache(List Cache.Gerber_Pace(),*Gerber.Gerber)
    If ListSize(Cache())
      LockMutex(*Gerber\Mutex)
      VectorSourceColor(*Gerber\Colors\BackgroundColor|$FF000000)
      FillVectorOutput()
      ForEach Cache()
        Select Cache()\ID
          Case #Gerber_PID_Move
            MovePathCursor(Cache()\X,Cache()\Y,Cache()\F)
          Case #Gerber_PID_Line
            AddPathLine(Cache()\X,Cache()\Y,Cache()\F)
          Case #Gerber_PID_Circle
            AddPathCircle(Cache()\X,Cache()\Y,Cache()\R,Cache()\I,Cache()\J,Cache()\F)
          Case #Gerber_PID_Box
            AddPathBox(Cache()\X,Cache()\Y,Cache()\I,Cache()\J,Cache()\F)
          Case #Gerber_PID_Draw
            StrokePath(Cache()\I,Cache()\F)
          Case #Gerber_PID_Fill
            FillPath(Cache()\F)
          Case #Gerber_PID_Color
            Select Cache()\F
              Case #Gerber_VSC_Contour;Contour
                If #NewaysMode
                  VectorSourceColor(#Red|$FF000000)
                Else
                  VectorSourceColor(*Gerber\Colors\ForegroundColor|$FF000000)
                EndIf
              Case #Gerber_VSC_Fiducial;FID
                If #NewaysMode
                  VectorSourceColor(#Blue|$FF000000)
                Else
                  VectorSourceColor(*Gerber\Colors\ForegroundColor|$FF000000)
                EndIf
              Case #Gerber_VSC_Foreground
                VectorSourceColor(*Gerber\Colors\ForegroundColor|$FF000000)
              Case #Gerber_VSC_Background
                VectorSourceColor(*Gerber\Colors\BackgroundColor|$FF000000)
            EndSelect
          Case #Gerber_PID_Close
            ClosePath()
        EndSelect
      Next
      UnlockMutex(*Gerber\Mutex)
    EndIf
  EndProcedure
  
  Procedure AddPathLine_(X.d,Y.d,F.l,*Gerber.Gerber,List Cache.Gerber_Pace())
    AddPathLine(X,Y,F)
    AddElement(Cache())
    Cache()\ID=#Gerber_PID_Line
    Cache()\X=X
    Cache()\Y=Y
    Cache()\F=F
  EndProcedure
  Macro AddPathLine(InX,InY,InF=#PB_Path_Default)
    AddPathLine_(InX,InY,InF,*Gerber,CacheList())
  EndMacro
  
  Procedure MovePathCursor_(X.d,Y.d,F.l,*Gerber.Gerber,List Cache.Gerber_Pace())
    MovePathCursor(X,Y,F)
    If Not(ListSize(Cache()) And Cache()\ID=#Gerber_PID_Move)
      AddElement(Cache())
    EndIf
    Cache()\ID=#Gerber_PID_Move
    Cache()\X=X
    Cache()\Y=Y
  EndProcedure
  Macro MovePathCursor(InX,InY,InF=#PB_Path_Default)
    MovePathCursor_(InX,InY,InF,*Gerber,CacheList())
  EndMacro
  
  Procedure AddPathCircle_(X.d,Y.d,R.d,S.d,E.d,F.l,*Gerber.Gerber,List Cache.Gerber_Pace())
    AddPathCircle(X,Y,R,S,E,F)
    AddElement(Cache())
    Cache()\ID=#Gerber_PID_Circle
    Cache()\X=X
    Cache()\Y=Y
    Cache()\R=R
    Cache()\I=S
    Cache()\J=E
    Cache()\F=F
  EndProcedure
  Macro AddPathCircle(InX,InY,InR,InSt=0,InE=360,InF=#PB_Path_Default)
    AddPathCircle_(InX,InY,InR,InSt,InE,InF,*Gerber,CacheList())
  EndMacro
  
  Procedure AddPathBox_(X.d,Y.d,I.d,J.d,F.l,*Gerber.Gerber,List Cache.Gerber_Pace())
    AddPathBox(X,Y,I,J,F)
    AddElement(Cache())
    Cache()\ID=#Gerber_PID_Box
    Cache()\X=X
    Cache()\Y=Y
    Cache()\I=I
    Cache()\J=J
    Cache()\F=F
  EndProcedure
  Macro AddPathBox(InX,InY,InI,InJ,InF=#PB_Path_Default)
    AddPathBox_(InX,InY,InI,InJ,InF,*Gerber,CacheList())
  EndMacro
  
  Procedure StrokePath_(W.d,F.l,*Gerber.Gerber,List Cache.Gerber_Pace())
    StrokePath(W,F)
    AddElement(Cache())
    Cache()\ID=#Gerber_PID_Draw
    Cache()\I=W
    Cache()\F=F
  EndProcedure
  Macro StrokePath(InW,InF=#PB_Path_Default)
    StrokePath_(InW,InF,*Gerber,CacheList())
  EndMacro
  
  Procedure ClosePath_(*Gerber.Gerber,List Cache.Gerber_Pace())
    ClosePath()
    AddElement(Cache())
    Cache()\ID=#Gerber_PID_Close
  EndProcedure
  Macro ClosePath()
    ClosePath_(*Gerber,CacheList())
  EndMacro
  
  Procedure FillPath_(F.l,*Gerber.Gerber,List Cache.Gerber_Pace())
    FillPath(F)
    AddElement(Cache())
    Cache()\ID=#Gerber_PID_Fill
    Cache()\F=F
  EndProcedure
  Macro FillPath(InF=#PB_Path_Default)
    FillPath_(InF,*Gerber,CacheList())
  EndMacro
  
  Procedure VectorSourceColor_(C.a,*Gerber.Gerber,List Cache.Gerber_Pace())
    AddElement(Cache())
    Cache()\ID=#Gerber_PID_Color
    Cache()\F=C
  EndProcedure
  Macro VectorSourceColor(InCl)
    VectorSourceColor_(Incl,*Gerber,CacheList())
  EndMacro
  ;}
  
  ;{ Helper functions and macros
  Macro TruncList(_List_)
    NewList DummyList()
    SplitList(_List_, DummyList(), #True)
    FreeList(DummyList())
  EndMacro
  Macro Movement(UsedCommand)
    OldPosition\X=Position\X
    OldPosition\Y=Position\Y
    I=Position\X
    J=Position\Y
    If *Gerber\Header\CoordinateMode=#Gerber_Coord_Absolute
      NewPosition\X=Position\X
      NewPosition\Y=Position\Y
    Else
      NewPosition\X=0
      NewPosition\Y=0
    EndIf
    For MMC=1 To CountRegularExpressionGroups(UsedCommand)-1
      Select RegularExpressionGroup(UsedCommand,MMC)
        Case "X"
          NewPosition\X=ValD(RegularExpressionGroup(UsedCommand,MMC+1))
        Case "Y"
          NewPosition\Y=ValD(RegularExpressionGroup(UsedCommand,MMC+1))
        Case "I"
          I=I+ValD(RegularExpressionGroup(UsedCommand,MMC+1))
        Case "J"
          J=J+ValD(RegularExpressionGroup(UsedCommand,MMC+1))
      EndSelect
    Next
    If *Gerber\Header\CoordinateMode=#Gerber_Coord_Absolute
      Position\X=NewPosition\X
      Position\Y=NewPosition\Y
    Else
      Position\X+NewPosition\X
      Position\Y+NewPosition\Y
    EndIf
  EndMacro
  Macro CheckPath(Diff=0)
    If PathBoundsX()-Diff<*Gerber\Min\X:*Gerber\Min\X=PathBoundsX()-Diff:EndIf
    If PathBoundsY()-Diff<*Gerber\Min\Y:*Gerber\Min\Y=PathBoundsY()-Diff:EndIf
    If PathBoundsWidth()+PathBoundsX()+Diff>*Gerber\Max\X:*Gerber\Max\X=PathBoundsWidth()+PathBoundsX()+Diff:EndIf
    If PathBoundsHeight()+PathBoundsY()+Diff>*Gerber\Max\Y:*Gerber\Max\Y=PathBoundsHeight()+PathBoundsY()+Diff:EndIf
  EndMacro
  Macro DrawGerber(MyPosition)
    If Not IsPathEmpty()
      If *Gerber\Data\Polarity=#Gerber_Polarity_Dark
        Select MapKey(*Gerber\Data\Apertures())
          Case "107";Contour
            VectorSourceColor(#Gerber_VSC_Contour);C=#Red|$FF000000
          Case "178"                              ;FID
            VectorSourceColor(#Gerber_VSC_Fiducial);C=#Blue|$FF000000
          Default
            VectorSourceColor(#Gerber_VSC_Foreground)
        EndSelect
      Else
        VectorSourceColor(#Gerber_VSC_Background)
      EndIf
      Select *Gerber\FillMode
        Case #Gerber_FillMode_Skeleton
          If GMode=1
            Select *Gerber\Data\Apertures(Aperture)\Type
              Case #Gerber_AT_Circle
                If *Gerber\Data\Apertures()\Diameter<>0
                  AddPathCircle(MyPosition\X,MyPosition\Y,0.5**Gerber\Data\Apertures()\Diameter**Gerber\Data\ScaleFactor)
                EndIf
              Case #Gerber_AT_Rectangle
                If *Gerber\Data\Apertures()\X<>0
                  AddPathBox(MyPosition\X-0.5**Gerber\Data\Apertures()\X,MyPosition\Y-0.5**Gerber\Data\Apertures()\Y,*Gerber\Data\Apertures()\X**Gerber\Data\ScaleFactor,*Gerber\Data\Apertures()\Y**Gerber\Data\ScaleFactor)
                EndIf
            EndSelect          
          EndIf
          CheckPath()
          StrokePath(1,#PB_Path_Default)
        Case #Gerber_FillMode_Fill
          If G36
            CheckPath()
            FillPath()
          Else
            Select *Gerber\Data\Apertures(Aperture)\Type
              Case #Gerber_AT_Circle
                If *Gerber\Data\Apertures()\Diameter=0
                  CheckPath()
                  StrokePath(1,#PB_Path_Default)
                Else
                  CheckPath(0.5**Gerber\Data\Apertures()\Diameter**Gerber\Data\ScaleFactor)
                  StrokePath(*Gerber\Data\Apertures()\Diameter**Gerber\Data\ScaleFactor,#PB_Path_Default|#PB_Path_RoundEnd|#PB_Path_RoundCorner)
                EndIf
              Case #Gerber_AT_Rectangle
                If *Gerber\Data\Apertures()\X=0
                  CheckPath()
                  StrokePath(1,#PB_Path_Default)
                Else
                  CheckPath(0.5**Gerber\Data\Apertures()\X**Gerber\Data\ScaleFactor)
                  StrokePath(*Gerber\Data\Apertures()\X**Gerber\Data\ScaleFactor,#PB_Path_Default|#PB_Path_SquareEnd)
                EndIf
              Default
                If *Gerber\Data\Apertures()\X=0
                  CheckPath()
                  StrokePath(1,#PB_Path_Default)
                Else
                  CheckPath(0.5**Gerber\Data\Apertures()\X**Gerber\Data\ScaleFactor)
                  StrokePath(*Gerber\Data\Apertures()\X**Gerber\Data\ScaleFactor,#PB_Path_Default)
                EndIf
            EndSelect
          EndIf
      EndSelect
    EndIf
    MovePathCursor(MyPosition\X,MyPosition\Y)
  EndMacro
  Macro CalculatePosition(DataSet)
    Len=Pow(Pow(DataSet\X,2)+Pow(DataSet\Y,2),0.5)
    Rot=ATan2(DataSet\X,DataSet\Y)+*AMacro\Primitives()\Radian
    DataSet\X=*Position\X+Len*Cos(Rot)**Gerber\Data\ScaleFactor
    DataSet\Y=*Position\Y+Len*Sin(Rot)**Gerber\Data\ScaleFactor
  EndMacro
  Macro AddError(MyError)
    LastElement(*Gerber\Log\Errors())
    AddElement(*Gerber\Log\Errors())
    *Gerber\Log\Errors()=MyError
  EndMacro
  Macro IsGerber_(Object)
    Bool(Object And GerberList(Str(Object)))
    ;Bool(Object And GerberList(Str(Object)) And SizeOf(Object)=SizeOf(Gerber) And Object\MagicNumber=#Gerber_MagicNumber)
  EndMacro
  Procedure IsGerber(*Gerber.Gerber)
    ProcedureReturn IsGerber_(*Gerber)
  EndProcedure
  Procedure IsGerberValid(*Gerber.Gerber)
    ProcedureReturn Bool(IsGerber_(*Gerber) And ListSize(*Gerber\Log\Errors())=0)
  EndProcedure
  Procedure FreeGerber(*Gerber.Gerber)
    If IsGerber_(*Gerber)
      DeleteMapElement(GerberList(),Str(*Gerber))
      FreeStructure(*Gerber)
      ProcedureReturn #True
    Else
      ProcedureReturn #False
    EndIf
  EndProcedure
  Procedure SetGerberCallback(*FunctionAddress,Timeout);Use 0 to disable callback, timeout is the minimum wait time between calls (in ms)
    *Callback=*FunctionAddress
    If Timeout>0
      CallbackTimeout=Timeout
    Else
      CallbackTimeout=1000
    EndIf
  EndProcedure
  Procedure SplitL(String.s, Array StringList.s(1))
    Protected S.String,*S.Integer=@S,p.l,Pos.l
    String+"*"
    *S\i=@String
    Pos=ArraySize(StringList())+1
    ReDim StringList(Pos+CountString(String,"*"))
    If StringList(Pos-1)=""
      Pos-1
    EndIf
    Repeat
      p=FindString(S\s,"*")
      If p
        StringList(Pos) = PeekS(*S\i, p-1)
        If StringList(Pos)<>""
          Pos+1
        EndIf
      EndIf
      *S\i + p << #PB_Compiler_Unicode;1 -> *2
    Until p = 0
    *S\i = 0
    If Pos > 0
      ReDim StringList(Pos-1)
    EndIf
  EndProcedure
  Procedure Split(String.s, Array StringArray.s(1))
    Protected S.String,*S.Integer=@S,asize.l=CountString(String,"%"),i.l,p.l
    ReDim StringArray(asize)
    *S\i = @String
    While i < asize
      p=FindString(S\s,"%")
      StringArray(i) = PeekS(*S\i, p - 1)
      *S\i + p << #PB_Compiler_Unicode;1 -> *2
      i + 1
    Wend
    StringArray(i) = S\s
    *S\i = 0
  EndProcedure
  ;}
  
  ;{ Internal plotting functions (for creating the cache)
  Procedure DrawPrimitives(*AMacro.Gerber_AM,*Position.Pos,*Gerber.Gerber,List CacheList.Gerber_Pace())
    Protected Orig.Pos,Rot.d,Count.w,Len.d,NX.d,NY.d,GMode.a=0,Aperture.s="",Pos1.Pos,Pos2.Pos,Pos3.Pos,Pos4.Pos,G36.a=#True
    With *AMacro
      ForEach \Primitives()
        MovePathCursor(*Position\X,*Position\Y,#PB_Path_Default)
        Select \Primitives()\Type
            ;Case #Gerber_MT_Comment
            ;{ Comments already sorted out
            ;}
          Case #Gerber_MT_Circle
            ;{ 1, Circle
            Len=Pow(Pow(\Primitives()\CenterX,2)+Pow(\Primitives()\CenterY,2),0.5)
            Rot=ATan2(\Primitives()\CenterX,\Primitives()\CenterY)
            AddPathCircle(*Position\X+Len*Cos(\Primitives()\Radian+Rot)**Gerber\Data\ScaleFactor,*Position\Y+Len*Sin(\Primitives()\Radian+Rot)**Gerber\Data\ScaleFactor,0.5*\Primitives()\Diameter**Gerber\Data\ScaleFactor,0,360,#PB_Path_Default)
            ;}
          Case #Gerber_MT_LineVector,#Gerber_MT_VectorLine
            ;{ 2 (deprecated in 2015), 20, Line with start point, vector and thickness
            DrawGerber(*Position)
            Len=Pow(Pow(\Primitives()\StartX,2)+Pow(\Primitives()\StartY,2),0.5)
            Rot=ATan2(\Primitives()\StartX,\Primitives()\StartY)+\Primitives()\Radian
            MovePathCursor(*Position\X+Len*Cos(Rot)**Gerber\Data\ScaleFactor,*Position\Y+Len*Sin(Rot)**Gerber\Data\ScaleFactor,#PB_Path_Default)
            Len=Pow(Pow(\Primitives()\EndX,2)+Pow(\Primitives()\EndY,2),0.5)
            Rot=ATan2(\Primitives()\EndX,\Primitives()\EndY)+\Primitives()\Radian
            AddPathLine(*Position\X+Len*Cos(Rot)**Gerber\Data\ScaleFactor,*Position\Y+Len*Sin(Rot)**Gerber\Data\ScaleFactor,#PB_Path_Default)
            If *Gerber\FillMode=#Gerber_FillMode_Fill
              StrokePath(\Primitives()\Width**Gerber\Data\ScaleFactor)
            EndIf
            ;}
          Case #Gerber_MT_Outline
            ;{ 4, Irregular polygon with definition of X,Y-plots
            Len=Pow(Pow(\Primitives()\StartX,2)+Pow(\Primitives()\StartY,2),0.5)
            Rot=ATan2(\Primitives()\StartX,\Primitives()\StartY)+\Primitives()\Radian
            MovePathCursor(*Position\X+Len*Cos(Rot)**Gerber\Data\ScaleFactor,*Position\Y+Len*Sin(Rot)**Gerber\Data\ScaleFactor,#PB_Path_Default)
            ResetList(\Primitives()\Vertices())
            For Count=1 To \Primitives()\VertexCount
              NextElement(\Primitives()\Vertices())
              Len=Pow(Pow(\Primitives()\Vertices()\X,2)+Pow(\Primitives()\Vertices()\Y,2),0.5)
              Rot=ATan2(\Primitives()\Vertices()\X,\Primitives()\Vertices()\Y)+\Primitives()\Radian
              AddPathLine(*Position\X+Len*Cos(Rot)**Gerber\Data\ScaleFactor,*Position\Y+Len*Sin(Rot)**Gerber\Data\ScaleFactor,#PB_Path_Default)
            Next
            ;}
          Case #Gerber_MT_Polygon
            ;{ 5, Polygon with definition per X,Y-coordinates (needs verification!)
            Debug "Regular Polygon (needs verification)"
            Len=Pow(Pow(\Primitives()\CenterX+0.5*\Primitives()\Diameter,2)+Pow(\Primitives()\CenterY,2),0.5)
            Rot=ATan2(\Primitives()\CenterX+0.5*\Primitives()\Diameter,\Primitives()\CenterY)+\Primitives()\Radian
            Pos1\X=*Position\X+Len*Cos(Rot)**Gerber\Data\ScaleFactor
            Pos1\Y=*Position\Y+Len*Sin(Rot)**Gerber\Data\ScaleFactor
            MovePathCursor(Pos1\X,Pos1\Y,#PB_Path_Default)
            For Count=2 To \Primitives()\VertexCount
              Rot+2*#PI/\Primitives()\VertexCount
              AddPathLine(*Position\X+Len*Cos(Rot)**Gerber\Data\ScaleFactor,*Position\Y+Len*Sin(Rot)**Gerber\Data\ScaleFactor,#PB_Path_Default)
            Next
            AddPathLine(Pos1\X,Pos1\Y,#PB_Path_Default)
            ;}
          Case #Gerber_MT_Moire
            ;6 (deprecated in 2021)
            Debug "Primitive ignored: Moire"
          Case #Gerber_MT_Thermal
            ;7
            Debug "Primitive ignored: Thermal (annulus)"
          Case #Gerber_MT_CenterLine
            ;{ 21, Line with center point, thickness and width (basically a rectangle) (needs verification!)
            Debug "CenterLine (needs verification!)"
            Pos1\X=\Primitives()\CenterX-0.5*\Primitives()\Width
            Pos1\Y=\Primitives()\CenterY-0.5*\Primitives()\Height
            Pos2\X=Pos1\X+\Primitives()\Width
            Pos2\Y=Pos1\Y
            Pos3\X=Pos2\X
            Pos3\Y=Pos1\Y+\Primitives()\Height
            Pos4\X=Pos1\X
            Pos4\Y=Pos3\Y
            CalculatePosition(Pos1)
            CalculatePosition(Pos2)
            CalculatePosition(Pos3)
            CalculatePosition(Pos4)
            MovePathCursor(Pos1\X,Pos1\Y,#PB_Path_Default)
            AddPathLine(Pos2\X,Pos2\Y,#PB_Path_Default)
            AddPathLine(Pos3\X,Pos3\Y,#PB_Path_Default)
            AddPathLine(Pos4\X,Pos4\Y,#PB_Path_Default)
            AddPathLine(Pos1\X,Pos1\Y,#PB_Path_Default)
            ;}
          Case #Gerber_MT_LowerLeftLine
            ;{ 22 (deprecated in 2015), Rectangle with start point, width and height (needs verification!)
            Debug "LowerLeftLine (needs verification!)"
            Pos1\X=\Primitives()\CenterX
            Pos1\Y=\Primitives()\CenterY
            Pos2\X=Pos1\X+\Primitives()\Width
            Pos2\Y=Pos1\Y
            Pos3\X=Pos2\X
            Pos3\Y=Pos1\Y+\Primitives()\Height
            Pos4\X=Pos1\X
            Pos4\Y=Pos3\Y
            CalculatePosition(Pos1)
            CalculatePosition(Pos2)
            CalculatePosition(Pos3)
            CalculatePosition(Pos1)
            MovePathCursor(Pos1\X,Pos1\Y,#PB_Path_Default)
            AddPathLine(Pos2\X,Pos2\Y,#PB_Path_Default)
            AddPathLine(Pos3\X,Pos3\Y,#PB_Path_Default)
            AddPathLine(Pos4\X,Pos4\Y,#PB_Path_Default)
            AddPathLine(Pos1\X,Pos1\Y,#PB_Path_Default)
            ;}
          Default
            Debug "Unknown Primitive: "+Str(\Primitives()\Type)
        EndSelect
        ;       If *Gerber\FillMode=#Gerber_FillMode_Fill
        ;         DrawGerber(*Position)
        ;       EndIf
      Next
    EndWith
  EndProcedure
  
  Procedure DrawAperture(*Aperture.Gerber_Aperture,*Position.Pos,*Gerber.Gerber,*AMacro.Gerber_AM,List CacheList.Gerber_Pace())
    Protected Counter.a,Part.d,Rad.d
    ;MovePathCursor(*Position\X,*Position\Y,#PB_Path_Default)
    With *Aperture
      Select \Type
        Case #Gerber_AT_Circle
          Rad=0.5*\Diameter
          AddPathCircle(*Position\X**Gerber\Data\ScaleFactor,*Position\Y**Gerber\Data\ScaleFactor,Rad,0,360,#PB_Path_Default)
          If \InnerX>0
            AddPathCircle(*Position\X**Gerber\Data\ScaleFactor,*Position\Y**Gerber\Data\ScaleFactor,Rad,0,360,#PB_Path_Default)
          EndIf
        Case #Gerber_AT_Rectangle
          AddPathBox(-0.5*\X**Gerber\Data\ScaleFactor,-0.5*\Y**Gerber\Data\ScaleFactor,\X**Gerber\Data\ScaleFactor,\Y**Gerber\Data\ScaleFactor,#PB_Path_Relative)
        Case #Gerber_AT_Obround
          If \X>\Y
            AddPathCircle(-0.5*(\X-\Y)**Gerber\Data\ScaleFactor,0,0.5*\Y**Gerber\Data\ScaleFactor,90,270,#PB_Path_Relative)
            AddPathLine((\X-\Y)**Gerber\Data\ScaleFactor,0,#PB_Path_Relative)
            AddPathCircle(0,0.5*\Y**Gerber\Data\ScaleFactor,0.5*\Y**Gerber\Data\ScaleFactor,270,90,#PB_Path_Relative)
            AddPathLine((\Y-\X)**Gerber\Data\ScaleFactor,0,#PB_Path_Relative)
          Else
            AddPathCircle(0,-0.5*(\Y-\X)**Gerber\Data\ScaleFactor,0.5*\X**Gerber\Data\ScaleFactor,180,0,#PB_Path_Relative)
            AddPathLine(0,(\Y-\X)**Gerber\Data\ScaleFactor,#PB_Path_Relative)
            AddPathCircle(-0.5*\X**Gerber\Data\ScaleFactor,0,0.5*\X**Gerber\Data\ScaleFactor,0,180,#PB_Path_Relative)
            AddPathLine(0,(\X-\Y)**Gerber\Data\ScaleFactor,#PB_Path_Relative)
          EndIf
          If \InnerX
            MovePathCursor(*Position\X,*Position\Y,#PB_Path_Default)
            AddPathCircle(*Position\X**Gerber\Data\ScaleFactor,*Position\Y**Gerber\Data\ScaleFactor,\InnerX**Gerber\Data\ScaleFactor,0,360,#PB_Path_Default)
          EndIf
        Case #Gerber_AT_Polygon
          MovePathCursor(0.5*\Diameter*Cos(-1*\Radian)**Gerber\Data\ScaleFactor,0.5*\Diameter*Sin(-1*\Radian)**Gerber\Data\ScaleFactor,#PB_Path_Relative)
          Part=360/\Vertex
          For Counter=0 To \Vertex
            *Position\X+0.5*\Diameter*Cos(Radian(-1*\Rotation+Part*Counter))**Gerber\Data\ScaleFactor
            *Position\Y+0.5*\Diameter*Sin(Radian(-1*\Rotation+Part*Counter))**Gerber\Data\ScaleFactor
            AddPathLine(*Position\X,*Position\Y)
          Next
          If \InnerX>0
            AddPathCircle(*Position\X,*Position\Y,\InnerX**Gerber\Data\ScaleFactor,0,360,#PB_Path_Default)
          EndIf
        Case #Gerber_AT_ApertureMacro
          DrawPrimitives(*AMacro,*Position,*Gerber,CacheList())
        Case #Gerber_AT_ApertureBlock
          AddError("ApertureBlock!")
        Default
          AddError("Aperture-Fehler (Type): "+Str(\Type))
      EndSelect
    EndWith
    MovePathCursor(*Position\X,*Position\Y,#PB_Path_Default)
  EndProcedure
  
  Procedure PlotGerber(*Gerber.Gerber,Array Path.s(1),List CacheList.Gerber_Pace())
    Protected Counter.a,Temp$,Position.Pos,Aperture.s,NewPosition.Pos,Center.Pos,GMode.a,Rad.d,OldPosition.Pos,G36.a,ErrCount.l=ListSize(*Gerber\Log\Errors()),I.d,J.d,MMC.a,Pos.l,Max.l,LastD.a
    Protected SRX.l,SRY.l,SRI.d,SRJ.d
    ResetMap(*Gerber\Data\Apertures())
    MovePathCursor(0,0)
    Position\X=0:Position\Y=0
    NewPosition\X=0:NewPosition\Y=0
    
    With *Gerber\Data
      Max=ArraySize(Path())
      For Pos=0 To Max
        If MatchRegularExpression(Gerber_Command_FollowUp,Path(Pos))
          Path(Pos)=Path(Pos)+"D0"+Str(LastD)
        EndIf
        
        If ExamineRegularExpression(Gerber_Command_D01,Path(Pos)) And NextRegularExpressionMatch(Gerber_Command_D01)
          ;{ D01: LINE
          Movement(Gerber_Command_D01)
          AddPathLine(Position\X,Position\Y,#PB_Path_Default)
          GMode=#Gerber_GMode_G01
          LastD=1
          If Not G36
            If *Gerber\FillMode=#Gerber_FillMode_Skeleton
              Select \Apertures(Aperture)\Type
                Case #Gerber_AT_Circle
                  If \Apertures()\Diameter<>0
                    Rad=0.5*\Apertures()\Diameter
                    AddPathCircle(OldPosition\X,OldPosition\Y,Rad**Gerber\Data\ScaleFactor)
                    AddPathCircle(Position\X,Position\Y,Rad**Gerber\Data\ScaleFactor)
                  EndIf
                Case #Gerber_AT_Rectangle
                  If \Apertures()\X<>0
                    SRI=0.5*\Apertures()\X
                    SRJ=0.5*\Apertures()\Y
                    AddPathBox(OldPosition\X-SRI,OldPosition\Y-SRJ,\Apertures()\X**Gerber\Data\ScaleFactor,\Apertures()\Y**Gerber\Data\ScaleFactor)
                    AddPathBox(Position\X-SRI,Position\Y-SRJ,\Apertures()\X**Gerber\Data\ScaleFactor,\Apertures()\Y**Gerber\Data\ScaleFactor)
                  EndIf
              EndSelect          
              MovePathCursor(Position\X,Position\Y)
            EndIf
          EndIf
          ;}
        ElseIf ExamineRegularExpression(Gerber_Command_D02,Path(Pos)) And NextRegularExpressionMatch(Gerber_Command_D02)
          ;{ D02: MOVE
          Movement(Gerber_Command_D02)
          MovePathCursor(Position\X,Position\Y,#PB_Path_Default)
          LastD=2
          ;}
        ElseIf ExamineRegularExpression(Gerber_Command_D03,Path(Pos)) And NextRegularExpressionMatch(Gerber_Command_D03)
          ;{ D03: FLASH
          Movement(Gerber_Command_D03)
          ;MovePathCursor(Position\X,Position\Y,#PB_Path_Default)
          DrawGerber(Position)
          If Aperture<>""
            DrawAperture(\Apertures(Aperture),Position,*Gerber,\ApertureMacro(\Apertures(Aperture)\ApertureMacro),CacheList())
          EndIf
          LastD=3
          G36=#True
          DrawGerber(Position)
          G36=#False
          ;}
        ElseIf ExamineRegularExpression(Gerber_Command_G01,Path(Pos)) And NextRegularExpressionMatch(Gerber_Command_G01)
          ;{ G01: Linear-Plot-Mode
          Movement(Gerber_Command_G01)
          Select RegularExpressionGroup(Gerber_Command_G01,CountRegularExpressionGroups(Gerber_Command_G01))
            Case "D01"
              If *Gerber\FillMode=#Gerber_FillMode_Skeleton
                If Not G36
                  Select \Apertures(Aperture)\Type
                    Case #Gerber_AT_Circle
                      Rad=0.5*\Apertures()\Diameter
                      AddPathCircle(OldPosition\X,OldPosition\Y,Rad**Gerber\Data\ScaleFactor,0,360,#PB_Path_Default)
                      AddPathCircle(Position\X,Position\Y,Rad**Gerber\Data\ScaleFactor,0,360,#PB_Path_Default)
                    Case #Gerber_AT_Rectangle
                      SRI=0.5*\Apertures()\X
                      SRJ=0.5*\Apertures()\Y
                      AddPathBox(OldPosition\X-SRI,OldPosition\Y-SRJ,\Apertures()\X**Gerber\Data\ScaleFactor,\Apertures()\Y**Gerber\Data\ScaleFactor,#PB_Path_Default)
                      AddPathBox(Position\X-SRI,Position\Y-SRJ,\Apertures()\X**Gerber\Data\ScaleFactor,\Apertures()\Y**Gerber\Data\ScaleFactor,#PB_Path_Default)
                  EndSelect
                  MovePathCursor(OldPosition\X,OldPosition\Y,#PB_Path_Default)
                EndIf
                AddPathLine(Position\X,Position\Y,#PB_Path_Default)
              Else
                AddPathLine(Position\X,Position\Y,#PB_Path_Default)
              EndIf
              LastD=1
            Case "D02"
              MovePathCursor(Position\X,Position\Y,#PB_Path_Default)
              LastD=2
            Default
              If G36
                AddPathLine(Position\X,Position\Y,#PB_Path_Default)
                LastD=1
              Else
                AddError("G01-Error: "+Path(Pos))
              EndIf
          EndSelect
          GMode=#Gerber_GMode_G01
          ;}
        ElseIf ExamineRegularExpression(Gerber_Command_G23,Path(Pos)) And NextRegularExpressionMatch(Gerber_Command_G23)
          ;{ G02/G03: Circle mode (clockwise/counterclockwise)
          GMode=Val(Mid(Path(Pos),3,1))
          NewPosition\X=Position\X
          NewPosition\Y=Position\Y
          Center\X=Position\X
          Center\Y=Position\Y
          For Counter=1 To CountRegularExpressionGroups(Gerber_Command_G23)
            Temp$=RegularExpressionGroup(Gerber_Command_G23,Counter)
            Select Left(Temp$,1)
              Case "X"
                If *Gerber\Header\CoordinateMode=#Gerber_Coord_Absolute
                  NewPosition\X=ValD(Right(Temp$,Len(Temp$)-1))
                Else
                  NewPosition\X=Position\X+ValD(Right(Temp$,Len(Temp$)-1))
                EndIf
              Case "Y"
                If *Gerber\Header\CoordinateMode=#Gerber_Coord_Absolute
                  NewPosition\Y=ValD(Right(Temp$,Len(Temp$)-1))
                Else
                  NewPosition\Y=Position\Y+ValD(Right(Temp$,Len(Temp$)-1))
                EndIf
              Case "I"
                Center\X=Position\X+ValD(Right(Temp$,Len(Temp$)-1))
              Case "J"
                Center\Y=Position\Y+ValD(Right(Temp$,Len(Temp$)-1))
            EndSelect
          Next
          If NewPosition\X=Position\X And NewPosition\Y=Position\Y
            Rad=Pow(Pow(Center\X-Position\X,2)+Pow(Center\Y-Position\Y,2),0.5)
            If Center\X=Position\X Or Center\Y=Position\Y;Rad<=\Apertures(Aperture)\Diameter/2
              MovePathCursor(Position\X,Position\Y)
              If Rad<\Apertures(Aperture)\Diameter/2
                AddPathLine(Center\X,Center\Y,#PB_Path_Default)
              Else
                AddPathCircle(Center\X,Center\Y,Rad)
              EndIf
            Else
              Debug Rad
              AddPathCircle(Center\X,Center\Y,Rad)
            EndIf
            ;DrawGerber(Position)
          Else
            Rad=Pow(Pow(Center\X-Position\X,2)+Pow(Center\Y-Position\Y,2),0.5)
            If *Gerber\FillMode=#Gerber_FillMode_Skeleton
              AddPathCircle(Center\X,Center\Y,Rad,Degree(ATan2(Position\X-Center\X,Position\Y-Center\Y)),Degree(ATan2(NewPosition\X-Center\X,NewPosition\Y-Center\Y)),(#PB_Path_CounterClockwise*Bool(GMode=#Gerber_GMode_G02))|(#PB_Path_Connected*G36))
              Rad=0.5*\Apertures(Aperture)\Diameter
              AddPathCircle(Position\X,Position\Y,Rad)
              AddPathCircle(NewPosition\X,NewPosition\Y,Rad)
              MovePathCursor(Position\X,Position\Y)
              AddPathLine(NewPosition\X,NewPosition\Y)
            Else
              If Not G36 And Rad<\Apertures(Aperture)\Diameter/2
                DrawGerber(Position)
                MovePathCursor(NewPosition\X,NewPosition\Y)
                AddPathCircle(Center\X,Center\Y,Rad+\Apertures(Aperture)\Diameter/2,Degree(ATan2(Position\X-Center\X,Position\Y-Center\Y)),Degree(ATan2(NewPosition\X-Center\X,NewPosition\Y-Center\Y)),(#PB_Path_CounterClockwise*Bool(GMode=#Gerber_GMode_G02)))
                ClosePath()
                G36=#True
                DrawGerber(Position)
                G36=#False
              Else
                AddPathCircle(Center\X,Center\Y,Rad,Degree(ATan2(Position\X-Center\X,Position\Y-Center\Y)),Degree(ATan2(NewPosition\X-Center\X,NewPosition\Y-Center\Y)),(#PB_Path_CounterClockwise*Bool(GMode=#Gerber_GMode_G02))|(#PB_Path_Connected*G36))
              EndIf
            EndIf
          EndIf
          Position\X=NewPosition\X
          Position\Y=NewPosition\Y
          If Not G36
            If *Gerber\FillMode=#Gerber_FillMode_Fill And \Apertures(Aperture)\Diameter>0
              ;StrokePath(\Apertures(Aperture)\Diameter,#PB_Path_RoundEnd)
            Else
              ;StrokePath(1,#PB_Path_RoundEnd)
            EndIf
          EndIf
          LastD=1
          ;}
        ElseIf ExamineRegularExpression(Gerber_Command_SelectAperture,Path(Pos)) And NextRegularExpressionMatch(Gerber_Command_SelectAperture)
          ;{ G54: Set aperture
          If Aperture
            DrawGerber(Position)
          EndIf
          Temp$=RegularExpressionGroup(Gerber_Command_SelectAperture,3)
          If Val(Temp$)>9 And FindMapElement(\Apertures(),Temp$)
            Aperture=Temp$
            *Gerber\Data\ScaleFactor=1.0
            *Gerber\Data\Rotation=0.0
            If \Apertures(Temp$)\Type=#Gerber_AT_ApertureBlock
              AddError("Uses Aperture Blocks. This feature is not completed yet!")
            EndIf
          ElseIf Temp$="01"
            ;AddError("ToDo: G54D01")
            GMode=#Gerber_GMode_G01
          ElseIf Temp$="02"
            ;Ignore
          ElseIf Temp$="03"
            ;Ignore!
            ;AddError("ToDo: G54D03")
          Else
            AddError("G54-Error/Unknown aperture: D"+Temp$)
          EndIf
          GMode=#Gerber_GMode_Undefined
          ;}
        ElseIf Path(Pos)="G36"
          ;{ G36: Begin Contour
          DrawGerber(Position)
          G36=#True
          Aperture=""
          *Gerber\Data\ScaleFactor=1.0
          *Gerber\Data\Rotation=0.0
          ;}
        ElseIf Path(Pos)="G37"
          ;{ G37: End Contour
          If *Gerber\FillMode
            GMode=0
          Else
            GMode=1
          EndIf
          ;ClosePath()
          DrawGerber(Position)
          G36=#False
          ;}
        ElseIf ExamineRegularExpression(Gerber_Command_LS,Path(Pos)) And NextRegularExpressionMatch(Gerber_Command_LS)
          ;{ LS: Set scale factor (reset after every G54!)
          DrawGerber(Position)
          *Gerber\Data\ScaleFactor=ValF(RegularExpressionGroup(Gerber_Command_LS,1))
          ;}
        ElseIf ExamineRegularExpression(Gerber_Command_LR,Path(Pos)) And NextRegularExpressionMatch(Gerber_Command_LR)
          ;{ LR: Set rotation (reset after every G54!)
          *Gerber\Data\Rotation=ValF(RegularExpressionGroup(Gerber_Command_LR,1))
          ;}
        ElseIf ExamineRegularExpression(Gerber_Command_LP,Path(Pos)) And NextRegularExpressionMatch(Gerber_Command_LP)
          ;{ LPx: Set to Dark/Clear Mode
          DrawGerber(Position)
          Select RegularExpressionGroup(Gerber_Command_LP,1)
            Case "D"
              *Gerber\Data\Polarity=#Gerber_Polarity_Dark
            Case "C"
              *Gerber\Data\Polarity=#Gerber_Polarity_Clear
          EndSelect
          MovePathCursor(Position\X,Position\Y,#PB_Path_Default)
          ;}
        ElseIf MatchRegularExpression(Gerber_Command_End,Path(Pos))
          ;{ End of plotting sequence
          Break
          ;}
        ElseIf ExamineRegularExpression(Gerber_Command_Single,Path(Pos)) And NextRegularExpressionMatch(Gerber_Command_Single)
          Select RegularExpressionGroup(Gerber_Command_Single,1)
            Case "01","02","03"
              GMode=Val(RegularExpressionGroup(Gerber_Command_Single,1))
            Case "75","74","04"
              ;  G75: Switch To linear plotting (obsolete)
              ;  G74: Switch To quadrant mode (obsolete)
              ;  G04: Ignore, it's a comment
            Default
              AddError("Error or ignored command: "+Path(Pos))
          EndSelect
        ElseIf Path(Pos)="G01D01"
          ;  G01D01: Whatever it is supposed to do...
          GMode=1
        ElseIf Path(Pos)<>""
          ;{ Now, that's an error or some unsupported command
          AddError("Error or ignored command: "+Path(Pos))
          ;}
        EndIf
        
      Next
    EndWith
    DrawGerber(Position)
    
    CompilerIf #PB_Compiler_Debugger;debug drawing errors
      If ListSize(*Gerber\Log\Errors())>ErrCount
        Debug "File: "+*Gerber\FileName$+" -> "+Str(ListSize(*Gerber\Log\Errors()))+"  error(s)"
        SelectElement(*Gerber\Log\Errors(),ErrCount)
        Repeat
          Debug *Gerber\Log\Errors()
        Until NextElement(*Gerber\Log\Errors())=0
      EndIf
    CompilerEndIf
  EndProcedure
  ;}
  
  ;{ Interactive GerberGadget
  ;{ Mousewheel fix for Windows < 10, adapted from original code by mk-soft: http://forums.purebasic.com/english/viewtopic.php?t=70074
  CompilerIf #PB_Compiler_OS=#PB_OS_Windows
    
    Enumeration #PB_EventType_FirstCustomValue
      #My_EventType_MouseWheelUp
      #My_EventType_MouseWheelDown
    EndEnumeration
    
    Import ""
      PB_Object_EnumerateStart( PB_Objects )
      PB_Object_EnumerateNext( PB_Objects, *ID.Integer )
      PB_Object_EnumerateAbort( PB_Objects )
      PB_Object_GetObject( PB_Object , DynamicOrArrayID)
      PB_Window_Objects.i
      PB_Gadget_Objects.i
    EndImport
    
    Procedure HoverGadget()
      Protected x, y, handle, gadget
      x = DesktopMouseX()
      y = DesktopMouseY()
      handle = WindowFromPoint_(y << 32 | x)
      PB_Object_EnumerateStart(PB_Gadget_Objects)
      While PB_Object_EnumerateNext(PB_Gadget_Objects, @gadget)
        If handle = GadgetID(gadget)
          PB_Object_EnumerateAbort(PB_Gadget_Objects)
          ProcedureReturn gadget
        EndIf
      Wend
      ProcedureReturn -1
    EndProcedure
    
    Procedure WinCB(hWnd, uMsg, wParam, lParam)
      Protected gadget, wheel
      If uMsg = #WM_MOUSEWHEEL
        gadget = HoverGadget()
        If gadget >= 0 And GadgetType(Gadget)=#PB_GadgetType_Canvas
          wheel = wParam >> 16 / 120
          If wheel > 0
            PostEvent(#PB_Event_Gadget, GetProp_(UseGadgetList(0),StringField("PB_WINDOWID",1,","))-1, gadget, #My_EventType_MouseWheelUp, Wheel)
          Else
            PostEvent(#PB_Event_Gadget, GetProp_(UseGadgetList(0),StringField("PB_WINDOWID",1,","))-1, gadget, #My_EventType_MouseWheelDown, Wheel)
          EndIf
        EndIf
      EndIf
      ProcedureReturn #PB_ProcessPureBasicEvents
    EndProcedure
    
    If OSVersion()<#PB_OS_Windows_10
      SetWindowCallback(@WinCB())
    EndIf
    
  CompilerEndIf
  ;}
  
  Procedure EventHandler()
    Protected GSize.Pos,Size.Pos,Gadget.i=EventGadget(),*Data.GerberGadget=GetGadgetData(Gadget),*Gerber.Gerber,Draw.a
    If *Data
      GSize\X=GadgetWidth(Gadget)
      GSize\Y=GadgetHeight(Gadget)
      *Gerber=*Data\Gerber
      If IsGerber_(*Gerber)
        With *Gerber
          Select EventType()
            Case #PB_EventType_Resize
              Draw=#True
              CompilerIf #PB_Compiler_OS=#PB_OS_Windows
              Case #My_EventType_MouseWheelDown,#My_EventType_MouseWheelUp
                If GetGadgetAttribute(Gadget,#PB_Canvas_Modifiers)&#PB_Canvas_Control
                  *Data\Rotation-90*EventData()
                  While *Data\Rotation>=360
                    *Data\Rotation-360
                  Wend
                  While *Data\Rotation<0
                    *Data\Rotation+360
                  Wend
                Else
                  *Data\Zoom=*Data\Zoom+(1+4*Bool(GetGadgetAttribute(Gadget,#PB_Canvas_Modifiers)&#PB_Canvas_Shift))**Data\ZoomFactor**Data\Zoom*EventData()
                EndIf
                Draw=#True
              CompilerEndIf
            Case #PB_EventType_MouseWheel
              If GetGadgetAttribute(Gadget,#PB_Canvas_Modifiers)&#PB_Canvas_Control
                *Data\Rotation-90*GetGadgetAttribute(Gadget,#PB_Canvas_WheelDelta)
                While *Data\Rotation>=360
                  *Data\Rotation-360
                Wend
                While *Data\Rotation<0
                  *Data\Rotation+360
                Wend
              Else
                *Data\LastX=GetGadgetAttribute(Gadget,#PB_Canvas_MouseX)
                *Data\LastY=GetGadgetAttribute(Gadget,#PB_Canvas_MouseY)
                *Data\X=(*Data\LastX-*Data\X)/*Data\Zoom
                *Data\Y=(*Data\LastY-*Data\Y)/*Data\Zoom
                *Data\Zoom=*Data\Zoom+(1+4*Bool(GetGadgetAttribute(Gadget,#PB_Canvas_Modifiers)&#PB_Canvas_Shift))**Data\ZoomFactor**Data\Zoom*GetGadgetAttribute(Gadget,#PB_Canvas_WheelDelta)
                *Data\X=-1*(*Data\X**Data\Zoom-*Data\LastX)
                *Data\Y=-1*(*Data\Y**Data\Zoom-*Data\LastY)
              EndIf
              Draw=#True
            Case #PB_EventType_LeftButtonDown
              *Data\LastX=GetGadgetAttribute(Gadget,#PB_Canvas_MouseX)
              *Data\LastY=GetGadgetAttribute(Gadget,#PB_Canvas_MouseY)
              *Data\LeftLock=#True
            Case #PB_EventType_LeftButtonUp
              *Data\X=*Data\X-*Data\LastX+GetGadgetAttribute(Gadget,#PB_Canvas_MouseX)
              *Data\Y=*Data\Y-*Data\LastY+GetGadgetAttribute(Gadget,#PB_Canvas_MouseY)
              *Data\LastX=GetGadgetAttribute(Gadget,#PB_Canvas_MouseX)
              *Data\LastY=GetGadgetAttribute(Gadget,#PB_Canvas_MouseY)
              *Data\LeftLock=#False
              Draw=#True
            Case #PB_EventType_MiddleButtonUp
              *Data\Rotation+90
              If *Data\Rotation>=360
                *Data\Rotation-360
              EndIf
              Draw=#True
            Case #PB_EventType_MouseEnter
              *Data\LastActiveGadget=GetActiveGadget()
              SetActiveGadget(Gadget)
            Case #PB_EventType_MouseLeave
              SetActiveGadget(*Data\LastActiveGadget)
            Case #PB_EventType_MouseMove
              If *Data\LeftLock
                Select *Data\Rotation
                  Case 0
                    *Data\X=*Data\X-*Data\LastX+GetGadgetAttribute(Gadget,#PB_Canvas_MouseX)
                    *Data\Y=*Data\Y-*Data\LastY+GetGadgetAttribute(Gadget,#PB_Canvas_MouseY)
                  Case 90
                    *Data\X=*Data\X+*Data\LastY-GetGadgetAttribute(Gadget,#PB_Canvas_MouseY)
                    *Data\Y=*Data\Y-*Data\LastX+GetGadgetAttribute(Gadget,#PB_Canvas_MouseX)
                  Case 180
                    *Data\X=*Data\X+*Data\LastX-GetGadgetAttribute(Gadget,#PB_Canvas_MouseX)
                    *Data\Y=*Data\Y+*Data\LastY-GetGadgetAttribute(Gadget,#PB_Canvas_MouseY)
                  Case 270
                    *Data\X=*Data\X-*Data\LastY+GetGadgetAttribute(Gadget,#PB_Canvas_MouseY)
                    *Data\Y=*Data\Y+*Data\LastX-GetGadgetAttribute(Gadget,#PB_Canvas_MouseX)
                EndSelect
                *Data\LastX=GetGadgetAttribute(Gadget,#PB_Canvas_MouseX)
                *Data\LastY=GetGadgetAttribute(Gadget,#PB_Canvas_MouseY)
                Draw=#True
              EndIf
          EndSelect
          If Draw
            StartVectorDrawing(CanvasVectorOutput(Gadget))
            Size\X=GadgetWidth(Gadget)/(\Max\X-\Min\X)
            Size\Y=GadgetHeight(Gadget)/(\Max\Y-\Min\Y)
            If Size\X>Size\Y:Size\X=Size\Y:EndIf
            TranslateCoordinates(*Data\X,*Data\Y,#PB_Coordinate_User)
            ScaleCoordinates(Size\X*\DrawScaling**Data\Zoom,Size\X*\DrawScaling**Data\Zoom,#PB_Coordinate_User)
            TranslateCoordinates(-\Min\X+0.5*(1-\DrawScaling)*(\Max\X-\Min\X),\Min\Y+0.5*(1-\DrawScaling)*(\Max\Y-\Min\Y),#PB_Coordinate_User)
            FlipCoordinatesY(0.5*(\Max\Y-\Min\Y),#PB_Coordinate_User)
            RotateCoordinates(ConvertCoordinateX(GadgetWidth(Gadget)/2,GadgetHeight(Gadget)/2,#PB_Coordinate_Output,#PB_Coordinate_User),ConvertCoordinateY(GadgetWidth(Gadget)/2,GadgetHeight(Gadget)/2,#PB_Coordinate_Output,#PB_Coordinate_User),*Data\Rotation,#PB_Coordinate_User)
            If *Gerber\FillMode=#Gerber_FillMode_Fill
              PlotFromCache(*Gerber\Cache\Filled(),*Gerber)
            Else
              PlotFromCache(*Gerber\Cache\Skeleton(),*Gerber)
            EndIf
            StopVectorDrawing()
            *Data\SizeX=GSize\X
            *Data\SizeY=GSize\Y
          ElseIf GSize\X<>*Data\SizeX Or GSize\Y<>*Data\SizeY
            *Data\SizeX=GSize\X
            *Data\SizeY=GSize\Y
            StartDrawing(CanvasOutput(Gadget))
            Box(0,0,GSize\X,GSize\Y,\Colors\BackgroundColor)
            StopDrawing()
          EndIf
        EndWith  
      Else
        StartDrawing(CanvasOutput(Gadget))
        Box(0,0,GSize\X,GSize\Y,GetSysColor_(#COLOR_BTNFACE))
        StopDrawing()
      EndIf
    Else
      StartDrawing(CanvasOutput(Gadget))
      Box(0,0,GadgetWidth(Gadget),GadgetHeight(Gadget),GetSysColor_(#COLOR_BTNFACE))
      StopDrawing()
    EndIf
  EndProcedure
  
  Procedure RedrawGerberGadget(Gadget.i)
    ;PostEvent(#PB_Event_Gadget,GetProp_(UseGadgetList(0),StringField("PB_WINDOWID",1,","))-1,Gadget,#PB_EventType_Resize)
    Protected *Data.GerberGadget
    If IsGadget(Gadget) And GadgetType(Gadget)=#PB_GadgetType_Canvas
      *Data=GetGadgetData(Gadget)
      PostEvent(#PB_Event_Gadget,*Data\Window,Gadget,#PB_EventType_Resize)
    EndIf
  EndProcedure
  
  Procedure ResetGerberGadgetData(Gadget.i,ReDraw.a=#True);Resets movement and zoom, not the Gerber data!
    Protected *Data.GerberGadget=GetGadgetData(Gadget)
    If *Data
      *Data\X=0
      *Data\Y=0
      *Data\LeftLock=0
      *Data\Zoom=1.0
      *Data\Rotation=0
      If ReDraw
        RedrawGerberGadget(Gadget)
      EndIf
    EndIf
  EndProcedure
  
  Procedure GerberGadget(Gadget.i,X.l,Y.l,Width.l,Height.l,*Gerber.Gerber,Flags.l=#False,Window.i=#Null)
    Protected *Data.GerberGadget
    If Flags&#Gerber_Flag_Canvas And IsGadget(Gadget) And GadgetType(Gadget)=#PB_GadgetType_Canvas
      Width=GadgetWidth(Gadget)
      Height=GadgetHeight(Gadget)
    Else
      If Gadget=#PB_Any
        Gadget=CanvasGadget(#PB_Any,X,Y,Width,Height,#PB_Canvas_ClipMouse|#PB_Canvas_Keyboard)
      Else
        CanvasGadget(Gadget,X,Y,Width,Height,#PB_Canvas_ClipMouse|#PB_Canvas_Keyboard)
      EndIf
    EndIf
    *Data=AllocateStructure(GerberGadget)
    *Data\Gerber=*Gerber
    *Data\Zoom=1.0
    *Data\ZoomFactor=0.2
    *Data\X=0
    *Data\Y=0
    If Flags&#Gerber_Flag_Canvas
      *Data\Window=Window
    Else
      *Data\Window=UseGadgetList(0)
    EndIf
    SetGadgetData(Gadget,*Data)
    If IsGerber_(*Gerber) And Not Flags&#Gerber_Flag_NoDrawing
      RedrawGerberGadget(Gadget)
    EndIf
    BindGadgetEvent(Gadget,@EventHandler())
    ProcedureReturn Gadget
  EndProcedure
  
  Procedure AssignGerberToGadget(Gadget.i,*Gerber.Gerber,NoDrawing.a=#False)
    If IsGadget(Gadget) And GadgetType(Gadget)=#PB_GadgetType_Canvas And IsGerber_(*Gerber)
      Protected *Data.GerberGadget
      FreeStructure(GetGadgetData(Gadget))
      *Data=AllocateStructure(GerberGadget)
      *Data\Gerber=*Gerber
      *Data\Zoom=1.0
      *Data\ZoomFactor=#Gerber_Gadget_StandardZoom
      *Data\X=0
      *Data\Y=0
      SetGadgetData(Gadget,*Data)
      If Not NoDrawing
        ;PostEvent(#PB_Event_Gadget,GetProp_(UseGadgetList(0),StringField("PB_WINDOWID",1,","))-1,Gadget,#PB_EventType_Resize)
        RedrawGerberGadget(Gadget)
      EndIf
      ProcedureReturn #True
    Else
      SetGadgetData(Gadget,0)
      ProcedureReturn #False
    EndIf
  EndProcedure
  
  Procedure FreeGerberGadget(Gadget.i)
    If IsGadget(Gadget) And GadgetType(Gadget)=#PB_GadgetType_Canvas
      UnbindGadgetEvent(Gadget,@EventHandler())
      FreeStructure(GetGadgetData(Gadget))
      FreeGadget(Gadget)
    EndIf
  EndProcedure
  ;}
  
  ;{ Plotting functions
  Procedure PlotGerberToCanvas(Gadget.i,*Gerber.Gerber)
    Protected Tick.q=ElapsedMilliseconds(),Size.Pos
    StartVectorDrawing(CanvasVectorOutput(Gadget))
    Size\X=GadgetWidth(Gadget)/(*Gerber\Max\X-*Gerber\Min\X)
    Size\Y=GadgetHeight(Gadget)/(*Gerber\Max\Y-*Gerber\Min\Y)
    If Size\X>Size\Y:Size\X=Size\Y:EndIf
    ScaleCoordinates(Size\X**Gerber\DrawScaling,Size\X**Gerber\DrawScaling,#PB_Coordinate_User)
    TranslateCoordinates(-*Gerber\Min\X,*Gerber\Min\Y,#PB_Coordinate_User)
    TranslateCoordinates(0.5*(1-*Gerber\DrawScaling)*(*Gerber\Max\X-*Gerber\Min\X),0.5*(1-*Gerber\DrawScaling)*(*Gerber\Max\Y-*Gerber\Min\Y),#PB_Coordinate_User)
    FlipCoordinatesY(0.5*(*Gerber\Max\Y-*Gerber\Min\Y),#PB_Coordinate_User)
    If *Gerber\FillMode=#Gerber_FillMode_Fill
      PlotFromCache(*Gerber\Cache\Filled(),*Gerber)
    Else
      PlotFromCache(*Gerber\Cache\Skeleton(),*Gerber)
    EndIf
    StopVectorDrawing()
    *Gerber\Log\LastRenderTime=ElapsedMilliseconds()-Tick
  EndProcedure
  
  Procedure PlotGerberToImage(Image.i,*Gerber.Gerber,Width.l=0,Height.l=0);Specify width/height when using #PB_Any!
    Protected Tick.q=ElapsedMilliseconds(),Size.Pos
    If Image=#PB_Any
      Image=CreateImage(#PB_Any,Width,Height,24,*Gerber\Colors\BackgroundColor)
    EndIf
    StartVectorDrawing(ImageVectorOutput(Image))
    Size\X=ImageWidth(Image)/(*Gerber\Max\X-*Gerber\Min\X)
    Size\Y=ImageHeight(Image)/(*Gerber\Max\Y-*Gerber\Min\Y)
    If Size\X>Size\Y:Size\X=Size\Y:EndIf
    ScaleCoordinates(Size\X**Gerber\DrawScaling,Size\X**Gerber\DrawScaling,#PB_Coordinate_User)
    TranslateCoordinates(-*Gerber\Min\X,*Gerber\Min\Y,#PB_Coordinate_User)
    TranslateCoordinates(0.5*(1-*Gerber\DrawScaling)*(*Gerber\Max\X-*Gerber\Min\X),0.5*(1-*Gerber\DrawScaling)*(*Gerber\Max\Y-*Gerber\Min\Y),#PB_Coordinate_User)
    FlipCoordinatesY(0.5*(*Gerber\Max\Y-*Gerber\Min\Y),#PB_Coordinate_User)
    If *Gerber\FillMode=#Gerber_FillMode_Fill
      PlotFromCache(*Gerber\Cache\Filled(),*Gerber)
    Else
      PlotFromCache(*Gerber\Cache\Skeleton(),*Gerber)
    EndIf
    StopVectorDrawing()
    *Gerber\Log\LastRenderTime=ElapsedMilliseconds()-Tick
    ProcedureReturn Image
  EndProcedure
  ;}
  
  ;{ Create Gerber objects
  Macro WriteList(MyList,MySize)
    Stop=Pos+MySize
    Repeat
      AddElement(MyList)
      MyList\ID=PeekA(Pos)
      Select PeekA(Pos)
        Case #Gerber_PID_Box
          MyList\X=PeekD(Pos+1)
          MyList\Y=PeekD(Pos+9)
          MyList\I=PeekD(Pos+17)
          MyList\J=PeekD(Pos+25)
          MyList\F=PeekL(Pos+33)
          Pos+37
        Case #Gerber_PID_Circle
          MyList\X=PeekD(Pos+1)
          MyList\Y=PeekD(Pos+9)
          MyList\R=PeekD(Pos+17)
          MyList\I=PeekD(Pos+25)
          MyList\J=PeekD(Pos+33)
          MyList\F=PeekL(Pos+41)
          Pos+45
        Case #Gerber_PID_Close
          Pos+1
        Case #Gerber_PID_Color
          MyList\F=PeekL(Pos+1)
          Pos+5
        Case #Gerber_PID_Draw
          MyList\I=PeekD(Pos+1)
          MyList\F=PeekL(Pos+9)
          Pos+13
        Case #Gerber_PID_Fill
          MyList\F=PeekL(Pos+1)
          Pos+5
        Case #Gerber_PID_Line,#Gerber_PID_Move
          MyList\X=PeekD(Pos+1)
          MyList\Y=PeekD(Pos+9)
          MyList\F=PeekL(Pos+17)
          Pos+21
      EndSelect
    Until Pos>=Stop
  EndMacro
  Macro WritePos(Struct,Address)
    Struct\X=PeekD(Address)
    Struct\Y=PeekD(Address+8)
  EndMacro
  Procedure LoadPureGerber(*Mem,Size.l=0);Loads a PureGerber object, zero size means MemorySize(*Memory)
    #HeaderSize=61
    Protected *Out,OSize.l,retval,*Gerber.Gerber,sFill.l,sSkeleton.l,Pos.l,Stop.l
    If *Mem
      If Size=0
        Size=MemorySize(*Mem)
      EndIf
      If Size>#HeaderSize And PeekQ(*Mem)=#Gerber_MagicNumber
        OSize=PeekL(*Mem+8)
        *Out=AllocateMemory(OSize,#PB_Memory_NoClear)
        retval=UncompressMemory(*Mem+12,Size-12,*Out,OSize,#PB_PackerPlugin_Lzma)
        If retval=OSize
          *Gerber=AllocateStructure(Gerber)
          GerberList(Str(*Gerber))=1
          *Gerber\Mutex=CreateMutex()
          *Gerber\Colors\BackgroundColor=GetSysColor_(#COLOR_BTNFACE)
          *Gerber\Colors\ForegroundColor=#Black
          *Gerber\FillMode=#Gerber_FillMode_Fill
          WritePos(*Gerber\Min,*Out)
          WritePos(*Gerber\Max,*Out+16)
          WritePos(*Gerber\BoardSize,*Out+32)
          *Gerber\Unit=PeekA(*Out+48)
          *Gerber\DrawScaling=PeekF(*Out+49)
          sFill=PeekL(*Out+53)
          sSkeleton=PeekL(*Out+57)
          Pos=*Out+#HeaderSize
          If sFill
            WriteList(*Gerber\Cache\Filled(),sFill)
          EndIf
          If sSkeleton
            WriteList(*Gerber\Cache\Skeleton(),sSkeleton)
          EndIf
          ProcedureReturn *Gerber
        EndIf
      EndIf
    EndIf
    ProcedureReturn 0
  EndProcedure
  
  Macro PokeStructure(Mem,Struct)
    CopyMemory(@Struct,Mem,SizeOf(Struct))
  EndMacro
  Macro GetListSize(MyList,MyVar)
    ForEach MyList
      Select MyList\ID
        Case #Gerber_PID_Box
          MyVar+37
        Case #Gerber_PID_Circle
          MyVar+45
        Case #Gerber_PID_Close
          MyVar+1
        Case #Gerber_PID_Color
          MyVar+5
        Case #Gerber_PID_Draw
          MyVar+13
        Case #Gerber_PID_Fill
          MyVar+5
        Case #Gerber_PID_Line,#Gerber_PID_Move
          MyVar+21
      EndSelect
    Next
  EndMacro
  Macro InsertList(MyList)
    ForEach MyList
      PokeA(Pos,MyList\ID)
      Select MyList\ID
        Case #Gerber_PID_Box
          PokeD(Pos+1,MyList\X)
          PokeD(Pos+9,MyList\Y)
          PokeD(Pos+17,MyList\I)
          PokeD(Pos+25,MyList\J)
          PokeL(Pos+33,MyList\F)
          Pos+37
        Case #Gerber_PID_Circle
          PokeD(Pos+1,MyList\X)
          PokeD(Pos+9,MyList\Y)
          PokeD(Pos+17,MyList\R)
          PokeD(Pos+25,MyList\I)
          PokeD(Pos+33,MyList\J)
          PokeL(Pos+41,MyList\F)
          Pos+45
        Case #Gerber_PID_Close
          Pos+1
        Case #Gerber_PID_Color
          PokeL(Pos+1,MyList\F)
          Pos+5
        Case #Gerber_PID_Draw
          PokeD(Pos+1,MyList\I)
          PokeL(Pos+9,MyList\F)
          Pos+13
        Case #Gerber_PID_Fill
          PokeL(Pos+1,MyList\F)
          Pos+5
        Case #Gerber_PID_Line,#Gerber_PID_Move
          PokeD(Pos+1,MyList\X)
          PokeD(Pos+9,MyList\Y)
          PokeL(Pos+17,MyList\F)
          Pos+21
      EndSelect
    Next
  EndMacro
  Procedure CreatePureGerber(*Gerber.Gerber,Flags=#Gerber_PGF_All);Returns a PureGerber object (size via MemorySize(*Memory))
    #HeaderSize=61
    Protected *Mem,Size.l,*Out,OSize.l,sSkeleton.l,sFill.l,Pos.i
    If IsGerber_(*Gerber)
      
      If Flags&#Gerber_PGF_Fill
        GetListSize(*Gerber\Cache\Filled(),sFill)
      EndIf
      If Flags&#Gerber_PGF_Skeleton
        GetListSize(*Gerber\Cache\Skeleton(),sSkeleton)
      EndIf
      Size=sSkeleton+sFill+#HeaderSize
      *Mem=AllocateMemory(Size,#PB_Memory_NoClear)
      PokeStructure(*Mem,*Gerber\Min)
      PokeStructure(*Mem+16,*Gerber\Max)
      PokeStructure(*Mem+32,*Gerber\BoardSize)
      PokeA(*Mem+48,*Gerber\Unit)
      PokeF(*Mem+49,*Gerber\DrawScaling)
      PokeL(*Mem+53,sFill)
      PokeL(*Mem+57,sSkeleton)
      Pos=*Mem+#HeaderSize
      If Flags&#Gerber_PGF_Fill
        InsertList(*Gerber\Cache\Filled())
      EndIf
      If Flags&#Gerber_PGF_Skeleton
        InsertList(*Gerber\Cache\Skeleton())
      EndIf
      *OUT=AllocateMemory(Size+12,#PB_Memory_NoClear)
      PokeQ(*Out,#Gerber_MagicNumber)
      PokeL(*Out+8,Size)
      OSize=CompressMemory(*Mem,Size,*Out+12,Size,#PB_PackerPlugin_Lzma,9)
      FreeMemory(*Mem)
      If OSize
        *Mem=ReAllocateMemory(*Out,OSize+12)
        If *Mem=0
          FreeMemory(*Out)
        Else
          ProcedureReturn *Mem
        EndIf
      Else
        FreeMemory(*Out)
      EndIf
      
    EndIf
    ProcedureReturn #False
  EndProcedure
  
  Procedure CreateGerberDataFromString(Gerber$)
    Protected Tick.q=ElapsedMilliseconds(),CallbackTick.q=Tick+CallbackTimeout,MacroName$,STemp$,Temp$,PCount.l,PCounter.l,Counter.l,TCount.l,TCounter.l,ACount.l,ATemp$,ACounter.l,*Gerber.Gerber,Position.Pos,Image.i,Dim Out$(0),sum.a,count
    Protected Dim Split$(0),NewList BlockStack.s(),Pos.l,Max.l,Dim Path.s(0)
    If *Callback
      CallFunctionFast(*Callback,0,1)
    EndIf
    Gerber$=ReplaceString(ReplaceString(ReplaceString(ReplaceString(Gerber$,#CR$,""),#LF$,""),#TAB$,"")," ","")
    *Gerber=AllocateStructure(Gerber)
    With *Gerber
      GerberList(Str(*Gerber))=1
      \Mutex=CreateMutex()
      \DrawScaling=#Gerber_DrawScaling
      ;\Min\X=#MAXLONG:\Min\Y=#MAXLONG
      ;\Max\X=-#MAXLONG:\Max\Y=-#MAXLONG
      Split(Gerber$,Split$())
      PCount=ArraySize(Split$())
      
      ;{ Process Gerber string
      For PCounter=1 To PCount
        STemp$=Trim(Split$(PCounter))
        If STemp$<>""
          If MatchRegularExpression(Gerber_RegEx_Header,STemp$)
            ;{ FS -> Format Specification
            If ExamineRegularExpression(Gerber_RegEx_Header,STemp$) And NextRegularExpressionMatch(Gerber_RegEx_Header)
              Select RegularExpressionGroup(Gerber_RegEx_Header,1);Ommited Zeros
                Case "L"
                  \Header\OmittedZeros=#Gerber_OZ_Leading
                Case "T"
                  \Header\OmittedZeros=#Gerber_OZ_Trailing
                Case "D"
                  \Header\OmittedZeros=#Gerber_OZ_No
              EndSelect
              Select RegularExpressionGroup(Gerber_RegEx_Header,2);Coordinate Mode
                Case "A"
                  \Header\CoordinateMode=#Gerber_Coord_Absolute
                Case "I"
                  \Header\CoordinateMode=#Gerber_Coord_Incremental
              EndSelect
              \Header\SequenceNumber=Val(RegularExpressionGroup(Gerber_RegEx_Header,3))
              \Header\PreparatoryFunctionCode=Val(RegularExpressionGroup(Gerber_RegEx_Header,4))
              \Header\X=Val(Left(RegularExpressionGroup(Gerber_RegEx_Header,5),1))
              \Header\Digits=Val(Right(RegularExpressionGroup(Gerber_RegEx_Header,5),1))
              \Header\Y=Val(Left(RegularExpressionGroup(Gerber_RegEx_Header,6),1))
              \Header\Z=Val(Left(RegularExpressionGroup(Gerber_RegEx_Header,7),1))
              \Header\DraftCode=Val(RegularExpressionGroup(Gerber_RegEx_Header,8))
              \Header\MiscCode=Val(RegularExpressionGroup(Gerber_RegEx_Header,9))
              \Header\Scaling=Pow(10,\Header\Digits)
              \Header\Header("Header")=#Gerber_Header_OK
            Else
              AddError("Header error: "+STemp$)
              \Header\Header("Header")=#Gerber_Header_Error
            EndIf
            ;}
          ElseIf MatchRegularExpression(Gerber_RegEx_Names,STemp$)
            ;{ IN/LN -> Image Name/Load Name (deprecated in 2013, use G04)
            If ExamineRegularExpression(Gerber_RegEx_Names,STemp$) And  NextRegularExpressionMatch(Gerber_RegEx_Names)
              AddElement(\Header\Names())
              \Header\Names()=RegularExpressionGroup(Gerber_RegEx_Names,1)
              \Header\Header("Names")=#Gerber_Header_OK
            Else
              AddError("Name-line error: "+STemp$)
              \Header\Header("Names")=#Gerber_Header_Error
            EndIf
            ;}
          ElseIf MatchRegularExpression(Gerber_RegEx_Unit,STemp$)
            ;{ MO -> Load unit (mm/inch)
            If ExamineRegularExpression(Gerber_RegEx_Unit,STemp$) And NextRegularExpressionMatch(Gerber_RegEx_Unit)
              Select RegularExpressionGroup(Gerber_RegEx_Unit,1)
                Case "IN"
                  \Unit=#Gerber_Unit_Inch
                Case "MM"
                  \Unit=#Gerber_Unit_MM
              EndSelect
              \Header\Header("Unit")=#Gerber_Header_OK
            Else
              AddError("MO-line error: "+STemp$)
              \Header\Header("Unit")=#Gerber_Header_Error
            EndIf
            ;}
          ElseIf MatchRegularExpression(Gerber_RegEx_ExposureMode,STemp$)
            ;{ IP -> Image Polarity (positive/negative) (deprecated in October 2013, because handling of IPNEG is not clearly defined)
            If ExamineRegularExpression(Gerber_RegEx_ExposureMode,STemp$) And NextRegularExpressionMatch(Gerber_RegEx_ExposureMode)
              Select RegularExpressionGroup(Gerber_RegEx_ExposureMode,1)
                Case "POS"
                  \Header\ExposureMode=#Gerber_EM_Positiv
                Case "NEG"
                  \Header\ExposureMode=#Gerber_EM_Negativ
                  AddError("Deprecated IPNEG-command used. Setting ExposurMode to negative but result may be incorrect!")
              EndSelect
              \Header\Header("ExposureMode")=#Gerber_Header_OK
            Else
              AddError("Exposuremode line error: "+STemp$)
              \Header\Header("ExposureMode")=#Gerber_Header_Error
            EndIf
            ;}
          ElseIf MatchRegularExpression(Gerber_RegEx_Macro,STemp$)
            ;{ AM -> Create Aperture-Macro
            If ExamineRegularExpression(Gerber_RegEx_Macro,STemp$) And NextRegularExpressionMatch(Gerber_RegEx_Macro)
              MacroName$=RegularExpressionGroup(Gerber_RegEx_Macro,1)
              ATemp$=Trim(RegularExpressionGroup(Gerber_RegEx_Macro,2),"*")
              ACount=CountString(ATemp$,"*")+1
              For ACounter=1 To ACount
                Temp$=StringField(ATemp$,ACounter,"*")
                TCount=CountString(Temp$,",")+1
                If Left(Temp$,1)="0";Sort out comments and add them to the comment list
                  AddElement(\Header\Comments())
                  \Header\Comments()=Right(Temp$,Len(Temp$)-1)
                Else
                  AddElement(\Data\ApertureMacro(MacroName$)\Primitives())
                  \Data\ApertureMacro(MacroName$)\Primitives()\Type=Val(StringField(Temp$,1,","))
                  Select \Data\ApertureMacro(MacroName$)\Primitives()\Type
                    Case #Gerber_MT_Circle
                      \Data\ApertureMacro(MacroName$)\Primitives()\Exposure=Val(StringField(Temp$,2,","))
                      \Data\ApertureMacro(MacroName$)\Primitives()\Diameter=ValD(StringField(Temp$,3,","))*\Header\Scaling
                      \Data\ApertureMacro(MacroName$)\Primitives()\CenterX=ValD(StringField(Temp$,4,","))*\Header\Scaling
                      \Data\ApertureMacro(MacroName$)\Primitives()\CenterY=ValD(StringField(Temp$,5,","))*\Header\Scaling
                      If TCount>5
                        \Data\ApertureMacro(MacroName$)\Primitives()\Rotation=ValD(StringField(Temp$,6,","))*\Header\Scaling
                        \Data\ApertureMacro(MacroName$)\Primitives()\Radian=Radian(\Data\ApertureMacro(MacroName$)\Primitives()\Rotation)
                      EndIf
                    Case #Gerber_MT_Outline
                      \Data\ApertureMacro(MacroName$)\Primitives()\Exposure=Val(StringField(Temp$,2,","))
                      \Data\ApertureMacro(MacroName$)\Primitives()\StartX=ValD(StringField(Temp$,4,","))*\Header\Scaling
                      \Data\ApertureMacro(MacroName$)\Primitives()\StartY=ValD(StringField(Temp$,5,","))*\Header\Scaling
                      \Data\ApertureMacro(MacroName$)\Primitives()\VertexCount=Val(StringField(Temp$,3,","))
                      For TCounter=1 To \Data\ApertureMacro(MacroName$)\Primitives()\VertexCount
                        AddElement(\Data\ApertureMacro(MacroName$)\Primitives()\Vertices())
                        \Data\ApertureMacro(MacroName$)\Primitives()\Vertices()\X=ValD(StringField(Temp$,4+2*TCounter,","))*\Header\Scaling
                        \Data\ApertureMacro(MacroName$)\Primitives()\Vertices()\Y=ValD(StringField(Temp$,5+2*TCounter,","))*\Header\Scaling
                      Next
                      If TCount>5+2*\Data\ApertureMacro(MacroName$)\Primitives()\VertexCount
                        \Data\ApertureMacro(MacroName$)\Primitives()\Rotation=ValD(StringField(Temp$,6+2*ListSize(\Data\ApertureMacro(MacroName$)\Primitives()\Vertices()),","))*\Header\Scaling
                        \Data\ApertureMacro(MacroName$)\Primitives()\Radian=Radian(\Data\ApertureMacro(MacroName$)\Primitives()\Rotation)
                      EndIf
                    Case #Gerber_MT_Polygon
                      \Data\ApertureMacro(MacroName$)\Primitives()\Exposure=Val(StringField(Temp$,2,","))
                      \Data\ApertureMacro(MacroName$)\Primitives()\VertexCount=Val(StringField(Temp$,3,","))
                      \Data\ApertureMacro(MacroName$)\Primitives()\CenterX=ValD(StringField(Temp$,4,","))*\Header\Scaling
                      \Data\ApertureMacro(MacroName$)\Primitives()\CenterY=ValD(StringField(Temp$,5,","))*\Header\Scaling
                      \Data\ApertureMacro(MacroName$)\Primitives()\Diameter=ValD(StringField(Temp$,6,","))*\Header\Scaling
                      \Data\ApertureMacro(MacroName$)\Primitives()\Rotation=ValD(StringField(Temp$,7,","))*\Header\Scaling
                      \Data\ApertureMacro(MacroName$)\Primitives()\Radian=Radian(\Data\ApertureMacro(MacroName$)\Primitives()\Rotation)
                    Case #Gerber_MT_Thermal
                      \Data\ApertureMacro(MacroName$)\Primitives()\CenterX=ValD(StringField(Temp$,2,","))*\Header\Scaling
                      \Data\ApertureMacro(MacroName$)\Primitives()\CenterY=ValD(StringField(Temp$,3,","))*\Header\Scaling
                      \Data\ApertureMacro(MacroName$)\Primitives()\OuterDiameter=ValD(StringField(Temp$,4,","))*\Header\Scaling
                      \Data\ApertureMacro(MacroName$)\Primitives()\InnerDiameter=ValD(StringField(Temp$,5,","))*\Header\Scaling
                      \Data\ApertureMacro(MacroName$)\Primitives()\Gap=ValD(StringField(Temp$,6,","))*\Header\Scaling
                      \Data\ApertureMacro(MacroName$)\Primitives()\Rotation=ValD(StringField(Temp$,7,","))*\Header\Scaling
                      \Data\ApertureMacro(MacroName$)\Primitives()\Radian=Radian(\Data\ApertureMacro(MacroName$)\Primitives()\Rotation)
                    Case #Gerber_MT_VectorLine,#Gerber_MT_LineVector
                      \Data\ApertureMacro(MacroName$)\Primitives()\Exposure=Val(StringField(Temp$,2,","))
                      \Data\ApertureMacro(MacroName$)\Primitives()\Width=ValD(StringField(Temp$,3,","))*\Header\Scaling
                      \Data\ApertureMacro(MacroName$)\Primitives()\StartX=ValD(StringField(Temp$,4,","))*\Header\Scaling
                      \Data\ApertureMacro(MacroName$)\Primitives()\StartY=ValD(StringField(Temp$,5,","))*\Header\Scaling
                      \Data\ApertureMacro(MacroName$)\Primitives()\EndX=ValD(StringField(Temp$,6,","))*\Header\Scaling
                      \Data\ApertureMacro(MacroName$)\Primitives()\EndY=ValD(StringField(Temp$,7,","))*\Header\Scaling
                      \Data\ApertureMacro(MacroName$)\Primitives()\Rotation=ValD(StringField(Temp$,8,","))*\Header\Scaling
                      \Data\ApertureMacro(MacroName$)\Primitives()\Radian=Radian(\Data\ApertureMacro(MacroName$)\Primitives()\Rotation)
                    Case #Gerber_MT_CenterLine,#Gerber_MT_LowerLeftLine
                      \Data\ApertureMacro(MacroName$)\Primitives()\Exposure=Val(StringField(Temp$,2,","))
                      \Data\ApertureMacro(MacroName$)\Primitives()\Width=ValD(StringField(Temp$,3,","))*\Header\Scaling
                      \Data\ApertureMacro(MacroName$)\Primitives()\Height=ValD(StringField(Temp$,4,","))*\Header\Scaling
                      \Data\ApertureMacro(MacroName$)\Primitives()\CenterX=ValD(StringField(Temp$,5,","))*\Header\Scaling
                      \Data\ApertureMacro(MacroName$)\Primitives()\CenterY=ValD(StringField(Temp$,6,","))*\Header\Scaling
                      \Data\ApertureMacro(MacroName$)\Primitives()\Rotation=ValD(StringField(Temp$,7,","))*\Header\Scaling
                      \Data\ApertureMacro(MacroName$)\Primitives()\Radian=Radian(\Data\ApertureMacro(MacroName$)\Primitives()\Rotation)
                    Case #Gerber_MT_Moire
                      \Data\ApertureMacro(MacroName$)\Primitives()\CenterX=ValD(StringField(Temp$,2,","))*\Header\Scaling
                      \Data\ApertureMacro(MacroName$)\Primitives()\CenterY=ValD(StringField(Temp$,3,","))*\Header\Scaling
                      \Data\ApertureMacro(MacroName$)\Primitives()\Diameter=Val(StringField(Temp$,4,","))
                      \Data\ApertureMacro(MacroName$)\Primitives()\RingThickness=ValD(StringField(Temp$,5,","))*\Header\Scaling
                      \Data\ApertureMacro(MacroName$)\Primitives()\Gap=ValD(StringField(Temp$,6,","))*\Header\Scaling
                      \Data\ApertureMacro(MacroName$)\Primitives()\VertexCount=Val(StringField(Temp$,7,","))
                      \Data\ApertureMacro(MacroName$)\Primitives()\CrosshairThickness=ValD(StringField(Temp$,8,","))*\Header\Scaling
                      \Data\ApertureMacro(MacroName$)\Primitives()\CrosshairLength=ValD(StringField(Temp$,9,","))*\Header\Scaling
                      \Data\ApertureMacro(MacroName$)\Primitives()\Rotation=ValD(StringField(Temp$,10,","))*\Header\Scaling
                      \Data\ApertureMacro(MacroName$)\Primitives()\Radian=Radian(\Data\ApertureMacro(MacroName$)\Primitives()\Rotation)
                  EndSelect
                EndIf
              Next
            Else
              AddError("Aperture-macro error: "+STemp$)
            EndIf
            ;}
          ElseIf MatchRegularExpression(Gerber_RegEx_Apertures,STemp$)
            ;{ AD -> Apertures Definition
            If ExamineRegularExpression(Gerber_RegEx_Apertures,STemp$)
              While NextRegularExpressionMatch(Gerber_RegEx_Apertures)
                ATemp$=RegularExpressionGroup(Gerber_RegEx_Apertures,1)
                Select RegularExpressionGroup(Gerber_RegEx_Apertures,2)
                  Case "C"
                    \Data\Apertures(ATemp$)\Type=#Gerber_AT_Circle
                    Temp$=RegularExpressionGroup(Gerber_RegEx_Apertures,3)
                    \Data\Apertures(ATemp$)\Diameter=ValD(StringField(Temp$,1,"X"))*\Header\Scaling
                    Select CountString(Temp$,"X")
                      Case 1
                        \Data\Apertures(ATemp$)\InnerX=ValD(StringField(Temp$,2,"X"))*\Header\Scaling
                      Case 2
                        \Data\Apertures(ATemp$)\InnerX=ValD(StringField(Temp$,2,"X"))*\Header\Scaling
                        \Data\Apertures(ATemp$)\InnerY=ValD(StringField(Temp$,3,"X"))*\Header\Scaling
                    EndSelect
                  Case "R"
                    \Data\Apertures(ATemp$)\Type=#Gerber_AT_Rectangle
                    Temp$=RegularExpressionGroup(Gerber_RegEx_Apertures,3)
                    \Data\Apertures(ATemp$)\X=ValD(StringField(Temp$,1,"X"))*\Header\Scaling
                    \Data\Apertures(ATemp$)\Y=ValD(StringField(Temp$,2,"X"))*\Header\Scaling
                    Select CountString(Temp$,"X")
                      Case 2
                        \Data\Apertures(ATemp$)\Diameter=ValD(StringField(Temp$,3,"X"))*\Header\Scaling
                      Case 3
                        \Data\Apertures(ATemp$)\InnerX=ValD(StringField(Temp$,3,"X"))*\Header\Scaling
                        \Data\Apertures(ATemp$)\InnerY=ValD(StringField(Temp$,4,"X"))*\Header\Scaling
                    EndSelect
                  Case "O"
                    \Data\Apertures(ATemp$)\Type=#Gerber_AT_Obround
                    Temp$=RegularExpressionGroup(Gerber_RegEx_Apertures,3)
                    \Data\Apertures(ATemp$)\X=ValD(StringField(Temp$,1,"X"))*\Header\Scaling
                    \Data\Apertures(ATemp$)\Y=ValD(StringField(Temp$,2,"X"))*\Header\Scaling
                    If CountString(Temp$,"X")=2
                      \Data\Apertures(Temp$)\InnerX=ValD(StringField(Temp$,3,"X"))*\Header\Scaling
                    EndIf
                  Case "P"
                    \Data\Apertures(ATemp$)\Type=#Gerber_AT_Polygon
                    Temp$=RegularExpressionGroup(Gerber_RegEx_Apertures,3)
                    \Data\Apertures(ATemp$)\X=ValD(StringField(Temp$,1,"X"))*\Header\Scaling
                    \Data\Apertures(ATemp$)\Vertex=Val(StringField(Temp$,2,"X"))
                    Select CountString(Temp$,"X")
                      Case 2
                        \Data\Apertures(ATemp$)\Rotation=ValD(StringField(Temp$,3,"X"))*\Header\Scaling
                        \Data\Apertures(ATemp$)\Radian=Radian(\Data\Apertures(ATemp$)\Rotation)
                      Case 3
                        \Data\Apertures(ATemp$)\Rotation=ValD(StringField(Temp$,3,"X"))*\Header\Scaling
                        \Data\Apertures(ATemp$)\Radian=Radian(\Data\Apertures(ATemp$)\Rotation)
                        \Data\Apertures(ATemp$)\InnerX=ValD(StringField(Temp$,4,"X"))*\Header\Scaling
                    EndSelect
                  Default
                    \Data\Apertures(ATemp$)\Type=#Gerber_AT_ApertureMacro
                    \Data\Apertures(ATemp$)\ApertureMacro=RegularExpressionGroup(Gerber_RegEx_Apertures,2)
                    If Not FindMapElement(\Data\ApertureMacro(),\Data\Apertures(ATemp$)\ApertureMacro)
                      Debug "Missing Aperture macro: "+\Data\Apertures(ATemp$)\ApertureMacro
                    EndIf
                EndSelect
              Wend
            Else
              AddError("Apertur error: "+STemp$)
            EndIf
            ;}
          ElseIf MatchRegularExpression(Gerber_RegEx_Attributes,STemp$)
            ;{ TA -> Aperture Attributes
            If ExamineRegularExpression(Gerber_RegEx_Attributes,STemp$) And NextRegularExpressionMatch(Gerber_RegEx_Attributes)
              \Header\Attributes(RegularExpressionGroup(Gerber_RegEx_Attributes,1))=RegularExpressionGroup(Gerber_RegEx_Attributes,2)
            Else
              AddError("Attribute error: "+STemp$)
            EndIf
            ;}
          ElseIf MatchRegularExpression(Gerber_Command_G04,STemp$)
            ;{ G04 -> Comment
            AddElement(\Header\Comments())
            \Header\Comments()=Mid(STemp$,4)
            ;}
          ElseIf MatchRegularExpression(Gerber_RegEx_LP,STemp$)
            ;{ LP -> Load Polarity (Dark/Clear)
            ReDim Path(ArraySize(Path())+1)
            Path(ArraySize(Path()))=Left(STemp$,3)
            ;}
          ElseIf MatchRegularExpression(Gerber_RegEx_ApertureBlock,STemp$)
            ;{ AB -> Aperture Block (Start or End)
            If ExamineRegularExpression(Gerber_RegEx_ApertureBlock,STemp$) And NextRegularExpressionMatch(Gerber_RegEx_ApertureBlock)
              Temp$=RegularExpressionGroup(Gerber_RegEx_ApertureBlock,1)
              Temp$=Right(Temp$,Len(Temp$)-1)
              If Temp$=""
                If ListSize(BlockStack())>0
                  DeleteElement(BlockStack())
                  LastElement(BlockStack())
                Else
                  AddError("Aperture Block End without start (AB)!")
                EndIf
              Else
                AddElement(BlockStack())
                BlockStack()=Temp$
                \Data\Apertures(Temp$)\Type=#Gerber_AT_ApertureBlock
              EndIf
            EndIf
            ;}
          ElseIf STemp$="G70"
            ;{ G70 -> Set unit to inch (deprecated in 2012)
            \Unit=#Gerber_Unit_Inch
            ;}  
          ElseIf STemp$="G71"
            ;{ G71 -> Set unit to mm (deprecated in 2012)
            \Unit=#Gerber_Unit_MM
            ;}  
          ElseIf STemp$="G90"
            ;{ G90 -> Set Coordinate format to absolute notation (deprecated in 2012)
            \Header\CoordinateMode=#Gerber_Coord_Absolute
            ;}  
          ElseIf STemp$="G91"
            ;{ G91 -> Set Coordinate format to incemental notation (deprecated in 2012)
            \Header\CoordinateMode=#Gerber_Coord_Incremental
            ;}  
          ElseIf MatchRegularExpression(Gerber_RegEx_MI,STemp$)
            ;{ MI -> Mirroring (deprecated in December 2012, just check if strange value is set -> error message and ignore)
            Select STemp$
              Case "MIA0*","MIA0B0*","MIB0*"
                ;Ok, ignore it.
              Default
                AddError("Deprecated MI with non-standard values found! Will be ignored and may affect mirroring of the PCB: "+STemp$)
            EndSelect
            ;}
          ElseIf MatchRegularExpression(Gerber_RegEx_SF,STemp$)
            ;{ SF -> Scale factor (deprecated in December 2012, just check if strange value is set -> error message and ignore)
            If ExamineRegularExpression(Gerber_RegEx_SF,STemp$) And NextRegularExpressionMatch(Gerber_RegEx_SF)
              ACount=0
              For ACounter=1 To CountRegularExpressionGroups(Gerber_RegEx_SF)
                Temp$=RegularExpressionGroup(Gerber_RegEx_SF,ACounter)
                Temp$=Right(Temp$,Len(Temp$)-1)
                If Left(Temp$,1)=".":Temp$="0"+Temp$:EndIf
                If ValF(Temp$)<>1.0
                  ACount=1
                  Break
                EndIf
              Next
              If ACount
                AddError("Deprecated SF with non-standard values found! Will be ignored and may affect scaling of the PCB: "+STemp$)
              EndIf
            Else
              AddError("Faulty SF-command: "+STemp$)
            EndIf
            ;}
          ElseIf MatchRegularExpression(Gerber_RegEx_IR,STemp$)
            ;{ IR -> Image rotation (deprecated in December 2012, completely ignored if not 0°, otherwise no effect)
            If STemp$<>"IR0*"
              AddError("Deprecated image rotation-command will be ignored: "+STemp$)
            EndIf
            ;}
          ElseIf MatchRegularExpression(Gerber_RegEx_AS,STemp$)
            ;{ AS -> Axis selection (deprecated in December 2012, ignored if not A=X/B=Y, otherwise no effect)
            If STemp$<>"ASAXBY*"
              AddError("Deprecated axis selection-command will be ignored: "+STemp$)
            EndIf
            ;}
          ElseIf MatchRegularExpression(Gerber_RegEx_SR,STemp$)
            ;{ SR -> Step and repeat (todo)
            If ExamineRegularExpression(Gerber_RegEx_SR,STemp$) And NextRegularExpressionMatch(Gerber_RegEx_SR)
              If Val(RegularExpressionGroup(Gerber_RegEx_SR,1))<>1 Or Val(RegularExpressionGroup(Gerber_RegEx_SR,2))<>1
                AddError("Step and repeat command which can't be processed (because it's not programmed yet)!")
              EndIf
            Else
              AddError("Stepmode error: "+STemp$)
            EndIf
            ;}
          ElseIf MatchRegularExpression(Gerber_RegEx_OF,STemp$)
            ;{ OF -> Offset factor (deprecated in December 2012, completely ignored)
            AddError("Deprecated offset-command will be ignored: "+STemp$)
            ;}
          ElseIf MatchRegularExpression(Gerber_RegEx_LS,STemp$)
            ;{ LS -> Load scaling
            ReDim Path(ArraySize(Path())+1)
            Path(ArraySize(Path()))=Left(STemp$,Len(STemp$)-1)
            ;}
          Else
            ;{ Generate  renderpath or add to it...or unknown command
            Select Left(STemp$,1)
              Case "X","Y","G","D","I","J"
                SplitL(Trim(STemp$,"*"),Path())
              Default
                AddError("Unknown command: "+Left(STemp$,25))
            EndSelect
            ;}
          EndIf
        EndIf
        If ElapsedMilliseconds()>CallbackTick And *Callback
          CallFunctionFast(*Callback,PCounter,PCount+1+ArraySize(Path()));Calls the callback function (parameters: current position, total lines)
          CallbackTick=ElapsedMilliseconds()+CallbackTimeout
        EndIf
      Next
      ;}
      
      ;{ Add omitted zeroes if "omit trailing zeroes" is active, otherwise the comma would be put into the wrong place. Deprecated mode, in for compatibility
      If \Header\OmittedZeros=#Gerber_OZ_Trailing
        Max=ArraySize(Path())
        For Pos=0 To Max
          ATemp$=Path(Pos)
          sum=ExtractRegularExpression(Gerber_RegEx_Omitter,ATemp$,Out$())
          If sum>0
            For count=0 To ArraySize(Out$())
              If FindString(Out$(count),"-")
                ATemp$=ReplaceString(ATemp$,Out$(count),LSet(Out$(count),2+\Header\X+\Header\Digits,"0"))
              Else
                ATemp$=ReplaceString(ATemp$,Out$(count),LSet(Out$(count),1+\Header\X+\Header\Digits,"0"))
              EndIf
            Next
          EndIf
          Path(Pos)=ATemp$
        Next
      EndIf
      ;}
      
      ; !!!!!!!!TESTEN!!!!!!!!
      ;{ Path preprocessing (convert from incremental values to absolute values (if needed))
      If *Gerber\Header\CoordinateMode=#Gerber_Coord_Incremental
        Max=ArraySize(Path())
        Position\X=0:Position\Y=0
        For Pos=0 To Max
          If ExamineRegularExpression(Gerber_RegEx_PreprocessX,Path(Pos)) And NextRegularExpressionMatch(Gerber_RegEx_PreprocessX)
            Position\X+ValD(RegularExpressionGroup(Gerber_RegEx_PreprocessX,1))
            Path(Pos)=ReplaceString(Path(Pos),RegularExpressionGroup(Gerber_RegEx_PreprocessX,1),Str(Position\X))
          EndIf
          If ExamineRegularExpression(Gerber_RegEx_PreprocessY,Path(Pos)) And NextRegularExpressionMatch(Gerber_RegEx_PreprocessY)
            Position\Y+ValD(RegularExpressionGroup(Gerber_RegEx_PreprocessY,1))
            Path(Pos)=ReplaceString(Path(Pos),RegularExpressionGroup(Gerber_RegEx_PreprocessY,1),Str(Position\Y))
          EndIf
          ;           Select Path(Pos)
          ;             Case "M00","M01","M02";M01 maybe without effect (should maybe not stop the processing!)
          ;               ReDim Path(Pos)
          ;               Break
          ;           EndSelect
          If ElapsedMilliseconds()>CallbackTick And *Callback
            CallFunctionFast(*Callback,PCount+Pos,PCount+ArraySize(Path()));Calls the callback function (parameters: current position, total lines)
            CallbackTick=ElapsedMilliseconds()+CallbackTimeout
          EndIf
        Next
      EndIf
      ;}    
      
      ;{ Some error messages (may be enhanced in the future)
      If \Header\Header("Header")=#Gerber_Header_Missing
        ;AddError("Header missing!")
      EndIf
      If \Header\Header("Unit")=#Gerber_Header_Missing
        ;AddError("Scaling missing, assuming mm!")
      EndIf
      ;}
      
      ;{ Create cache and calculate size
      Image=CreateImage(#PB_Any,1,1)
      StartVectorDrawing(ImageVectorOutput(Image))
      PlotGerber(*Gerber,Path(),*Gerber\Cache\Skeleton())
      StopVectorDrawing()
      StartVectorDrawing(ImageVectorOutput(Image))
      \FillMode=#Gerber_FillMode_Fill
      PlotGerber(*Gerber,Path(),*Gerber\Cache\Filled())
      StopVectorDrawing()
      FreeImage(Image)
      ;}
      
      ;{ Calculate board size in mm
      \BoardSize\X=(\Max\X-\Min\X)/\Header\Scaling
      \BoardSize\Y=(\Max\Y-\Min\Y)/\Header\Scaling
      If \Unit=#Gerber_Unit_Inch;Board size is always stored as mme
        \BoardSize\X=\BoardSize\X*25.4
        \BoardSize\Y=\BoardSize\Y*25.4
      EndIf
      ;}
      
      ;{ Cleanup
      FreeMap(*Gerber\Data\Apertures())
      ForEach *Gerber\Data\ApertureMacro()
        ForEach *Gerber\Data\ApertureMacro()\Primitives()
          FreeList(*Gerber\Data\ApertureMacro()\Primitives()\Vertices())
        Next
        FreeList(*Gerber\Data\ApertureMacro()\Primitives())
      Next
      FreeMap(*Gerber\Data\ApertureMacro())
      ;}
      
      \Log\LoadingTime=ElapsedMilliseconds()-Tick
      ;Debug "Ladezeit ("+\FileName$+"): "+Str(\Log\LoadingTime)+"ms"
      If *Callback
        CallFunctionFast(*Callback,1,1)
      EndIf
    EndWith
    
    ProcedureReturn *Gerber
  EndProcedure
  
  Procedure CreateGerberDataFromFile(File$)
    Protected File,Input$,*Gerber.Gerber,*Mem,Size=FileSize(File$)
    If Size>0
      File=ReadFile(#PB_Any,File$,#PB_Ascii|#PB_File_SharedRead)
      If File
        If ReadQuad(File)=#Gerber_MagicNumber
          FileSeek(File,0,#PB_Absolute)
          *Mem=AllocateMemory(Size,#PB_Memory_NoClear)
          ReadData(File,*Mem,Size)
          CloseFile(File)
          *Gerber=LoadPureGerber(*Mem)
          FreeMemory(*Mem)
          If *Gerber
            *Gerber\FileName$=File$
            ProcedureReturn *Gerber
          EndIf
        Else
          FileSeek(File,0)
          Input$=ReadString(File,#PB_File_IgnoreEOL)
          CloseFile(File)
          If Input$<>""
            *Gerber=CreateGerberDataFromString(Input$)
            *Gerber\FileName$=File$
            CompilerIf #PB_Compiler_Debugger;debug initialization errors
              If ListSize(*Gerber\Log\Errors())>0
                Debug "File: "+File$+" -> "+Str(ListSize(*Gerber\Log\Errors()))+" error(s)"
                ForEach *Gerber\Log\Errors()
                  Debug *Gerber\Log\Errors()
                Next
              EndIf
            CompilerEndIf
            ProcedureReturn *Gerber
          EndIf
        EndIf
      EndIf
    EndIf
    ProcedureReturn 0
  EndProcedure
  
  Procedure CatchGerber(*Memory,Size=0)
    If Size<1
      ProcedureReturn CreateGerberDataFromString(PeekS(*Memory,MemorySize(*Memory)))
    Else
      ProcedureReturn CreateGerberDataFromString(PeekS(*Memory,Size))
    EndIf
  EndProcedure
  ;}
  
EndModule

; IDE Options = PureBasic 6.10 beta 2 (Windows - x64)
; CursorPosition = 1
; Folding = BAABAAAAAAAAAAAAAAEw-AAAAAAAAAAAg
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
; EnableCompileCount = 0
; EnableBuildCount = 0