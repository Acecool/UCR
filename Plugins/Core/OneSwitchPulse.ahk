/*
OneSwitch pulse (J2K version) for UCR
*/

; All plugins must derive from the _Plugin class
class OneSwitchPulse extends _Plugin {
	Type := "OneSwitch Pulse"
	Description := "OneSwitch Pulse for UCR. Designed to be used with JoyToKey. Add to Global profile."
	TimerRunning := 0
	; The Init() method of a plugin is called when one is added. Use it to create your Gui etc
	Init(){
		; Create the GUI
		Gui, % this.hwnd ":Add", GroupBox, xm ym w310 h75, Inputs
		Gui, % this.hwnd ":Add", Text, xm+5 yp+20, % "Toggle On/Off"
		this.AddInputButton("Toggle", 0, this.Toggle.Bind(this), "x100 yp-2 w200")
		
		Gui, % this.hwnd ":Add", Text, xm+5 y+10, % "Choice"
		this.AddInputButton("Choice1", 0, this.ChoiceChangedState.Bind(this), "x100 yp-2 w200")
		
		Gui, % this.hwnd ":Add", GroupBox, x+30 ym w310 h75, Outputs
		
		Gui, % this.hwnd ":Add", Text, xp+5 yp+20 Section, % "Pulse Button"
		this.AddOutputButton("PulseButton", 0, "xs+100 yp-2 w200")
		
		Gui, % this.hwnd ":Add", Text, xs y+10, % "Timeout Button"
		this.AddOutputButton("TimeoutButton", 0, "xs+100 yp-2 w200")
		
		Gui, % this.hwnd ":Add", GroupBox, xm y+20 w630 h45 Section, Special Features
		
		;Gui, % this.hwnd ":Add", Text, xs y+10, % "Hold Button"
		this.AddControl("HoldButtonEnabled", this.HoldButtonChanged.Bind(this), "CheckBox", "xp+5 yp+20 w200", "Hold HoldButton while Pulse is active")
		
		Gui, % this.hwnd ":Add", Text, x335 yp, % "HoldButton"
		this.AddOutputButton("HoldButton", 0, "xp+100 yp-2 w200")
		
		Gui, % this.hwnd ":Add", GroupBox, xm yp+40 w440 h130 Section, Timer Settings (All in MilliSeconds)
		
		Gui, % this.hwnd ":Add", Text, xm+5 yp+20, % "Pulse Rate (How often to hit the Pulse Button)"
		this.AddControl("PulseRate", 0, "Edit", "x400 yp-2 w40", 500)
		
		Gui, % this.hwnd ":Add", Text, xm+5 y+10, % "Choice Delay (After input activity, how long to wait before pulsing again)"
		this.AddControl("SuspendTime", 0, "Edit", "x400 yp-2 w40", 2000)
		
		Gui, % this.hwnd ":Add", Text, xm+5 y+10, % "Timeout (If no input activity for this time, hit Timeout Button)"
		this.AddControl("TimeOut", 0, "Edit", "x400 yp-2 w40", 5000)

		Gui, % this.hwnd ":Add", Text, xm+5 y+10, % "Timeout Warning (If no input activity for this time, play warning)"
		this.AddControl("TimeOutWarning", 0, "Edit", "x400 yp-2 w40", 4000)

		Gui, % this.hwnd ":Add", Text, x+10 ys+20 Center w200 h100 hwndhStatus
		Gui, % this.hwnd ":Font"
		this.hStatus := hStatus

		this.Enabled := 0	; Whether the state is toggled on or off
		this.ShowStatus()
		
		this.PulseFn := this.Pulse.Bind(this)
		this.TimeoutFn := this.Timeout.Bind(this)
		this.TimeoutWarningFn := this.TimeoutWarning.Bind(this)
		this.ResumePulseFn := this.SetTimerState.Bind(this, 1)
	}
	
	; The user pressed the Toggle on / off hotkey
	Toggle(e){
		if (e){
			this.Enabled := !this.Enabled
			if (this.GuiControls.HoldButtonEnabled.value)
				this.OutputButtons.HoldButton.SetState(this.Enabled)
			this.ShowStatus()
			OutputDebug % "UCR| Setting State - " this.Enabled
			this.SetSubscriptionState(this.Enabled)
			this.SetTimerState(this.Enabled)
			this.AsynchBeep((this.Enabled * 500) + 500)
		}
	}
	
	ShowStatus(){
		GuiControl, , % this.hStatus, % (this.Enabled ? "ON" : "OFF")
		Gui, % this.hwnd ":Font", % (this.Enabled ? "cGreen" : "cRed") " s60"
		GuiControl, Font, % this.hStatus
		Gui, % this.hwnd ":Font"
	}
	
	; Called when the Choice button changes state (key is pressed or released)
	; Does nothing, the choice button is handled by InputActivity() like all other input
	ChoiceChangedState(e){
		;~ OutputDebug, % "Choice changed state to: " (e ? "Down" : "Up")
		;~ this.DelayTimers()
	}


	; One of the Input Button / Axis bindings in UCR changed state
	; even ones in other profiles / plugins
	InputActivity(ipt, state){
		if (ipt == this.InputButtons.Toggle)
			return	; ignore input from the Toggle Button
		if (ipt.value.type == 4){
			OutputDebug % "UCR| InputActivity (Axis)"
			;this.DelayTimers()
			this.ScheduleTimers()
		} else {
			; Button type input - stop timers while button is down, call DelayTimers() on up
			OutputDebug % "UCR| InputActivity (Button) - state: " state
			if (state){
				this.SetTimerState(0)
			} else {
				this.ScheduleTimers()
			}
		}
	}

	HoldButtonChanged(e){
		if (e){
			if (this.TimerRunning)
				this.OutputButtons.HoldButton.SetState(1)
		} else {
			this.OutputButtons.HoldButton.SetState(0)
		}
	}
	
	; Schedules the timers to restart after the amount of time specified by the SuspendTime GuiControl
	ScheduleTimers(){
		fn := this.ResumePulseFn
		SetTimer, % fn, % "-" this.GuiControls.SuspendTime.value
	}
	
	; Send a pulse to J2K
	Pulse(){
		OutputDebug % "UCR| Pulse " round(A_TickCount / 1000, 2)
		this.OutputButtons.PulseButton.SetState(1)
		Sleep 50
		this.OutputButtons.PulseButton.SetState(0)
	}
	
	; Send a timeout to J2K
	Timeout(){
		OutputDebug % "UCR| Pulse Timeout " round(A_TickCount / 1000, 2)
		this.SetTimerState(0)
		this.OutputButtons.TimeoutButton.SetState(1)
		Sleep 50
		this.OutputButtons.TimeoutButton.SetState(0)
		this.SetTimerState(1)
	}
	
	TimeoutWarning(){
		OutputDebug % "UCR| Pulse Timeout Warning"
		this.AsynchBeep(750,50)
		this.AsynchBeep(750,50)
	}
	
	; Called when plugin (ie profile) becomes active
	OnActive(){
		if (this.Enabled){
			this.SetSubscriptionState(1)
			this.SetTimerState(1)
		}
	}
	
	OnInActive(){
		if (this.Enabled){
			this.SetTimerState(0)
			this.SetSubscriptionState(0)
		}
	}
	
	; Turns on or off the listening of input activity
	SetSubscriptionState(state){
		if (state){
			UCR.SubscribeToInputActivity(this.hwnd, this.ParentProfile.id, this.InputActivity.Bind(this))
		} else {
			UCR.UnSubscribeToInputActivity(this.hwnd, this.ParentProfile.id)
		}
	}
	
	; Turns on or off the timers
	SetTimerState(state){
		OutputDebug % "UCR| Changing Timer state to: " state
		pfn := this.PulseFn
		tfn := this.TimeoutFn
		wfn := this.TimeoutWarningFn
		rfn := this.ResumePulseFn
		if (state && this.Enabled){
			SetTimer, % pfn, % this.GuiControls.PulseRate.Value
			SetTimer, % tfn, % "-" this.GuiControls.TimeOut.Value
			if (warn := this.GuiControls.TimeOutWarning.Value)
				SetTimer, % wfn, % "-" warn
		} else if (!state){
			try {
				SetTimer, % pfn, Off
				SetTimer, % tfn, Off
				SetTimer, % wfn, Off
				SetTimer, % rfn, Off
			}
		}
		this.TimerRunning := state
	}
	
	AsynchBeep(freq, dur := 250){
		fn := this._AsynchBeep.Bind(this, freq, dur)
		SetTimer, % fn, -0
	}
	
	_AsynchBeep(freq, dur){
		SoundBeep, % freq, % dur
	}
}
