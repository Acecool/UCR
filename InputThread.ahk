Class _InputThread {
	IOClasses := {AHK_KBM_Input: 0}
	__New(){
		for name, state in this.IOClasses {
			cls := name "_BindThread"
			this.IOClasses[name] := new %cls%(this)
		}
		;msgbox new
	}
	
	UpdateBindings(ControlGUID, j){
		
		;msgbox % "Adding object of class:" IOBoj.__value.IOClass
		OutputDebug % "UCR| _InputThread.UpdateBindings - cls: " j.IOClass
		;this.IOClasses[j.IOClass]._Deserialize(j)
		;this.IOClasses[j.IOClass].UpdateBinding()
		
		this.IOClasses[j.IOClass].UpdateBinding(ControlGUID, j)
		
		;tmp.UpdateBinding()
		;bindobj.UpdateBinding()
		/*
		Loop % bindobj.Binding.length() {
			btn := bindobj.Binding[A_Index]
			OutputDebug % "UCR| Adding Button code " btn
			
		}
		*/
	}
}

	class AHK_KBM_Input_BindThread {
		__New(parent){
			this.ParentThread := parent
		}
		
		/*
		_Deserialize(obj){
			for k, v in obj {
				this[k] := v
			}
		}
		*/
		
		; THREAD COMMANDS
		UpdateBinding(ControlGUID, j){
			;msgbox Update binding
			;return
			this.RemoveBinding(ControlGUID)
			keyname := this.BuildHotkeyString(j)
			if (keyname){
				fn := this.KeyEvent.Bind(this, 1)
				hotkey, % keyname, % fn, On
				fn := this.KeyEvent.Bind(this, 0)
				hotkey, % keyname " up", % fn, On
				OutputDebug % "UCR| Added hotkey " keyname
				this._CurrentBinding := keyname
			}
		}
		
		RemoveBinding(ControlGUID){
			return
			hotkey, % this._CurrentBinding, UCR_DUMMY_LABEL
			hotkey, % this._CurrentBinding, Off
			hotkey, % this._CurrentBinding " up", UCR_DUMMY_LABEL
			hotkey, % this._CurrentBinding " up", Off
			this._CurrentBinding := 0
		}
		
		KeyEvent(e){
			; ToDo: Parent will not exist in thread!
			
			OutputDebug % "UCR| KEY EVENT"
			;this.ParentControl.ChangeStateCallback.Call(e)
			;msgbox % "Hotkey pressed - " this.ParentControl.Parentplugin.id
		}
		; == END OF THREAD COMMANDS

		;ToDo: Add include
		static _Modifiers := ({91: {s: "#", v: "<"},92: {s: "#", v: ">"}
		,160: {s: "+", v: "<"},161: {s: "+", v: ">"}
		,162: {s: "^", v: "<"},163: {s: "^", v: ">"}
		,164: {s: "!", v: "<"},165: {s: "!", v: ">"}})

		; Builds an AHK hotkey string (eg ~^a) from a BindObject
		BuildHotkeyString(bo){
			if (!bo.Binding.Length())
				return ""
			str := ""
			if (bo.BindOptions.Wild)
				str .= "*"
			if (!bo.BindOptions.Block)
				str .= "~"
			max := bo.Binding.Length()
			Loop % max {
				key := bo.Binding[A_Index]
				if (A_Index = max){
					islast := 1
					nextkey := 0
				} else {
					islast := 0
					nextkey := bo[A_Index+1]
				}
				if (this.IsModifier(key) && (max > A_Index)){
					str .= this.RenderModifier(key)
				} else {
					str .= this.BuildKeyName(key)
				}
			}
			return str
		}
		
		; Builds the AHK key name
		BuildKeyName(code){
			static replacements := {33: "PgUp", 34: "PgDn", 35: "End", 36: "Home", 37: "Left", 38: "Up", 39: "Right", 40: "Down", 45: "Insert", 46: "Delete"}
			static additions := {14: "NumpadEnter"}
			if (ObjHasKey(replacements, code)){
				return replacements[code]
			} else if (ObjHasKey(additions, code)){
				return additions[code]
			} else {
				return GetKeyName("vk" Format("{:x}", code))
			}
		}
		
		; Returns true if this Button is a modifier key on the keyboard
		IsModifier(code){
			return ObjHasKey(this._Modifiers, code)
		}
		
		; Renders the keycode of a Modifier to it's AHK Hotkey symbol (eg 162 for LCTRL to ^)
		RenderModifier(code){
			return this._Modifiers[code].s
		}

	}
