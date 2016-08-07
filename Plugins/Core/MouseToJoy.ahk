/*
Remaps mouse DELTA information (is unconcerned with cursor position, just cares about mouse movement) to joystick output.
Features Absolute and Relative modes
*/
class MouseToJoy extends _Plugin {
	Type := "Remapper (Mouse Axis To Joystick Axis)"
	Description := "Converts mouse input delta information into two joystick axes"
	AbsoluteThresholdFactor := {x: 10, y: 10}
	AbsoluteTimeout := {x: 10, y: 10}
	RelativeTimeout := {x: 10, y: 10}
	RelativeScaleFactor := {x: 1, y: 1}
	Mode := 2	; 1 = Absolute, 2 = Relative
	SeenMice := {}
	
	Init(){
		title_row := 25
		x_row := 45
		y_row := x_row + 25
		;Gui, Add, Text, y+5 , Absolute Mode threshold
		Gui, Add, Text, % "xm y" x_row+3, X AXIS
		Gui, Add, Text, % "xm y" y_row+3, Y AXIS
		
		; Absolute mode
		Gui, Add, GroupBox, % "x50 ym w125 Section h" y_row+25, % "Absolute Mode"
		Gui, Add, Text, % "xs+10 y" title_row, Threshold
		this.AddControl("AbsoluteThresholdX", this.ThresholdChanged.Bind(this, "X"), "Edit", "x70 w30 y" x_row, 10)
		;~ Gui, Add, Button, % "x+5 yp hwndhwnd", Calibrate
		;~ fn := this.Calibrate.Bind(this, "X")
		;~ GuiControl +g, % hwnd, % fn
		Gui, Add, Text, % "x120 w40 center y" title_row, Timeout
		this.AddControl("AbsoluteTimeout", this.TimeoutChanged.Bind(this, "X"), "Edit", "x120 w40 y" x_row + 10, 50)
		
		this.AddControl("AbsoluteThresholdY", this.ThresholdChanged.Bind(this, "Y"), "Edit", "x70 w30 y" y_row, 10)
		;~ Gui, Add, Button, % "x+5 yp hwndhwnd", Calibrate
		;~ fn := this.Calibrate.Bind(this, "Y")
		;~ GuiControl +g, % hwnd, % fn
		;this.AddControl("AbsoluteTimeoutY", this.TimeoutChanged.Bind(this, "Y"), "Edit", "x120 w40 y" y_row, 50)
		
		; Relative Mode
		Gui, Add, GroupBox, % "x185 ym w115 Section h" y_row+25, % "Relative Mode"
		;Gui, Add, Text, % "x200 w40 center y" title_row, Timeout
		;this.AddControl("RelativeTimeoutX", this.TimeoutChanged.Bind(this, 2, "X"), "Edit", "x200 w40 y" x_row, 10)
		;this.AddControl("RelativeTimeoutY", this.TimeoutChanged.Bind(this, 2, "Y"), "Edit", "x200 w40 y" y_row, 10)
		Gui, Add, Text, % "xs+5 center y" title_row, Scale Factor
		this.AddControl("RelativeScaleFactorX", this.ScaleFactorChanged.Bind(this, "X"), "Edit", "xs+5 w45 y" x_row, 1)
		this.AddControl("RelativeScaleFactorY", this.ScaleFactorChanged.Bind(this, "Y"), "Edit", "xs+5 w45 y" y_row, 1)
		
		; Tweaks
		Gui, Add, Text, % "x+25 w20 center y" title_row, Invert
		this.AddControl("InvertX", 0, "CheckBox", "xp+5 y" x_row+3, "", 0)
		this.AddControl("InvertY", 0, "CheckBox", "xp y" y_row+3, "", 0)
		
		; Mouse Selection
		Gui, Add, GroupBox, % "x305 ym w105 Section h" y_row+25, % "Multi-Mouse"
		Gui, Add, Text, % "xs+5 Center w90 y" title_row - 5, Mouse Picker
		Gui, Add, DDL, hwndhSelectMouse xs+5 yp+15 w90, Any||
		fn := this.MouseSelectChanged.Bind(this)
		this.MouseSelectChangedFn := fn
		GuiControl, +g, % hSelectMouse, % fn
		this.hSelectMouse := hSelectMouse
		
		Gui, Add, Text, % "xs+5 Center w90 y+2", Current Mouse
		this.AddControl("MouseID", 0, "Edit", "xs+5 y+2 w90", "")
		
		; Outputs
		this.AddOutputAxis("OutputAxisX", 0, "x420 w125 y" x_row)
		this.AddOutputAxis("OutputAxisY", 0, "x420 w125 y" y_row)
		Gui, Add, Slider, % "hwndhwnd x550 y" x_row
		this.hSliderX := hwnd
		Gui, Add, Slider, % "hwndhwnd x550 y" y_row
		this.hSliderY := hwnd
		
		;this.AddControl("AbsoluteRadio", 0, "Radio", "x150 ym",, 1)
		;this.AddControl("RelativeRadio", 0, "Radio", "x270 ym",, 0)
		this.AddControl("ModeSelect", this.ModeSelect.Bind(this), "DDL", "x575 w100 ym AltSubmit", "Mode: Absolute||Mode: Relative")
		this.AddInputDelta("MouseDelta", this.MouseEvent.Bind(this))
		
		;this.MouseTimeoutFn := this.OnMouseTimeout.Bind(this)
		;this.MouseTimeoutFn := this.MouseEvent.Bind(this, {x: 0, y: 0})
	}
	
	OnActive(){
		this.InputDeltas.MouseDelta.Register()
	}
	
	OnInactive(){
		this.InputDeltas.MouseDelta.UnRegister()
	}
	
	; Plugin was deleted - stop watching mouse
	OnDelete(){
		;this.MouseDelta.UnRegister()
		;this.MouseDelta := ""
	}
	
	MouseSelectChanged(){
		GuiControlGet, val,, % this.hSelectMouse
		if (val == "Any" || val == 0){
			val := ""
		}
		this.GuiControls.MouseID.value := val
		GuiControl, , % this.GuiControls.MouseID.hwnd, % val
	}
	
	;~ Calibrate(axis){
		;~ static state := 0
		;~ if (axis = "x"){
			
		;~ } else {
			
		;~ }
	;~ }
	
	;MouseEvent(x := 0, y := 0){
	MouseEvent(value){
		try {
			x := value.x, y := value.y, MouseID := value.MouseID
		} catch {
			; M2J sometimes seems to crash eg when switching from a profile with M2J to a profile without
			; This seems to fix it, but this should probably be properly investigated.
			return
		}
		m_id := this.GuiControls.MouseID.value
		if (m_id && m_id != value.MouseID)
			return
		; The "Range" for a given axis is -50 to +50
		static curr_x := 0, curr_y := 0
		
		if (this.Mode = 1){
			curr_x := x * this.AbsoluteThresholdFactor.X
			curr_y := y * this.AbsoluteThresholdFactor.Y
		} else {
			if (this.GuiControls.InvertX.value)
				x *= -1
			curr_x += ( x * this.RelativeScaleFactor.X )
			if (curr_x > 50)
				curr_x := 50
			else if (curr_x < -50)
				curr_x := -50
			
			if (this.GuiControls.InvertY.value)
				y *= -1
			curr_y += ( y * this.RelativeScaleFactor.Y )
			if (curr_y > 50)
				curr_y := 50
			else if (curr_y < -50)
				curr_y := -50
		}
		;OutputDebug, % "UCR| x: " curr_x " (" UCR.Libraries.StickOps.InternalToAHK(curr_x) "), y: " curr_y
		if (this.OutputAxes.OutputAxisX.value.DeviceID && this.OutputAxes.OutputAxisX.value.Axis){
			this.OutputAxes.OutputAxisX.SetState(UCR.Libraries.StickOps.InternalToVjoy(curr_x))
			GuiControl, , % this.hSliderX, % UCR.Libraries.StickOps.InternalToAHK(curr_x)
		}
		if (this.OutputAxes.OutputAxisY.value.DeviceID && this.OutputAxes.OutputAxisY.value.Axis){
			this.OutputAxes.OutputAxisY.SetState(UCR.Libraries.StickOps.InternalToVjoy(curr_y))
			GuiControl, , % this.hSliderY, % UCR.Libraries.StickOps.InternalToAHK(curr_y)
		}
		
		if (!ObjHasKey(this.SeenMice, MouseID)){
			this.SeenMice[MouseID] := 1
			GuiControl, , % this.hSelectMouse, % MouseID
		}
		
		if (this.Mode = 1 && (x != 0 || y != 0)){
			;fn := this.MouseTimeoutFn
			fn := this.MouseEvent.Bind(this, {x: 0, y: 0, MouseID: MouseID})
			SetTimer, % fn, % "-" this.GuiControls.AbsoluteTimeout.value
		}
	}
	
	OnMouseTimeout(){
		this.MouseEvent({x: 0, y: 0})
	}
	
	ModeSelect(value){
		this.Mode := value
	}
	
	; === Absolute Mode variable changed
	ThresholdChanged(axis, value){
		this.AbsoluteThresholdFactor[axis] := 100 / value
	}
	
	TimeoutChanged(axis, value){
		this.AbsoluteTimeout[axis] := value
		;this.MouseDelta.SetTimeOut(value)
	}
	
	; === Relative Mode variable changed
	ScaleFactorChanged(axis, value){
		this.RelativeScaleFactor[axis] := value
	}
}