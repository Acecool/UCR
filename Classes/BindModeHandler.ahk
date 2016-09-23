﻿; =================================================================== BIND MODE HANDLER ==========================================================
; Prompts the user for input and detects their choice of binding
class _BindModeHandler {
	DebugMode := 2
	SelectedBinding := 0
	BindMode := 0
	EndKey := 0
	HeldModifiers := {}
	ModifierCount := 0
	_Callback := 0
	
	__New(){
		;this._BindModeThread:=AhkThread(A_ScriptDir "\Threads\BindModeThread.ahk",,1) ; Loads the AutoHotkey module and starts the script.
		;While !this._BindModeThread.ahkgetvar.autoexecute_done
		;	Sleep 50 ; wait until variable has been set.
		;this._BindModeThread.ahkExec["BindMapper := new _BindMapper(" ObjShare(this.ProcessInput.Bind(this)) ")"]
		this._BindModeThread := new _BindMapper(this.ProcessInput.Bind(this))
		
		Gui, new, +HwndHwnd
		Gui +ToolWindow -Border
		Gui, Font, S15
		Gui, Color, Red
		this.hBindModePrompt := hwnd
		Gui, Add, Text, Center, Press the button(s) you wish to bind to this control.`n`nBind Mode will end when you release a key.
	}
	
	/*
	StartBindMode(hk, callback){
		this._callback := callback
		this._OriginalHotkey := hk
		
		this.SelectedBinding := 0
		this.BindMode := 1
		this.EndKey := 0
		this.HeldModifiers := {}
		this.ModifierCount := 0
		
		; When detecting an output, tell the Bind Handler to ignore physical joysticks...
		; ... as output cannot be "sent" to physical sticks
		;this.SetHotkeyState(1, !hk._IsOutput)
		this.SetHotkeyState(1, 1)
	}
	*/
	;IOClassMappings, this._BindModeEnded.Bind(this, callback)
	StartBindMode(IOClassMappings, callback){
		this._callback := callback
		
		this.SelectedBinding := {Binding: [], DeviceID: 0, IOClass: 0}
		this.BindMode := 1
		this.EndKey := 0
		this.HeldModifiers := {}
		this.ModifierCount := 0
		this.IOClassMappings := IOClassMappings
		
		; When detecting an output, tell the Bind Handler to ignore physical joysticks...
		; ... as output cannot be "sent" to physical sticks
		;this.SetHotkeyState(1, !hk._IsOutput)
		this.SetHotkeyState(1, 1)
	}
	
	; Turns on or off the hotkeys
	SetHotkeyState(state, enablejoystick := 1){
		if (state){
			Gui, % this.hBindModePrompt ":Show"
			UCR.MoveWindowToCenterOfGui(this.hBindModePrompt)
		} else {
			Gui, % this.hBindModePrompt ":Hide"
		}
		;this._BindModeThread.ahkExec["BindMapper.SetHotkeyState(" state "," enablejoystick ")"]
		;this._BindModeThread.SetHotkeyState(state, enablejoystick)
		this._BindModeThread.SetDetectionState(state, this.IOClassMappings)
	}
	
	; The BindModeThread calls back here
	ProcessInput(e, i, deviceid, IOClass){
		;ToolTip % "e " e ", i " i ", deviceid " deviceid ", IOClass " IOClass
		;if (ObjHasKey(this._Modifiers, i))
		if (this.SelectedBinding.IOClass && (this.SelectedBinding.IOClass != IOClass)){
			; Changed binding IOCLass part way through.
			if (e){
				SoundBeep, 500, 100
			}
			return
		}
		max := this.SelectedBinding.Binding.length()
		if (e){
			for idx, code in  this.SelectedBinding.Binding {
				if (i == code)
					return	; filter repeats
			}
			this.SelectedBinding.Binding.push(i)
			this.SelectedBinding.DeviceID := DeviceID
			if (this.AHK_KBM_Input.IsModifier(i)){
				if (max > this.ModifierCount){
					; Modifier pressed after end key
					SoundBeep, 500, 100
					return
				}
				this.ModifierCount++
			} else if (max > this.ModifierCount) {
				; Second End Key pressed after first held
				SoundBeep, 500, 100
				return
			}
			this.SelectedBinding.IOClass := IOClass
		} else {
			this.BindMode := 0
			this.SetHotkeyState(0, this.IOClassMappings)
			;ret := {Binding:[i], DeviceID: deviceid, IOClass: this.IOClassMappings[IOClass]}
			
			OutputDebug % "UCR| BindModeHandler: Bind Mode Ended. Binding[1]: " this.SelectedBinding.Binding[1] ", DeviceID: " this.SelectedBinding.DeviceID ", IOClass: " this.SelectedBinding.IOClass
			this._Callback.Call(this.SelectedBinding)
		}
	}
	
	; Implements IsModifier to tell the BindMode Handler that this IOClass can be a modifier
	class AHK_KBM_Input {
		static _Modifiers := ({91: {s: "#", v: "<"},92: {s: "#", v: ">"}
			,160: {s: "+", v: "<"},161: {s: "+", v: ">"}
			,162: {s: "^", v: "<"},163: {s: "^", v: ">"}
			,164: {s: "!", v: "<"},165: {s: "!", v: ">"}})
		
		IsModifier(code){
			return ObjHasKey(this._Modifiers, code)
		}
	}
	
	/*
	; The BindModeThread calls back here
	_ProcessInput(e, type, code, deviceid){
		;OutputDebug % "UCR| _ProcessInput: e: " e ", type: " type ", code: " code ", deviceid: " deviceid
		; Build Key object and pass to ProcessInput
		i := new _Button({type: type, code: code, deviceid: deviceid})
		this.ProcessInput(i,e)
	}
	*/
	
	/*
	; Called when a key was pressed
	ProcessInput(i, e){
		if (!this.BindMode)
			return
		if (i.type > 1){
			is_modifier := 0
		} else {
			is_modifier := i.IsModifier()
			; filter repeats
			;if (e && (is_modifier ? ObjHasKey(HeldModifiers, i.code) : EndKey) )
			if (e && (is_modifier ? ObjHasKey(this.HeldModifiers, i.code) : i.code = this.EndKey.code) )
				return
		}

		;~ ; Are the conditions met for end of Bind Mode? (Up event of non-modifier key)
		;~ if ((is_modifier ? (!e && ModifierCount = 1) : !e) && (i.type > 1 ? !ModifierCount : 1) ) {
		; Are the conditions met for end of Bind Mode? (Up event of any key)
		if (!e){
			; End Bind Mode
			this.BindMode := 0
			this.SetHotkeyState(0)
			;bindObj := this._OriginalHotkey.value.clone()
			bindObj := {}
			bindObj.Buttons := []
			for code, key in this.HeldModifiers {
				bindObj.Buttons.push(key)
			}
			
			bindObj.Buttons.push(this.EndKey)
			bindObj.Type := this.EndKey.Type
			;this._Callback.(this._OriginalHotkey, bindObj)
			
			; New format
			ret :={Binding: []}
			max := BindObj.buttons.Length()
			Loop % max {
				ret.Binding.push(BindObj.buttons[A_Index].code)
			}
				
			; Simulate BindMode Thread passing back input type that generated result
			if (bindObj.Type == 1){
				t := "AHK_KBM_Input"
			} else if (bindObj.Type == 2) {
				t := "AHK_JoyBtn_Input"
				ret.DeviceID := BindObj.buttons[max].DeviceID
			} else if (bindObj.Type == 3) {
				t := "AHK_JoyHat_Input"
				ret.DeviceID := BindObj.buttons[max].DeviceID
			}
			; Resolve input type to binding type
			; {AHK_KBM_Input: "AHK_KBM_Input", AHK_JoyBtn_Input: "AHK_JoyBtn_Input", AHK_JoyHat_Input: "AHK_JoyHat_Input"}
			;t := this._OriginalHotkey._BindTypes[t]
			ret.IOClass := this.IOClassMappings[t]
			;this._Callback.(this._OriginalHotkey, ret, t)
			this._Callback.Call(ret, t)
			
			return
		} else {
			; Process Key Up or Down event
			if (is_modifier){
				; modifier went up or down
				if (e){
					this.HeldModifiers[i.code] := i
					this.ModifierCount++
				} else {
					this.HeldModifiers.Delete(i.code)
					this.ModifierCount--
				}
			} else {
				; regular key went down or up
				if (i.type > 1 && this.ModifierCount){
					; Reject joystick button + modifier - AHK does not support this
					if (e)
						SoundBeep
				} else if (e) {
					; Down event of non-modifier key - set end key
					this.EndKey := i
				}
			}
		}
		
		; Mouse Wheel u/d/l/r has no Up event, so simulate it to trigger it as an EndKey
		if (e && (i.code >= 156 && i.code <= 159)){
			this.ProcessInput(i, 0)
		}
	}
	*/
}
