﻿class TitanOne_Output extends _UCR.Classes.IOClasses.IOClassBase {
	static IsInitialized := 0
	static IsAvailable := 0
	static _hModule := 0
	
	_Init(){
		if (_UCR.Classes.IOClasses.TitanOne_Output.IsInitialized)
			return
		this._LoadLibrary()
	}
	
	_LoadLibrary(){
		this.LoadLibraryLog := ""
		hModule := DLLCall("LoadLibrary", "Str", "Resources\gcdapi.dll", "Ptr")
		this.LoadLibraryLog .= "Loading Resources\gcdapi.dll returned " hModule "`n"
		if (hModule){
			; Initialize the API
			ret := DllCall("gcdapi\gcdapi_Load", "char")
			this.LoadLibraryLog .= "gcdapi\gcdapi_Load returned " ret "`n"
			if (ret){
				this.LoadLibraryLog .= "Titan One library loaded OK`n"
				this._SetInitState(hMoudule)
				return
			}
		}
		this._SetInitState(0)
	}
	
	_SetInitState(hMoudule){
		state := (hModule != 0)
		_UCR.Classes.IOClasses.TitanOne_Output._hModule := hModule
		_UCR.Classes.IOClasses.TitanOne_Output.IsAvailable := state
		_UCR.Classes.IOClasses.TitanOne_Output.IsInitialized := state
		UCR.IOClassMenu.AddSubMenu("Titan One", "TitanOne")
			.AddMenuItem("Show &Titan One Log...", "ShowTitanOneLog", this.ShowLog.Bind(this))
	}
	
	ShowLog(){
		Clipboard := this.LoadLibraryLog
		msgbox % this.LoadLibraryLog "`n`nThis information has been copied to the clipboard"
	}
}

class TitanOne_Button_Output extends _UCR.Classes.IOClasses.TitanOne_Output {
	static IOClass := "TitanOne_Button_Output"
	static _NumButtons := 12
	
	BuildHumanReadable(){
		return this._Prefix " Titan One Buttton " this.BuildButtonName(this.Binding[1])
	}
	
	BuildButtonName(id){
		return id
	}
	
	AddMenuItems(){
		menu := this.ParentControl.AddSubMenu("Titan One Buttons", "TitanOneButtons")
		Loop % this._NumButtons {
			menu.AddMenuItem(A_Index, A_Index, this._ChangedValue.Bind(this, A_Index))	; Set the callback when selected
		}
	}

	_ChangedValue(o){
		bo := this.ParentControl.GetBinding()._Serialize()
		bo.IOClass := this.IOClass
		if (o <= this._NumButtons){
			; Button selected
			bo.Binding := [o]
		} else {
			return
		}
		this.ParentControl.SetBinding(bo)
	}
}





/*
		menu := this.ParentControl.AddSubMenu("Titan Axis", "TitanAxis")
		offset := 100
		Loop 6 {
			str := ""
			TitanAxes := UCR.Libraries.Titan.GetAxisNames()
			axis := A_Index
			str := " ( ", i := 0
			for console, axes in TitanAxes {
				if (!axes[axis])
					continue
				if (i){
					str .= " / "
				}
				str .= console " " axes[axis]
				i++
			}
			str .= ")"

			;names := GetAxisNames
			menu.AddMenuItem(A_Index str, A_Index, this._ChangedValue.Bind(this, offset + A_Index))
		}
		
		
		
				state := Round(state/327.67)
				UCR.Libraries.Titan.SetAxisByIndex(this.__value.Axis, state)


		*/
		
		/*
		TitanButtons := UCR.Libraries.Titan.GetButtonNames()
		menu := this.AddSubMenu("Titan Buttons", "TitanButtons")
		Loop 13 {
			btn := A_Index
			str := " ( ", i := 0
			for console, buttons in TitanButtons {
				if (!buttons[btn])
					continue
				if (i){
					str .= " / "
				}
				str .= console " " buttons[btn]
				i++
			}
			str .= ")"
			menu.AddMenuItem(A_Index str, "Button" A_Index, this._ChangedValue.Bind(this, 10000 + A_Index))
		}

		menu := this.AddSubMenu("Titan Hat", "TitanHat")
		Loop 4 {
			menu.AddMenuItem(HatDirections[A_Index], HatDirections[A_Index], this._ChangedValue.Bind(this, 10210 + A_Index))	; Set the callback when selected
		}
		*/
