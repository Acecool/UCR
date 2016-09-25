/*
	UCR Main bootstrap file
	
	The recommended editor for UCR is AHK Studio
	https://autohotkey.com/boards/viewtopic.php?t=300
*/
#SingleInstance force

OutputDebug DBGVIEWCLEAR
SetBatchLines, -1
global UCR	; set UCR as a super-global NOW so that it is super-global while the Constructor is executing
new _UCR()	; The first line of the constructor will store the class instance in the UCR super-global
return

; If you wish to be able to debug plugins, include them in UCRDebug.ahk
; The file does not have to exist, and this line can be safely commented out
#Include *iUCRDebug.ahk

; Include the main classes
#Include Classes\UCRMain.ahk
#Include Classes\Menu.ahk
#Include Classes\Minimizer.ahk
#Include Classes\ProfileToolbox.ahk
#Include Classes\ProfilePicker.ahk
#Include Classes\ProfileTreeBase.ahk
#Include Classes\InputHandler.ahk
#Include Classes\BindModeHandler.ahk
#Include Classes\Profile.ahk

#include Libraries\JSON.ahk

/*
	; Block commented includes are recognized by AHKStudio
	; These lines merely make these files appear in AHKStudio's "Project Explorer"
	; This DOES NOT mean you will be able to debug them
	
	; Threads
	#Include Threads\BindModeThread.ahk
	#Include Threads\MessageFilterThread.ahk
	#Include Threads\ProfileInputThread.ahk
	
	; Libraries
	#Include Libraries\StickOps\StickOps.ahk
	;#Include Libraries\TTS\TTS.ahk
	
	; Include Plugins in case they are not in UCRDebug.ahk
	;#include Plugins\Core\AxisInitializer.ahk
	;#include Plugins\Core\AxisMerge.ahk
	;#include Plugins\Core\AxisToAxis.ahk
	;#include Plugins\Core\AxisToButton.ahk
	;#include Plugins\Core\BigEmptyPlugin.ahk
	;#include Plugins\Core\ButtonToAxis.ahk
	#include Plugins\Core\ButtonToButton.ahk
	;#include Plugins\Core\CodeRunner.ahk
	;#include Plugins\Core\GameBind.ahk
	;#include Plugins\Core\MouseToJoy.ahk
	;#include Plugins\Core\OneSwitchProfileSwitcher.ahk
	;#include Plugins\Core\OneSwitchPulse.ahk
	;#include Plugins\Core\ProfileSwitcher.ahk
	;#include Plugins\Core\ProfileSpeaker.ahk
*/

; Called if the user closes the GUI
GuiClose(hwnd){
	UCR.GuiClose(hwnd)
}

; Func allows the MessageHandler thread to register messages in this thread
UCR_OnMessageCreate(msg,hwnd,fnPtr){
	OnMessage(msg+0,hwnd+0,Object(fnPtr+0))
}