; ======================================================================== BANNER MENU ===============================================================
; A compound GuiControl with a Readout (Shows current state) and a menu
class _BannerMenu extends _Menu {
	__New(ParentHwnd, aParams*){
		this._ParentHwnd := ParentHwnd
		this._Ptr := &this
		
		base.__New()
		Gui, Add, Button, % "hwndhReadout " aParams[1]
		this.hReadout := hReadout
		fn := this.OpenMenu.Bind(this)
		GuiControl, +g, % this.hReadout, % fn

		this.hwnd := hReadout	; all classes that represent Gui objects should have a unique hwnd property
	}
	
	; Shows the menu
	OpenMenu(){
		ControlGetPos, cX, cY, cW, cH,, % "ahk_id " this.hReadout
		Menu, % this.id, Show, % cX+1, % cY + cH
	}
	
	; Sets the text of the Cue Banner
	SetCueBanner(text){
		GuiControl,, % this.hReadout, % text
	}
	
	; Override
	_ChangedValue(o){
		
	}
	
	; All Input controls should implement this function, so that if the Input Thread for the profile is terminated...
	; ... then it can be re-built by calling this method on each control.
	_RequestBinding(){
		; do nothing
	}
}
