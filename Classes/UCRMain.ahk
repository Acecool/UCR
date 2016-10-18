﻿; ======================================================================== MAIN CLASS ===============================================================
Class _UCR {
	Version := "0.1.4"				; The version of the main application
	SettingsVersion := "0.0.6"		; The version of the settings file format
	_StateNames := {0: "Normal", 1: "InputBind", 2: "GameBind"}
	_State := {Normal: 0, InputBind: 1, GameBind: 2}
	_GameBindDuration := 0			; The amount of time to wait in GameBind mode (ms)
	_CurrentState := 0				; The current state of the application
	;Profiles := []					; A hwnd-indexed sparse array of instances of _Profile objects
	Profiles := {}					; A unique-id indexed sparse array of instances of _Profile objects
	ProfileTree := {}				; A lookup table for Profile order. A sparse array of Parent IDs, containing Ordered Arrays of Profile IDs
	Libraries := {}					; A name indexed array of instances of library objects
	CurrentProfile := 0				; Points to an Instance of the _Profile class which is the current active profile
	CurrentPID := 0					; The ID of the _Profile class which is the current active profile
	PluginList := []				; A list of plugin Types (Lookup to PluginDetails), indexed by order of Plugin Select DDL
	PluginDetails := {}				; A name-indexed list of plugin Details (Classname, Description etc). Name is ".Type" property of class
	BindControlLookup := {}			; Allows bind threads to find the plugin that
	PLUGIN_WIDTH := 680				; The Width of a plugin
	PLUGIN_FRAME_WIDTH := 720		; The width of the plugin area
	SIDE_PANEL_WIDTH := 150			; The default width of the side panel
	TOP_PANEL_HEIGHT := 75			; The amount of space reserved for the top panel (profile select etc)
	GUI_MIN_HEIGHT := 300			; The minimum height of the app. Required because of the way AHK_H autosize/pos works
	CurrentSize := {w: this.PLUGIN_FRAME_WIDTH + this.SIDE_PANEL_WIDTH, h: this.GUI_MIN_HEIGHT}	; The current size of the app.
	CurrentPos := {x: "", y: ""}										; The current position of the app.
	_ProfileTreeChangeSubscriptions := {}	; An hwnd-indexed array of callbacks for things that wish to be notified if the profile tree changes
	_InputActivitySubscriptions := {}
	_InputThreadScript := ""		; Set in Ctor
	_ThreadHeader := "`n#Persistent`n#NoTrayIcon`n#MaxHotkeysPerInterval 9999`n"
	_ThreadFooter := "`nautoexecute_done := 1`nreturn`n"
	_LoadedInputThreads := {}		; ProfileID-indexed sparse array of loaded input threads
	_InputThreadStates := {}
	_SavingToDisk := 0				; 1 if in the process of saving to disk. Do not allow exit while this is 1
	; Default User Settings
	UserSettings := {MinimizeOptions: {MinimizeToTray: 1, StartMinimized: 0}, GuiControls: {ShowJoystickNames: 1}}
	
	__New(){
		; ============== Init section - This needs to be done first ========
		; Set super-global UCR to point to class instance
		global UCR := this
		
		; Get the HWND of the default GUI
		Gui +HwndHwnd
		this.hwnd := hwnd
		
		; Work out the name of the INI file
		str := A_ScriptName
		if (A_IsCompiled)
			str := StrSplit(str, ".exe")
		else
			str := StrSplit(str, ".ahk")
		this._SettingsFile := A_ScriptDir "\" str.1 ".ini"
		; Load the settings file into an object, but do nothing with it for now
		SettingsObj := this._LoadSettings()
		; Merge the User Settings onto the default settings
		this.MergeObject(this.UserSettings, SettingsObj.UserSettings) ;*[UCR]
		; ======================= End of init ==============================
		
		this.Minimizer := new _Minimizer(this.hwnd, this._GuiMinimized.Bind(this))
		
		FileRead, Script, % A_ScriptDir "\Threads\ProfileInputThread.ahk"
		
		; Cache script for profile InputThreads
		this._InputThreadScript := this._ThreadFooter Script 
		
		/*
		if (this.UserSettings.GuiControls.ShowJoystickNames){
			; Load the Joystick OEM name DLL
			#DllImport,joystick_OEM_name,%A_ScriptDir%\Resources\JoystickOEMName.dll\joystick_OEM_name,double,,CDecl AStr
			;~ DllCall("LoadLibrary", Str, A_ScriptDir "\Resources\JoystickOEMName.dll")
			;~ if (ErrorLevel != 0){
				;~ MsgBox Error Loading \Resources\JoystickOEMName.dll. Exiting...
				;~ ExitApp
			;~ }
		}
		*/
		
		this.SaveSettingsTimerFn := this.__SaveSettings.Bind(this)		
		
		; Provide a common repository of libraries for plugins
		this._LoadLibraries()
		
		; Start the input detection system
		this._BindModeHandler := new _BindModeHandler()
		this._InputHandler := new _InputHandler()
		
		; Add the Profile Toolbox - this is used to add and edit profiles
		this._ProfileToolbox := new _ProfileToolbox()
		this._ProfilePicker := new _ProfilePicker()
		
		; Create the Main Menu
		this._CreateMainMenu()
		
		; Create the Main Gui
		this._CreateGui()

		; Initialize IOClasses
		; This will add menu entries to the IOClasses menu, and load DLLs etc.
		for name, cls in _UCR.Classes.IOClasses {
			if (name == "__Class")
				continue
			;OutputDebug % "UCR| Initializing IOClass " name
			cls._Init()
		}

		; Load list of plugins and update Plugin Select
		this._LoadPluginList()
		this._UpdatePluginSelect()

		; Load the profiles and plugins from the settings file
		this._Deserialize(SettingsObj)
		
		; Update state of Profile Toolbox
		this.UpdateProfileToolbox()
		
		; Move the window to it's last position and size
		this._ShowGui()
		if (this.UserSettings.MinimizeOptions.StartMinimized){
			this._GuiMinimized()
		}
		
		; Start the Global Profile
		this._SetProfileState(1, 2)
		
		; Start the Current Profile, do not save
		this.ChangeProfile(SettingsObj.CurrentProfile, 0)
		
		; Watch window position and size using MessageFilter thread
		this._MessageFilterThread := AhkThread(A_ScriptDir "\Threads\MessageFilterThread.ahk",,1)
		While !this._MessageFilterThread.ahkgetvar.autoexecute_done
			Sleep 50 ; wait until variable has been set.
		matchobj := {msg: 0x5, hwnd: this.hwnd}
		filterobj := {hwnd: this.hwnd}
		this._MessageFilterThread.ahkExec["new MessageFilter(" ObjShare(this._OnSize.Bind(this)) "," &matchobj "," &filterobj ")"]
		matchobj.msg := 0x3
		this._MessageFilterThread.ahkExec["new MessageFilter(" ObjShare(this._OnMove.Bind(this)) "," &matchobj "," &filterobj ")"]
	}
	
	GuiClose(hwnd){
		if (hwnd = this.hwnd){
			while (this._SavingToDisk){
				; Wait for save to complete
				sleep 100
			}
			ExitApp
		}
	}
	
	_GuiMinimized(){
		if (this.UserSettings.MinimizeOptions.MinimizeToTray){
			this.Minimizer.MinimizeGuiToTray()
		} else {
			WinMinimize, % "ahk_id " this.hwnd
		}
	}
	
	; Libraries can be used to easily add functionality to UCR.
	; Place a folder in the Libraries folder eg "MyLib", with an ahk file of the same name (eg "MyLib.ahk") and it will be included.
	; It should contain a class definition of the same name (eg "Class MyLib") which will be instantiated and added to the Libraries array
	; Once instantiated, the method _UCR_LoadLibrary() will be called on the instance. It has the opportunity to return 1 for OK, 0 for fail
	; The class instance will be available for all plugins as UCR.Libraries.MyLib
	_LoadLibraries(){
		Loop, Files, % A_ScriptDir "\Libraries\*.*", D
		{
			str := A_LoopFileName
			filename := A_ScriptDir "\Libraries\" A_LoopFileName "\" A_LoopFileName ".ahk"
			if (FileExist(filename)){
				AddFile(filename, 1)
				lib := new %A_LoopFileName%()
				res := lib._UCR_LoadLibrary()
				if (res == 1){
					OutputDebug % "UCR| Loading Library " A_LoopFileName
					this.Libraries[A_LoopFileName] := lib
				}
			}
		}
	}
	
	_CreateGui(){
		Gui, % this.hwnd ":Margin", 0, 0
		Gui, % this.hwnd ":+Resize"
		start_width := UCR.PLUGIN_FRAME_WIDTH + UCR.SIDE_PANEL_WIDTH
		Gui, % this.hwnd ":Show", % "Hide w" start_width " h" UCR.GUI_MIN_HEIGHT, % "UCR - Universal Control Remapper v" this.Version
		Gui, % this.hwnd ":+Minsize" start_width + 15 "x" UCR.GUI_MIN_HEIGHT
		
		;Gui, % this.hwnd ":+Maxsize" start_width
		Gui, new, HwndHwnd
		this.hTopPanel := hwnd
		Gui % this.hTopPanel ":-Border"
		;Gui % this.hTopPanel ":Show", % "x0 y0 w" UCR.PLUGIN_FRAME_WIDTH " h" UCR.TOP_PANEL_HEIGHT, Main UCR Window
		
		; Profile Select DDL
		Gui, % this.hTopPanel ":Add", Text, xm y+10, Current Profile:
		Gui, % this.hTopPanel ":Add", Edit, % "x100 yp-5 hwndhCurrentProfile Disabled w" UCR.PLUGIN_FRAME_WIDTH - 115
		this.hCurrentProfile := hCurrentProfile
		
		;Gui, % this.hTopPanel ":Add", Button, % "x+5 yp-1 hwndhProfileToolbox w100", Profile Toolbox
		;this.hProfileToolbox := hProfileToolbox
		;fn := this._ProfileToolbox.ShowButtonClicked.Bind(this._ProfileToolbox)
		;GuiControl +g, % this.hProfileToolbox, % fn
		
		; Add Plugin
		Gui, % this.hTopPanel ":Add", Text, xm y+10, Plugin Selection:
		Gui, % this.hTopPanel ":Add", DDL, % "x100 yp-5 hwndhPluginSelect AltSubmit w" UCR.PLUGIN_FRAME_WIDTH - 150
		this.hPluginSelect := hPluginSelect
		
		Gui, % this.hTopPanel ":Add", Button, % "hwndhAddPlugin x+5 yp-1", Add
		this.hAddPlugin := hAddPlugin
		fn := this._AddPlugin.Bind(this)
		GuiControl % this.hTopPanel ":+g", % this.hAddPlugin, % fn
		
		Gui, % this.hwnd ":Add", Gui, % "w" UCR.PLUGIN_FRAME_WIDTH " h" UCR.TOP_PANEL_HEIGHT, % this.hTopPanel
		
		; Add the profile toolbox
		;Gui, % this.hwnd ":Add", Gui, % "x" UCR.PLUGIN_FRAME_WIDTH " ym aw ah w" UCR.SIDE_PANEL_WIDTH " h" UCR.GUI_MIN_HEIGHT, % this._ProfileToolbox.hwnd
		
		Gui, new, HwndHwnd
		this.hSidePanel := hwnd
		Gui % this.hSidePanel ":-Caption"
		Gui % this.hSidePanel ":Margin", 0, 0
		Gui, % this.hSidePanel ":Add", Text, % "x5 y5 aw Center w" UCR.SIDE_PANEL_WIDTH, Profile ToolBox
		Gui, % this.hSidePanel ":Add", Gui, % "x0 y+5 aw ah", % this._ProfileToolbox.hwnd
		Gui % this.hSidePanel ":Show", Hide
		Gui, % this.hwnd ":Add", Gui, % "x" UCR.PLUGIN_FRAME_WIDTH " ym aw ah w" UCR.SIDE_PANEL_WIDTH " h" UCR.GUI_MIN_HEIGHT, % this.hSidePanel
		
		;Gui, % this.hwnd ":Show"
	}
	
	; Creates the objects for the Main Menu
	_CreateMainMenu(){
		this.MainMenu := new _Menu()
		;this.MainMenu.AddSubMenu("Gui&Controls", "GuiControls")
		;	.AddMenuItem("Show Joystick &Names (Requires Restart)", "ShowJoystickNames", this._MenuHandler.Bind(this, "ShowJoystickNames"))
		this.MainMenu.AddSubMenu("&View", "View")
			.AddMenuItem("&Start Minimized", "StartMinimized", this._MenuHandler.Bind(this, "StartMinimized"))
			.parent.AddMenuItem("&Minimize to Tray", "MinimizeToTray", this._MenuHandler.Bind(this, "MinimizeToTray"))
		;this.MainMenu.AddSubMenu("&Debug", "Debug")
		;	.AddMenuItem("Show &vJoy Log...", "ShowvJoyLog", this._MenuHandler.Bind(this, "ShowvJoyLog"))
		this.IOClassMenu := this.MainMenu.AddSubMenu("&IOClasses", "IOClasses")
			;.AddMenuItem("Show &vJoy Log...", "ShowvJoyLog", this._MenuHandler.Bind(this, "ShowvJoyLog"))
		;this.MainMenu.AddSubMenu("&Titan Device", "Titan")
		;	.AddMenuItem("Detect current output type...", "DetectType", this._MenuHandler.Bind(this, "DetectTitanType"))
		Gui, % this.hwnd ":Menu", % this.MainMenu.id
	}
	
	; Called once at Startup to synch state of Main Menu with the INI file
	_SetMenuState(){
		for k, v in this.UserSettings.MinimizeOptions {
			this.MainMenu.MenusByName["View"].ItemsByName[k].SetCheckState(v)
		}
		
		for k, v in this.UserSettings.GuiControls {
			this.MainMenu.MenusByName["GuiControls"].ItemsByName[k].SetCheckState(v)
		}
		
	}
	
	; When an option is chose in the main menu, this is called
	_MenuHandler(name){
		if (name = "MinimizeToTray" || name = "StartMinimized"){
			this.UserSettings.MinimizeOptions[name] := !this.UserSettings.MinimizeOptions[name]
			this.MainMenu.MenusByName["View"].ItemsByName[name].ToggleCheck()
		}

		/*
		else if (name = "ShowJoystickNames"){
			this.UserSettings.GuiControls[name] := !this.UserSettings.GuiControls[name]
			this.MainMenu.MenusByName["GuiControls"].ItemsByName[name].ToggleCheck()
		}
		*/
		
		/*
		else if (name = "DetectTitanType"){
			this.Libraries.Titan.Acquire()
			type := this.Libraries.Titan.OutputNames[this.Libraries.Titan.Connections.output]
			if (!type)
				type := "Not connected"
			msgbox % "Currently plugged in as type: "type
		}
		*/
		this._SaveSettings()
	}
	
	_ShowGui(){
		xy := (this.CurrentPos.x != "" && this.CurrentPos.y != "" ? "x" this.CurrentPos.x " y" this.CurrentPos.y : "")
		Gui, % this.hwnd ":Show", % xy " h" this.CurrentSize.h " w" this.Currentsize.w
	}
	
	_OnMove(wParam, lParam, msg, hwnd){
		;this.CurrentPos := {x: LoWord(lParam), y: HiWord(lParam)}
		; Use WinGetPos rather than pos in message, as this is the top left of the Gui, not the client rect
		if (IsIconic(this.hwnd))	; do not update coords if window minimized
			return
		WinGetPos, x, y, , , % "ahk_id " this.hwnd
		if (x != "" && y != ""){
			this.CurrentPos := {x: x, y: y}
			this._SaveSettings()
		}
	}
	
	_OnSize(wParam, lParam, msg, hwnd){
		this.CurrentSize.h := HiWord(lParam)
		this.CurrentSize.w := LoWord(lParam)
		this._SaveSettings()
	}
	
	; The user clicked the "Add Plugin" button
	_AddPlugin(){
		this.CurrentProfile._AddPlugin()
	}
	
	; We wish to change profile. This may happen due to user input, or application changing
	; This is the function which ultimately decides which profiles should be active...
	; ... and which profiles should be "PreLoaded" (InputThread running, but detection suspended)
	; Save param can be set to 0 to not save when changing profile ...
	; ... eg so that when _LoadSettings() calls ChangeProfile, we do not save while loading.
	; ChangeProfile will accept the profile id of the current profile...
	; ... which will cause it to re-evaluate which profiles are inherited or linked
	ChangeProfile(id := 0, save := 1){
		if (id == 0){
			; No passed ID, assume current profile
			; Used to refresh state of linked / inherited profiles etc
			id := this.CurrentPID
		}
		if (!ObjHasKey(this.Profiles, id))
			return 0
		new_profile := this.Profiles[id]
		; Check if there is currently an active profile
		if (IsObject(this.CurrentProfile)){
			; A profile is currently active, de-activate old profiles.
			OutputDebug % "UCR| Changing Profile from " this.CurrentProfile.Name " to: " new_profile.Name
			
			; Make the Gui of the current profile invisible
			this.CurrentProfile._Hide()
			
		} else {
			OutputDebug % "UCR| Changing Profile for first time to: " new_profile.Name
		}
		
		; Reset the highlights in the ProfileToolbox
		this._ProfileToolbox.ResetProfileColors()

		; Change current profile to new profile
		this.CurrentProfile := new_profile
		this.CurrentPID := id

		new_profile_states := this._BuildNewProfileStates(id)

		; Stop any active Profiles that need to be stopped
		; Anything that is state 2 in _InputThreadStates and not present in new_profile_states has to die...
		for old_pid, state in this._InputThreadStates {
			if (state != 2)
				continue
			this._SetProfileState(old_pid, new_profile_states[old_pid])
			new_profile_states.Delete(old_pid)	; This profile's new state has been set, remove it from the list
		}
		
		; Activate the new profile
		this._SetProfileState(id, 2)

		; Next Activate other profiles (eg Inherited, Global) that need to be active
		for new_pid, state in new_profile_states {
			if (state != 2)
				continue
			this._SetProfileState(new_pid, state)
		}
		
		; Beyond this point, time is not really a factor.
		; Profiles and their InputThreads should be in the correct state, and ready to process input
		; ToDo: Look into making some of the rest of this function into an Asynch timer?
		
		; Make the new profile's Gui visible
		this.CurrentProfile._Show()

		; Finally PreLoad any linked profiles
		for new_pid, state in new_profile_states {
			if (state != 1)
				continue
			this._SetProfileState(new_pid, state)
		}
		
		; Update Gui to reflect new current profile
		this.UpdateCurrentProfileReadout()
		this._ProfileToolbox.SelectProfileByID(id)
		
		; Set Profile Toolbox highlights for Global profile
		this._ProfileToolbox.SetProfileColor(1, {fore: 0x0, back: 0x00ff00})
		; Update InheritsFromParent checkbox in Profile Toolbox
		this._ProfileToolbox.SetProfileInherit(this.CurrentProfile.InheritsfromParent)
		
		WinSet,Redraw,,% "ahk_id " this._ProfileToolbox.hTreeview
		
		; Save settings
		if (save){
			this._ProfileChanged(this.CurrentProfile)
		}
		return 1
	}

	; These two functions work out, given a profile ID, which profiles need to be loaded and activated.
	; Takes into account profile inheritance, and "linked" profiles (those pointed to by ProfileSwitcher plugins)
	_BuildNewProfileStates(id){
		profile := this.Profiles[id]
		ret := this.__BuildNewProfileStates(id)
		if (profile.InheritsFromParent && profile.ParentProfile){
			ret[profile.ParentProfile] := 2	; Add the parent profile, and set it to state 2 (Active)
			ret := this.__BuildNewProfileStates(profile.ParentProfile, ret)	; Add profiles which are linked to the parent
		}
		ret := this.__BuildNewProfileStates(1, ret)	; Add profiles which are linked to the Global profile
		;ret[id] := 2	; Make sure the new profile is in the list, and that it is set to Active
		ret.Delete(id)	; Make sure that the new profile itself did not make it into the list
		ret[1] := 2		; The Global profile is always active
		return ret
	}
	__BuildNewProfileStates(id, merge := 0){
		if (merge == 0)
			ret := {}
		else
			ret := merge.clone()
		profile := this.Profiles[id]
		for i, unused in profile._LinkedProfiles {
			ret[i] := 1	; Add the new profile to the list, and set it's state to 1 (PreLoaded)
		}
		return ret
	}

	; Tells a profile to change State
	; Also updates UCR's cache of profile states, and updates the ProfileToolBox to reflect the new state
	_SetProfileState(id, state){
		; Update ProfileToolbox display
		if (state == 2){
			if (id == this.CurrentPID){
				; Profile is Active as it is the Current Profile
				this._ProfileToolbox.SetProfileColor(id, {fore: 0xffffff, back: 0xff9933})	; Fake default selection box
			} else {
				; Profile is Active as it is Inherited by the Current Profile
				this._ProfileToolbox.SetProfileColor(id, {fore: 0x0, back: 0x00ffaa})
			}
		} else if (state == 1){
			; Profile is PreLoaded
			this._ProfileToolbox.SetProfileColor(id, {fore: 0x0, back: 0x00bfff})
		} else {
			; Profile is InActive
			this._ProfileToolbox.SetProfileColor(id, {fore: 0x0, back: 0xffffff})
		}
		
		; Change the state of the Profile
		if (this._InputThreadStates[id] != state){
			this.Profiles[id].SetState(state)
			this._InputThreadStates[id] := state
		}
	}
	
	; The user changed the InheritsFromParent setting for a profile
	; Reload profiles as appropriate, and save settings
	SetProfileInheritsState(id, state){
		this.profiles[id].InheritsFromParent := state
		; Change to the Current Profile, to force load of inherited profile
		; This will also force a save of settings
		this.ChangeProfile(this.CurrentPID)
	}
	
	; Called when the user changes the setting in a ProfileSwitcher plugin
	ProfileLinksChanged(){
		this.ChangeProfile(this.CurrentPID)
		WinSet,Redraw,,% "ahk_id " this._ProfileToolbox.hTreeview
	}
	
	UpdateCurrentProfileReadout(){
		GuiControl, % this.hTopPanel ":", % this.hCurrentProfile, % this.BuildProfilePathName(this.CurrentPID)
	}
	
	BuildProfilePathName(id){
		if (!ObjHasKey(this.profiles, id))
			return ""
		str := this.Profiles[id].Name
		while (this.Profiles[id].ParentProfile != 0){
			p := this.Profiles[id], pp := this.Profiles[p.ParentProfile]
			str := pp.Name " >> " str
			id := pp.id
		}
		return str
	}
	
	; Some aspect of the Profile Tree changed - eg structure or names of profiles in tree
	; Rebuild the tree
	UpdateProfileToolbox(){
		this._ProfileToolbox.BuildProfileTree()
		this.FireProfileTreeChangeCallbacks()
	}
	
	SubscribeToProfileTreeChange(hwnd, callback){
		this._ProfileTreeChangeSubscriptions[hwnd] := callback
	}
	
	UnSubscribeToProfileTreeChange(hwnd){
		this._ProfileTreeChangeSubscriptions.Delete(hwnd)
	}
	
	; Request notification of input activity.
	; Mainly for use by OneSwitch plugin
	SubscribeToInputActivity(hwnd, profile_id, callback){
		this._InputActivitySubscriptions[hwnd] := {callback: callback, profile_id: profile_id}
	}
	
	UnSubscribeToInputActivity(hwnd, profile_id){
		this._InputActivitySubscriptions.Delete(hwnd)
	}
	
	_RegisterGuiControl(ctrl, delete := 0){
		if (delete){
			this.BindControlLookup.Delete(ctrl.id)
		} else {
			;OutputDebug % "UCR| Registering GuiControl "
			this.BindControlLookup[ctrl.id] := ctrl
		}
	}
	
	; There was input activity on a profile
	; This is fired after the input is processed, and is solely for the purpose of UCR being able to detect that activity is happening.
	_InputEvent(ControlGuid, state){
		for hwnd, obj in this._InputActivitySubscriptions {
			cb := obj.callback, profile_id := obj.profile_id
			if (IsObject(obj.callback)  && ObjHasKey(this._InputThreadStates, obj.profile_id))
				obj.callback.Call(ControlGuid, state)
		}
	}
	
	FireProfileTreeChangeCallbacks(){
		for hwnd, cb in this._ProfileTreeChangeSubscriptions {
			if (IsObject(cb))
				cb.Call()
		}
	}
	
	; Update hPluginSelect with a list of available Plugins
	_UpdatePluginSelect(){
		this.PluginList := []
		str := ""
		i := 1
		for type, obj in this.PluginDetails {
			if (i > 1)
				str .= "|"
			str .= type "     - " obj.Description
			this.PluginList.push(type)
			if (i == 1){
				str .= "|"
			}
			i++
		}
		GuiControl,  % this.hTopPanel ":", % this.hPluginSelect, % str
	}
	
	; User clicked add new profile button
	_AddProfile(parent := 0){
		name := this._GetProfileName()
		if (name = 0)
			return
		id := this._CreateProfile(name, 0, parent)
		if (!IsObject(this.ProfileTree[parent]))
			this.ProfileTree[parent] := []
		this.ProfileTree[parent].push(id)
		this.UpdateProfileToolbox()
		this.ChangeProfile(id)
	}
	
	RenameProfile(id){
		if (!ObjHasKey(this.Profiles, id))
			return 0
		name := this._GetProfileName()
		if (name = 0)
			return 0
		this.Profiles[id].Name := name
		this.UpdateProfileToolbox()
		this.UpdateCurrentProfileReadout()
		this._SaveSettings()
	}
	
	MoveProfile(profile_id, parent_id, after){
		if (parent_id == "")
			parent_id := 0
		OutputDebug % "UCR| MoveProfile: profile: " profile_id ", parent: " parent_id ", after: " after
		; Do not allowing move of default or global profile
		if (profile_id < 3 || !ObjHasKey(this.Profiles, profile_id))
			return 0
		; Make sure parent_id is 0 or a valid profile_id
		if (parent_id != 0 && !ObjHasKey(this.Profiles, parent_id))
			return 0
		; Make sure requested move is valid
		if (after = 1 || (parent_id = 0 && after == "First") || parent_id == 1 || parent_id == 2)
			return 0
		
		profile := this.Profiles[profile_id]
		; Remove from old parent list
		for k, v in this.ProfileTree[profile.ParentProfile] {
			if (v == profile_id){
				this.ProfileTree[profile.ParentProfile].Remove(k)
				break
			}
		}
		; Add to new parent list
		if (!IsObject(this.ProfileTree[parent_id]))
			this.ProfileTree[parent_id] := []
		if (after == ""){
			this.ProfileTree[parent_id].push(profile_id)
		} else if (after == "First"){
			this.ProfileTree[parent_id].InsertAt(1, profile_id)
		} else {
			Loop % this.ProfileTree[parent_id].length(){
				if (this.ProfileTree[parent_id, A_Index] = after){
					this.ProfileTree[parent_id].InsertAt(A_Index + 1, profile_id)
					break
				}
			}
		}
		profile.ParentProfile := parent_id
		this.UpdateProfileToolbox()
		this.UpdateCurrentProfileReadout()
		this._SaveSettings()
	}
	
	; Creates a new profile and assigns it a unique ID, if needed.
	_CreateProfile(name, id := 0, parent := 0){
		if (id = 0){
			id := CreateGUID()
		}
		profile := new _Profile(id, name, parent)
		this.Profiles[id] := profile
		return id
	}
	
	; user clicked the Delete Profile button
	_DeleteProfile(){
		id := this.CurrentPID
		if (id = 1 || id = 2)
			return
		pp := this.CurrentProfile.ParentProfile
		if pp != 0
			newprofile := pp
		else
			newprofile := 2
		this._DeleteChildProfiles(id)
		this.__DeleteProfile(id)
		this.UpdateProfileToolbox()
		this.ChangeProfile(newprofile)
	}
	
	; Actually deletes a profile
	__DeleteProfile(id){
		; Remove profile's entry from ProfileTree
		profile := this.Profiles[id]
		profile.OnClose()
		treenode := this.ProfileTree[profile.ParentProfile]
		for k, v in treenode {
			if (v == id){
				treenode.Remove(k)	; Use Remove, so indexes shuffle down.
				; If array is empty, remove from tree
				if (!treenode.length())
					this.ProfileTree.Delete(profile.ParentProfile)	; Sparse array - use Delete instead of Remove
				break
			}
		}
		; Kill profile object
		this.profiles.Delete(profile.id)
	}
	
	; Recursively deletes child profiles
	_DeleteChildProfiles(id){
		for i, profile in this.Profiles{
			if (profile.ParentProfile = id){
				this._DeleteChildProfiles(profile.id)
				this.__DeleteProfile(profile.id)
			}
		}
	}
	
	; Load a list of available plugins
	_LoadPluginList(){
		Loop, Files, % A_ScriptDir "\Plugins\*.ahk", FR
		{
			FileRead,plugincode,% A_LoopFileFullPath
			RegExMatch(plugincode,"i)class\s+(\w+)\s+extends\s+",classname)
			already_loaded := 0
			; Check if the classname already exists.
			if (IsObject(_UCR.Classes.Plugins[classname1])){
					; Existing class extends plugin
					; Class has been included via other means (eg to debug it), so do not try to include again.
					already_loaded := 1
			}
			;dllthread := AhkThread("#NoTrayIcon`ntest := new " classname1 "()`ntype := test.type, description := test.description, autoexecute_done := 1`nLoop {`nsleep 10`n}`nclass _Plugin {`n}`n" plugincode)
			dllthread := AhkThread("#NoTrayIcon`ntest := new " classname1 "()`ntype := test.type, description := test.description, autoexecute_done := 1`nLoop {`nsleep 10`n}`nclass _UCR {`nclass Classes{`nclass Plugin{`n}`n}`n}`n" plugincode)
			
			t := A_TickCount + 1000
			While !(autoexecute_done := dllthread.ahkgetvar.autoexecute_done) && A_TickCount < t
				Sleep 10
			if (autoexecute_done){
				Type := dllthread.ahkgetvar.Type
				Description := dllthread.ahkgetvar.Description
			}
			ahkthread_free(dllthread)
			dllthread := ""
			if (!autoexecute_done){
				MsgBox % "Plugin " classname1 " failed to load. Removing from list."
				continue
			} else if (Type == "" || Description == ""){
				MsgBox % "Plugin " classname1 " does not have a type or description. Removing from list."
				continue
			}
			this.PluginDetails[Type] := {Description: Description, ClassName: classname1}
			if (!already_loaded)
				AddFile(A_LoopFileFullPath, 1)
		}
	}
	
	; Load settings from disk
	_LoadSettings(){
		FileRead, j, % this._SettingsFile
		if (j = ""){
			; Settings file empty or not found, create new settings
			j := {"CurrentProfile":"2", "SettingsVersion": this.SettingsVersion, "ProfileTree": {0: [1, 2]}, "Profiles":{"1":{"Name": "Global", "ParentProfile": "0"}, "2": {"Name": "Default", "ParentProfile": "0"}}}
		} else {
			OutputDebug % "UCR| Loading JSON from disk"
			j := JSON.Load(j)
		}
		
		; Check if Settings file is a compatible version
		if (j.SettingsVersion != this.SettingsVersion){
			; No, try to upgrade
			j := this._UpdateSettings(j)
			; Did upgrade succeed?
			if (j.SettingsVersion != this.SettingsVersion){
				; No, warn and exit.
				msgbox % this._SettingsFile " is incompatible with this version of UCR."
				ExitApp
			}
		}
		return j
	}
	
	; Save settings to disk
	; ToDo: improve. Only the thing that changed needs to be re-serialized. Cache values.
	_SaveSettings(){
		this._SavingToDisk := 1
		fn := this.SaveSettingsTimerFn
		SetTimer, % fn, Off
		SetTimer, % fn, -1000
	}
	
	__SaveSettings(){
		OutputDebug % "UCR| Saving JSON to disk"
		obj := this._Serialize()
		SettingsFile := this._SettingsFile
		FileReplace(JSON.Dump(obj, ,true), SettingsFile)
		this._SavingToDisk := 0
	}
	
	; If SettingsVersion changes, this handles converting the INI file to the new format
	_UpdateSettings(obj){
		if (obj.SettingsVersion != "0.0.6"){
			msgbox % "This version of UCR does not support INI files from previous versions.`nPlease back up or delete your INI file and re-run UCR."
			ExitApp
		}
		; Default to making no changes
		return obj
	}
	; A child profile changed in some way
	_ProfileChanged(profile){
		this._SaveSettings()
	}
	
	; Turns on or off GameBind mode. In GameBind mode, all outputs are delayed
	SetGameBindState(state){
		if (state){
			if (this._CurrentState == this._State.Normal){
				this._CurrentState := this._State.GameBind
				return 1
			}
		} else {
			if (this._CurrentState == this._State.GameBind){
				this._CurrentState := this._State.Normal
				return 1
			}
		}
		return 0
	}
	
	; A plugin is requesting that we register a binding with an input thread
	_RequestBinding(ctrl){
		bo := ctrl._Serialize()
		if (!IsObject(bo)){
			OutputDebug % "UCR| Warning! Tried to _RequestBinding without a BindObject set!"
			return
		}
		outputdebug % "UCR| UCRMain _RequestBinding - bo.Binding[1]: " bo.Binding[1] ", DeviceID: " bo.DeviceID ", IOClass: " bo.IOClass
		;ctrl.ParentPlugin.ParentProfile.InputThread.UpdateBinding(ctrl.id, bo)
		ctrl.ParentPlugin.ParentProfile.InputThread.UpdateBinding(ctrl.id, ObjShare(bo))
	}
	
	; A plugin is requesting a new Binding via Bind Mode (User pressing inputs they wish to bind)
	; Can also be used to request a binding for outputs, if the output has a corresponding input IOClass (eg Keyboard + Mouse)
	; IOClassMappings defines for each IOClass detected as input, what IOClass to map it to...
	; ... this is generally itself or a corresponding output IOClass
	; eg a request for a AHK_KBM_Output IOClass Binding would use AHK_KBM_Input as the detection IOClass
	RequestBindMode(IOClassMappings, callback){
		if (this._CurrentState == this._State.Normal){
			this._CurrentState := this._State.InputBind
			; De-Activate all active profiles, to make sure they do not interfere with the bind process
			this._DeActivateProfiles()
			; Start Bind Mode, pass callback to _BindModeEnded which gets fired when user makes a selection
			this._BindModeHandler.StartBindMode(IOClassMappings, this._BindModeEnded.Bind(this, callback))
			return 1
		}
	}
	
	; Bind Mode ended. Pass the Primitive BindObject and it's IOClass back to the GuiControl that requested the binding
	_BindModeEnded(callback, primitive){
		OutputDebug % "UCR| UCR: Bind Mode Ended. Binding[1]: " primitive.Binding[1] ", DeviceID: " primitive.DeviceID ", IOClass: " this.SelectedBinding.IOClass
		this.ChangeProfile(this.CurrentPID, 0)	; Do not save on change profile, bind mode will already cause a save
		this._CurrentState := this._State.Normal
		callback.Call(primitive)
	}
	
	; Request a Mouse Axis Delta binding
	RequestDeltaBinding(delta){
		this._InputHandler.SetDeltaBinding(delta)
	}
	
	; DeActivates all profiles in the _InputThreadStates array
	; We don't want hotkeys or plugins active while in Bind Mode...
	; Use ChangeProfile() on the current profile to re-activate.
	_DeActivateProfiles(){
		for p_id, state in this._InputThreadStates {
			if (state == 2){
				this._SetProfileState(p_id, 1)
				outputdebug % "UCR| _DeActivateProfiles changing state of profile " this.Profiles[p_id].name " from Active to PreLoaded"
			}
		}
	}

	; Picks a suggested name for a new profile, and presents user with a dialog box to set the name of a profile
	_GetProfileName(){
		c := 1
		found := 0
		while (!found){
			found := 1
			for id, profile in this.Profiles {
				if (profile.Name = "Profile " c){
					c++
					found := 0
					break
				}
			}
		}
		suggestedname := "Profile " c
		; Allow user to pick name
		prompt := "Enter a name for the Profile"
		coords := this.GetCenteredCoordinates(375, 130)
		InputBox, name, Add Profile, % prompt, ,,130,% coords.x,% coords.y,,, % suggestedname
		
		return (ErrorLevel ? 0 : name)
	}
	
	; Positions the specified window in the middle of the UCR GUI
	MoveWindowToCenterOfGui(hwnd){
		if (!WinExist("ahk_id " hwnd))
			return
		WinGetPos, cx, cy, cw, ch, % "ahk_id " hwnd
		WinGetPos, ux, uy, uw, uh, % "ahk_id " this.hwnd
		ux_mid := ux + (uw / 2), uy_mid := uy + (uh / 2)
		ox := (cw >= uw ? ux : (ux_mid - (cw / 2)))
		oy := (ch >= uh ? uy : (uy_mid - (ch / 2)))
		;Gui, % hwnd ":Show", % "x" ox " y" oy
		WinMove, % "ahk_id " hwnd,, ox, oy
	}
	
	; Given a width and height, returns coordinates that would center the window within the UCR window
	GetCenteredCoordinates(w,h){
		cw := w / 2, ch := h / 2
		WinGetPos, ux, uy, uw, uh, % "ahk_id " this.hwnd
		cx := ((uw / 2) - cw) + ux
		cy := ((uh / 2) - ch) + uy
		return {x: cx, y: cy}
	}

	MergeObject(src, patch){
		for k, v in patch {
			if (IsObject(v)){
				this.MergeObject(src[k], v)
			} else {
				src[k] := v
			}
		}
	}

	; Serialize this object down to the bare essentials for loading it's state
	_Serialize(){
		obj := {SettingsVersion: this.SettingsVersion
		, CurrentProfile: this.CurrentPID
		, CurrentSize: this.CurrentSize
		, CurrentPos: this.CurrentPos
		, UserSettings: this.UserSettings
		, Profiles: {}
		, ProfileTree: this.ProfileTree}
		for id, profile in this.Profiles {
			obj.Profiles[id] := profile._Serialize()
		}
		return obj
	}
	
	; Load this object from simple data strutures
	_Deserialize(obj){
		this._SetMenuState()
		this.Profiles := {}
		this.ProfileTree := obj.ProfileTree
		for id, profile in obj.Profiles {
			this._CreateProfile(profile.Name, id, profile.ParentProfile)
			this.Profiles[id]._Deserialize(profile)
			this.Profiles[id]._Hide()
		}
		;this.CurrentProfile := this.Profiles[obj.CurrentProfile]
		
		if (IsObject(obj.CurrentSize))
			this.CurrentSize := obj.CurrentSize
		if (IsObject(obj.CurrentPos))
			this.CurrentPos := obj.CurrentPos
	}
	
	; Holds Classes for GuiControls and IOControls
	class Classes {
		class GuiControls {
			#Include Classes\GuiControls\GuiControl.ahk
			#Include Classes\GuiControls\ProfileSelect.ahk
			#Include Classes\GuiControls\BannerMenu.ahk
			#Include Classes\GuiControls\IOControl.ahk
			#Include Classes\GuiControls\InputButton.ahk
			#Include Classes\GuiControls\InputAxis.ahk
			#Include Classes\GuiControls\InputDelta.ahk
			#Include Classes\GuiControls\OutputButton.ahk
			#Include Classes\GuiControls\OutputAxis.ahk
		}
		
		class IOClasses {
			#Include Classes\GuiControls\IOClasses\BindObject.ahk
			#Include Classes\GuiControls\IOClasses\IOClassBase.ahk
			#Include Classes\GuiControls\IOClasses\AHK.ahk
			#Include Classes\GuiControls\IOClasses\RawInput_Mouse_Delta.ahk
			#Include Classes\GuiControls\IOClasses\vGen.ahk
			#Include Classes\GuiControls\IOClasses\Titan.ahk
		}
		
		#Include Classes\Plugin.ahk
	}
}

; Dummy label for hotekys to bind to etc
UCR_DUMMY_LABEL:
	return