/*
Remaps mouse DELTA information (is unconcerned with cursor position, just cares about mouse movement) to joystick output.
Features Absolute and Relative modes
*/
class MouseToJoy extends _UCR.Classes.Plugin {
	Type := "Remapper (Mouse Axis To Joystick Axis)"
	Description := "Converts mouse input delta information into two joystick axes"
	RelativeScaleFactor := {x: 10, y: 10}
	RelativeTimeout := {x: 10, y: 10}
	AbsoluteTimeout := {x: 10, y: 10}
	AbsoluteScaleFactor := {x: 1, y: 1}
	Mode := 2	; 1 = Relative, 2 = Absolute
	SeenMice := {}
	CurrX := 0
	CurrY := 0
	TimerX := 0
	TimerY := 0
	SelectedMouse := -1
	Init(){
		title_row := 25
		x_row := 55
		y_row := x_row + 25
		Gui, Add, Text, % "xm y" x_row+3, X AXIS
		Gui, Add, Text, % "xm y" y_row+3, Y AXIS
		
		; Relative mode
		Gui, Add, GroupBox, % "Center x50 ym w125 Section h" y_row+35, % "Relative"
		Gui, Add, Text, % "xs+5 y" title_row, Scale Factor
		this.AddControl("Edit", "RelativeScaleX", this.RelativeScaleChanged.Bind(this, "X"), "x70 w30 y" x_row, 10)
		;~ Gui, Add, Button, % "x+5 yp hwndhwnd", Calibrate
		;~ fn := this.Calibrate.Bind(this, "X")
		;~ GuiControl +g, % hwnd, % fn
		Gui, Add, Text, % "x120 w40 center y" title_row, Timeout
		this.AddControl("Edit", "RelativeTimeout", this.TimeoutChanged.Bind(this, "X"), "x120 w40 y" x_row - 10, 50)
		
		Gui, Add, Text, % "x120 w40 center y" y_row - 10, Threshold
		this.AddControl("Edit", "RelativeThreshold", this.TimeoutChanged.Bind(this, "X"), "x120 w40 y" y_row + 5, 2)
		
		this.AddControl("Edit", "RelativeScaleY", this.RelativeScaleChanged.Bind(this, "Y"), "x70 w30 y" y_row, 10)
		;~ Gui, Add, Button, % "x+5 yp hwndhwnd", Calibrate
		;~ fn := this.Calibrate.Bind(this, "Y")
		;~ GuiControl +g, % hwnd, % fn
		;this.AddControl("RelativeTimeoutY", this.TimeoutChanged.Bind(this, "Y"), "x120 w40 y" y_row, 50)
		
		; Absolute Mode
		Gui, Add, GroupBox, % "Center x185 ym w55 Section h" y_row+35, % "Absolute"
		;Gui, Add, Text, % "x200 w40 center y" title_row, Timeout
		;this.AddControl("AbsoluteTimeoutX", this.TimeoutChanged.Bind(this, 2, "X"), "x200 w40 y" x_row, 10)
		;this.AddControl("AbsoluteTimeoutY", this.TimeoutChanged.Bind(this, 2, "Y"), "x200 w40 y" y_row, 10)
		Gui, Add, Text, % "Center xs+15 center w30 y" title_row, Scale`nFactor
		this.AddControl("Edit", "AbsoluteScaleFactorX", this.AbsoluteScaleChanged.Bind(this, "X"), "xs+15 w30 y" x_row, 1)
		this.AddControl("Edit", "AbsoluteScaleFactorY", this.AbsoluteScaleChanged.Bind(this, "Y"), "xs+15 w30 y" y_row, 1)
		
		; Tweaks
		Gui, Add, GroupBox, % "Center x245 ym w55 Section h" y_row+35, % "Common"
		Gui, Add, Text, % "xs+15 w20 center y" title_row+10, Invert
		this.AddControl("CheckBox", "InvertX", 0, "xp+5 y" x_row+3, "", 0)
		this.AddControl("CheckBox", "InvertY", 0, "xp y" y_row+3, "", 0)
		
		; Mouse Selection
		Gui, Add, GroupBox, % "x305 ym w110 Section h" y_row+35, % "Input"
		this.AddControl("InputDelta", "MD1", this.MouseSelectChanged.Bind(this), this.MouseEvent.Bind(this), "x310 w100 y" x_row)
		
		; Outputs
		Gui, Add, GroupBox, % "x420 ym w140 Section h" y_row+35, % "Outputs"
		this.AddControl("OutputAxis", "OutputAxisX", 0, "x425 w125 y" x_row - 20)
		this.AddControl("OutputAxis", "OutputAxisY", 0, "x425 w125 y" y_row)
		
		this.AddControl("AxisPreview", "", 0, this.IOControls.OutputAxisX, "x560 y" x_row, 50)
		this.AddControl("AxisPreview", "", 0, this.IOControls.OutputAxisY, "x560 y" y_row, 50)
		
		this.AddControl("DDL", "ModeSelect", this.ModeSelect.Bind(this), "x575 w100 ym AltSubmit", "Mode: Relative||Mode: Absolute")
		
		;this.MouseTimeoutFn := this.OnMouseTimeout.Bind(this)
		;this.MouseTimeoutFn := this.MouseEvent.Bind(this, {x: 0, y: 0})
	}
	
	OnActive(){
		;this.InputDeltas.MouseDelta.Register()
	}
	
	OnInactive(){
		;this.InputDeltas.MouseDelta.UnRegister()
	}
	
	MouseSelectChanged(value){
		; Store the selected DeviceID, so we do not have to keep looking it up
		this.SelectedMouse := this.IOControls.MD1.GetBinding().DeviceID
	}
	
	;~ Calibrate(axis){
		;~ static state := 0
		;~ if (axis = "x"){
			
		;~ } else {
			
		;~ }
	;~ }
	
	;MouseEvent(x := 0, y := 0){
	MouseEvent(value){
		; The "Range" for a given axis is -50 to +50
		try {

			x := value.axes.x, y := value.axes.y, ax := Abs(x), ay := Abs(y), MouseID := value.MouseID, dox := (x != ""), doy := (y != "")
					
			if (this.GuiControls.InvertX.Get())
				x *= -1
			if (this.GuiControls.InvertY.Get())
				y *= -1
		} catch {
			; M2J sometimes seems to crash eg when switching from a profile with M2J to a profile without
			; This seems to fix it, but this should probably be properly investigated.
			return
		}
		
		
		if (!ObjHasKey(this.SeenMice, MouseID)){
			GuiControl, , % this.hSelectMouse, % MouseID
		
			this.SeenMice[MouseID] := 1
			this.IOControls.MD1.AddItem(MouseID, MouseID)			
		}
		
		if (this.SelectedMouse != -1 && this.SelectedMouse && this.SelectedMouse != value.MouseID)
			return
			
				
		if (this.Mode = 1){
			; Relative
			threshold := this.GuiControls.RelativeThreshold.Get()
			if (dox && ax && ax <= threshold)
				dox := 0
			if (doy && ay && ay <= threshold)
				doy := 0
			if (dox){
				this.CurrX := x * this.RelativeScaleFactor.X
				
			}
			if (doy){
				this.CurrY := y * this.RelativeScaleFactor.Y
			}
		} else {
			; Absolute
			if (dox){
				this.CurrX += ( x * this.AbsoluteScaleFactor.X )
				if (this.CurrX > 50)
					this.CurrX := 50
				else if (this.CurrX < -50)
					this.CurrX := -50
			}
			
			if (doy){
				this.CurrY += ( y * this.AbsoluteScaleFactor.Y )
				if (this.CurrY > 50)
					this.CurrY := 50
				else if (this.CurrY < -50)
					this.CurrY := -50
			}
		}
	
		if (dox){
			;OutputDebug, % "UCR| x: " this.CurrX " (" UCR.Libraries.StickOps.InternalToAHK(this.CurrX) "), y: " this.CurrY
			ox := this.IOControls.OutputAxisX.GetBinding()
			if (ox.DeviceID && ox.Binding[1]){
				cx := UCR.Libraries.StickOps.InternalToAHK(this.CurrX)
				this.IOControls.OutputAxisX.Set(cx)
			}
		}
		
		if (doy){
			oy := this.IOControls.OutputAxisY.GetBinding()
			if (oy.DeviceID && oy.Binding[1]){
				cy := UCR.Libraries.StickOps.InternalToAHK(this.CurrY)
				this.IOControls.OutputAxisY.Set(cy)
			}
		}
	

		
		; In Relative mode, emulate centering with a timeout
		if (this.Mode = 1){
			if (dox && x != 0){
				if (this.TimerX != 0){
					fn := this.TimerX
					SetTimer, % fn, Off
				}
				fn := this.MouseEvent.Bind(this, {axes: {x: 0}, MouseID: MouseID})
				this.TimerX := fn
				SetTimer, % fn, % "-" this.GuiControls.RelativeTimeout.Get()
			}
			if (doy && y != 0){
				if (this.TimerY != 0){
					fn := this.TimerY
					SetTimer, % fn, Off
				}
				fn := this.MouseEvent.Bind(this, {axes: {y: 0}, MouseID: MouseID})
				this.TimerY := fn
				SetTimer, % fn, % "-" this.GuiControls.RelativeTimeout.Get()
			}
		}
	}
	
	OnMouseTimeout(){
		this.MouseEvent({x: 0, y: 0})
	}
	
	ModeSelect(value){
		this.Mode := value
	}
	
	; === Relative Mode variable changed
	RelativeScaleChanged(axis, value){
		;this.RelativeScaleFactor[axis] := 100 / value
		this.RelativeScaleFactor[axis] := value
	}
	
	TimeoutChanged(axis, value){
		this.RelativeTimeout[axis] := value
		;this.MouseDelta.SetTimeOut(value)
	}
	
	; === Absolute Mode variable changed
	AbsoluteScaleChanged(axis, value){
		this.AbsoluteScaleFactor[axis] := value
	}
}