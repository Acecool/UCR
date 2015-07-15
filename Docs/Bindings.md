#Component design document for binding system

##Goal
To provide a replacement for the AHK `Hotkey` GUI control which allows a script user to bind any input combination to a script action. The default AHK `Hotkey` control does not support all keyboard keys / mouse combinations, and does not support joystick input at all (ie it should use RawInput / HID / DirectInput).  

##Requirements
* The control should be able to detect keyboard, mouse or joystick input (Or any combination thereof). Joystick support should not be via WinMM, as this only supports 4 axes, 32 buttons, 1 POV. Full 8 axis, 128 button, 4 POV support is essential.
* The author should be able to define a callback function which is called whenever the state of the selected input changes (ie button up / down event, axis value changes) and pass the new state.  
* The control should have options for pass-through (`~`) and wild (`*`) mode (Keyboard / Mouse).
* The end-user should be able to clear bindings (Click Bind button and hold ESCape).
* The current binding should be able to be set programatically (eg when script loads, settings pulled from an INI file and control state initialized to existing binding).
* A callback should be able to be specified that gets called when the end-user changes binding.
* The control may need to be application aware - ie only fire callback if the input occurs while a specified application is active.
* (Optional) Should support XInput to allow the L/R triggers of XBOX controllers to be read independently.  


##Hurdles
* Joystick state reading POC written (Using RawInput), but axis values are pre-calibration. Possible info on extracting calibration info [here](https://msdn.microsoft.com/en-us/library/windows/hardware/ff543344(v=vs.85).aspx) ?
* Keyboard / mouse detection will probably need to make use of `SetWindowsHookEx` calls (POC written).

##Example usage
To clarify the requirements, here is a (psuedo-code) example of how it may work.  
```
fnFire := this.FireAllWeapons.Bind(this)  ; Define what func gets called on binding pressed
fnChange := this.OptionChanged.Bind(this)   ; Define what func gets called on binding change
AddHotkeyGuiControl("Fire All Weapons", "xm yp+10", fnFire, fnChange)  ; Adds GUI control

[...]

; Called when bound input changes state
FireAllWeapons(button, axis){
   if (button != -1){
      ; Button state changed
      ; button = 1 if button was pressed
      ; button = 0 if button was released
   } else if (axis != -1){
      ; axis = new value of axis (0 - 32767)
   }
}
```
