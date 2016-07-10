﻿; ======================================================================== PROFILE SLECT ===============================================================
class _ProfileSelect extends _BannerCombo {
	; Public vars
	State := -1			; State of the input. -1 is unset. GET ONLY
	; Internal vars describing the bindstring
	__value := 0		; Holds the Profile ID
	; Other internal vars
	_DefaultBanner := "Drop down the list to select a profile"
	_Options := ["Select Profile", "Clear Profile"]
	
	__New(parent, name, ChangeValueCallback, aParams*){
		base.__New(parent.hwnd, aParams*)
		this.ParentPlugin := parent
		this.Name := name
		this.ChangeValueCallback := ChangeValueCallback
		
		;this.__value := new _BindObject()
		this.SetComboState()
		UCR.SubscribeToProfileTreeChange(this.hwnd, this.SetComboState.Bind(this))
	}
	
	; Set the state of the GuiControl (Inc Cue Banner)
	SetComboState(){
		if (this.__value){
			; Has current binding
			this.SetOptions(this._Options)
			this.SetCueBanner(UCR.BuildProfilePathName(this.__value))
		} else {
			this.SetOptions([this._Options[1]])
			this.SetCueBanner(this._DefaultBanner)
		}
	}
	
	_ChangedValue(o){
		if (o == 1){
			;this.value := 1
			UCR._ProfilePicker.PickProfile(this.ProfileChanged.Bind(this), this.__value)
		} else {
			this.value := 0
		}
	}

	; A new selection was made in the Profile Picker
	ProfileChanged(id){
		this.value := id
	}
	
	value[]{
		get {
			return this.__value
		}
		
		set {
			this._value := value	; trigger _value setter to set value and cuebanner etc
			;OutputDebug % "UCR| "
			this.ParentPlugin._ControlChanged(this)
		}
	}
	
	_value[]{
		get {
			return this.__value
		}
		
		; Parent class told this hotkey what it's value is. Set value, but do not fire ParentPlugin._ControlChanged
		set {
			if (this.__value)
				this.ParentPlugin.ParentProfile.UpdateLinkedProfiles(this.ParentPlugin.id, this.__value, 0)
			this.__value := value
			if (value)
				this.ParentPlugin.ParentProfile.UpdateLinkedProfiles(this.ParentPlugin.id, value, 1)
			this.SetComboState()
		}
	}
	
	; Kill references so destructor can fire
	_KillReferences(){
		this.ChangeValueCallback := ""
		UCR.UnSubscribeToProfileTreeChange(this.hwnd)
	}
	
	_Serialize(){
		obj := {value: this._value}
		return obj
	}
	
	_Deserialize(obj){
		this._value := obj.value
	}
}
