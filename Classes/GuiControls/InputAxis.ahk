﻿; ======================================================================== INPUT AXIS ===============================================================
class InputAxis extends _UCR.Classes.GuiControls.IOControl {
	static _ControlType := "InputAxis"
	static _IOClassNames := ["AHK_JoyAxis_Input"]
	static _Text := "Input"
	
	__Delete(){
		OutputDebug % "UCR| " this._Text "Axis " this.name " in plugin " this.ParentPlugin.name " fired destructor"
	}
	
	_BuildMenu(){
		for i, cls in this._IOClasses {
			cls.AddMenuItems()
		}
		this.AddMenuItem("Clear", "Clear", this._ChangedValue.Bind(this, 2))
	}
	
	_ChangedValue(o){
		if (o == 2){
			this.__value.Binding := []
			this.__value.DeviceID := 0
			this.SetBinding(this.__value)
		}
	}
	
	; Set the state of the GuiControl (Inc Cue Banner)
	SetControlState(){
		if (this.IsBound()){
			this.SetCueBanner(this.__value.BuildHumanReadable())
		} else {
			this.SetCueBanner("Select an " this._Text " Axis")
		}
		for i, cls in this._IOClasses {
			cls.UpdateMenus(this.__value.IOClass)
		}
	}
}
