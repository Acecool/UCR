; Autohotkey V2 code!!
; Uses Fincs "Proposed New GUI API for AutoHotkey v2": http://ahkscript.org/boards/viewtopic.php?f=37&t=2998

#SingleInstance Force

MainWindow := new MainWindow()

; Is it possible to move this inside the class somehow?
OnMessage(0x115, "OnScroll") ; WM_VSCROLL
OnMessage(0x114, "OnScroll") ; WM_HSCROLL
#IfWinActive ahk_group MyGui
~WheelUp::
~WheelDown::
~+WheelUp::
~+WheelDown::
    ; SB_LINEDOWN=1, SB_LINEUP=0, WM_HSCROLL=0x114, WM_VSCROLL=0x115
    MainWindow.OnScroll(InStr(A_ThisHotkey,"Down") ? 1 : 0, 0, GetKeyState("Shift") ? 0x114 : 0x115, MainWindow.ScrollableSubWindow.Hwnd)
return
#IfWinActive

OnScroll(wParam, lParam, msg, hwnd){
	global MainWindow
	MainWindow.ScrollableSubWindow.OnScroll(wParam, lParam, msg, hwnd)
}

class MainWindow extends Window {
	
	__New(){
		this.Gui := GuiCreate("Outer Parent","Resize",this)
		this.Gui.AddButton("Add","gAddClicked")
		this.debug := this.Gui.AddLabel("debug: ","w500")
		
		this.Gui.Show("x0 y0 w600 h500")
		this.Hwnd := this.Gui.Hwnd
		
		; Set up child GUIs
		this.ScrollableSubWindow := new ScrollingSubWindow(this)
		this.ScrollableSubWindow.OnSize()
		
		this.OnSize()
		GroupAdd("MyGui", "ahk_id " . this.Hwnd)

	}

	AddClicked(){
		this.ScrollableSubWindow.AddClicked()
	}
	
	OnSize(){
		; Size Scrollable Child Window
		;Critical

		; Lots of hard wired values - would like to eliminate these!
		r := this.GetClientRect(this.Hwnd)
		r.b -= 50	; How far down from the top of the main gui does the child window start?
		; Subtract border widths
		r.b -= r.t + 6
		r.r -= r.l + 6

		; Client rect seems to not include scroll bars - check if they are showing and subtract accordingly
		sbv := this.GetScrollBarVisibility(this.ScrollableSubWindow.Hwnd)
		if (sbv.x){
			r.r -= 16
		}

		if (sbv.y){
			r.b -= 16
		}
		
		this.ScrollableSubWindow.Gui.Show("x0 y50 w" . r.r . " h" . r.b)
	}
	
	OnScroll(wParam, lParam, msg, hwnd){
		this.ScrollableSubWindow.OnScroll(wParam, lParam, msg, hwnd)
	}
}

class ScrollingSubWindow extends Window {
	__New(parent){
		this.parent := parent
		this.ChildWindows := []

		this.Gui := GuiCreate("","-Border 0x300000 Parent" . this.parent.Hwnd, this)
		this.Gui.Show("x0 y50 w10 h10")
		this.Hwnd := this.Gui.Hwnd
		
		;OnMessage(0x115, OnScroll()) ; WM_VSCROLL
		;OnMessage(0x114, OnScroll()) ; WM_HSCROLL

	}
	
	AddClicked(){
		child := new ChildWindow(this)
		this.ChildWindows[child.Hwnd] := child
	}
	
	ChildClosed(hwnd){
		this.ChildWindows.RemoveAt(hwnd)
		this.OnSize()
	}
	
	OnSize(){
		static SIF_RANGE := 0x1, SIF_PAGE := 0x2, SIF_DISABLENOSCROLL := 0x8, SB_HORZ := 0, SB_VERT := 1
		
		scroll_status := this.GetScrollInfos(this.Hwnd)

		viewport := {Top: 0, Left: 0, Right: 0, Bottom: 0}
		ctr := 0
		For key, value in this.ChildWindows {
			pos := this.ChildWindows[key].GetClientPos()
			bot := pos.y + pos.h
			if (pos.y < viewport.Top){
				viewport.Top := pos.y
			}
			if (pos.x < viewport.Left){
				viewport.Left := pos.x
			}
			if (bot > viewport.Bottom){
				viewport.Bottom := bot
			}
			right := pos.x + pos.w
			if (right > viewport.Right){
				viewport.Right := right
			}
			
			this.ChildWindows[key].SetDesc("b: " bot ", y: " pos.y ", h: " pos.h)
			ctr++
		}
		if (!ctr){
			; Update horizontal scroll bar.
			this.SetScrollInfo(this.Hwnd, SB_HORZ, {nMax: 0, nPage: 0, fMask: SIF_RANGE | SIF_PAGE })
			; Update vertical scroll bar.
			this.SetScrollInfo(this.Hwnd, SB_VERT, {nMax: 0, nPage: 0, fMask: SIF_RANGE | SIF_PAGE })
			return
		}
		
		ScrollWidth := viewport.Right - viewport.Left
		ScrollHeight := viewport.Bottom - viewport.Top

		; GuiHeight = size of client area
		g := this.GetClientRect(this.Hwnd)
		GuiWidth := g.r
		GuiHeight := g.b

		this.parent.SetDesc("SUB_GUI DEBUG: Lowest Widget Bottom: " . viewport.Bottom . ", GuiHeight: " . GuiHeight)

		; Update horizontal scroll bar.
		this.SetScrollInfo(this.Hwnd, SB_HORZ, {nMax: ScrollWidth, nPage: GuiWidth, fMask: SIF_RANGE | SIF_PAGE })

		; Update vertical scroll bar.
		this.SetScrollInfo(this.Hwnd, SB_VERT, {nMax: ScrollHeight, nPage: GuiHeight, fMask: SIF_RANGE | SIF_PAGE })
		
		; If being window gets bigger while child items are clipped, drag the child items into view
		if (viewport.Left < 0 && viewport.Right < GuiWidth){
			x := Abs(viewport.Left) > GuiWidth-viewport.Right ? GuiWidth-viewport.Right : Abs(viewport.Left)
		}
		if (viewport.Top < 0 && viewport.Bottom < GuiHeight){
			y := Abs(viewport.Top) > GuiHeight-viewport.Bottom ? GuiHeight-viewport.Bottom : Abs(viewport.Top)
		}
		if (x || y){
			this.ScrollWindow(this.Hwnd, x, y)
		}


	}

	OnScroll(wParam, lParam, msg, hwnd){
		static SCROLL_STEP := 10
		static SIF_ALL := 0x17

		bar := msg - 0x114 ; SB_HORZ=0, SB_VERT=1

		scroll_status := this.GetScrollInfos(this.Hwnd)
		
		; If call returns no info, quit
		if (scroll_status[bar] == 0){
			return
		}
		
		rect := this.GetClientRect(hwnd)
		new_pos := scroll_status[bar].nPos

		action := wParam & 0xFFFF
		if (action = 0){ ; SB_LINEUP
			;tooltip % "NP: " new_pos
			new_pos -= SCROLL_STEP
		} else if (action = 1){ ; SB_LINEDOWN
			; Wheel down
			new_pos += SCROLL_STEP
		} else if (action = 2){ ; SB_PAGEUP
			; Page Up ?
			new_pos -= rect.b - SCROLL_STEP
		} else if (action = 3){ ; SB_PAGEDOWN
			; Page Down ?
			new_pos += rect.b - SCROLL_STEP
		} else if (action = 5 || action = 4){ ; SB_THUMBTRACK || SB_THUMBPOSITION
			; Drag handle
			new_pos := wParam >> 16
		} else if (action = 6){ ; SB_TOP
			; Home?
			new_pos := scroll_status[bar].nMin ; nMin
		} else if (action = 7){ ; SB_BOTTOM
			; End?
			new_pos := scroll_status[bar].nMax ; nMax
		} else {
			return
		}
		
		min := scroll_status[bar].nMin ; nMin
		max := scroll_status[bar].nMax - scroll_status[bar].nPage ; nMax-nPage
		new_pos := new_pos > max ? max : new_pos
		new_pos := new_pos < min ? min : new_pos
		
		old_pos := scroll_status[bar].nPos ; nPos
		
		x := y := 0
		if bar = 0 ; SB_HORZ
			x := old_pos-new_pos
		else
			y := old_pos-new_pos

		; Scroll contents of window and invalidate uncovered area.
		this.ScrollWindow(hwnd, x, y)
		
		; Update scroll bar.
		tmp := scroll_status[bar]
		tmp.nPos := new_pos
		tmp.fMask := SIF_ALL

		this.SetScrollInfo(hwnd, bar, tmp)
		return
	}

}

; A Child Window Within the scrolling sub-window
class ChildWindow extends Window {
	__New(parent){
		this.parent := parent
		this.Gui := GuiCreate("Child","+Parent" . this.parent.Hwnd,this)
		this.Gui.AddLabel("I am " . this.Gui.Hwnd)	;this.Gui.Hwnd
		this.debug := this.Gui.AddLabel("debug: ", "w200")	;this.Gui.Hwnd
		this.Gui.Show("x0 y0 w200 h50")
		
		this.Hwnd := this.Gui.Hwnd
	}
	
	GetClientPos(){
		pos := this.GetPos(this.Hwnd)
		offset := this.ScreenToClient(this.parent.Hwnd, x, y)
		pos.x += offset.x
		pos.y += offset.y
		return pos
	}
	
	OnClose(){
		this.parent.ChildClosed(this.Hwnd)
	}
}

; Helper functions
class Window {
	; Wrapper for WinGetPos
	GetPos(hwnd){
		WinGetPos(x, y, w, h, "ahk_id " hwnd)
		return {x: x, y: y, w: w, h: h}
	}
	
	; Wrapper for GetClientRect DllCall
	; Gets "Client" (internal) area of a window
	GetClientRect(hwnd){
		VarSetCapacity(rect, 16, 0)
        DllCall("GetClientRect", "Ptr", hwnd, "Ptr", &rect)
        return {l: NumGet(rect, 0, "Int"), t: NumGet(rect, 4, "Int") , r: NumGet(rect, 8, "Int"), b: NumGet(rect, 12, "Int")}
	}
	
	; Wrapper for GetScrollInfo DllCall
	GetScrollInfo(hwnd, bar){
		static SIF_ALL := 0x17

	    VarSetCapacity(si, 28, 0)
	    NumPut(28, si) ; cbSize
	    NumPut(SIF_ALL, si, 4) ; fMask
	    if (DllCall("GetScrollInfo", "uint", hwnd, "int", bar, "uint", &si)){
			ret := {}
			ret.cbSize := NumGet(si, 0, "uint") ; cbSize
			ret.fMask := NumGet(si, 4, "uint") ; fMask
			ret.nMin := NumGet(si, 8, "int") ; nMin
			ret.nMax := NumGet(si, 12, "int") ; nMax
			ret.nPage := NumGet(si, 16) ; nPage
			ret.nPos := NumGet(si, 20) ; nPos
			ret.nTrackPos := NumGet(si, 24) ; nTrackPos
			return ret
		} else {
			return 0
		}
	}
	
	GetScrollInfos(hwnd){
		ret := []
		ret[0] := this.GetScrollInfo(hwnd, 0)
		ret[1] := this.GetScrollInfo(hwnd, 1)
		return ret
	}


	; Wrapper for SetScrollInfo DllCall
	SetScrollInfo(hwnd, bar, scrollinfo){
		VarSetCapacity(si, 28, 0)
		NumPut(28, si) ; cbSize
		

		if (scrollinfo.fMask){
			NumPut(scrollinfo.fMask, si, 4) ; fMask
		}
		if (scrollinfo.nMin){
			NumPut(scrollinfo.nMin, si, 8) ; nMin
		}
		if (scrollinfo.nMax){
			NumPut(scrollinfo.nMax, si, 12) ; nMax
		}
		if (scrollinfo.nPage){
			NumPut(scrollinfo.nPage, si, 16) ; nPage
		}
		if (scrollinfo.nPos){
			NumPut(scrollinfo.nPos, si, 20, "int") ; nPos
		}
		if (scrollinfo.nTrackPos){
			NumPut(scrollinfo.nTrackPos, si, 24) ; nTrackPos
		}
		return DllCall("SetScrollInfo", "uint", hwnd, "int", bar, "uint", &si, "int", 1)
	}

	; Wrapper for ScrollWindow DllCall
	ScrollWindow(hwnd, x, y){
		DllCall("ScrollWindow", "uint", hwnd, "int", x, "int", y, "uint", 0, "uint", 0)
	}

	; Wrapper for ScreenToClient DllCall
	; returns offset between screen and client coords
	ScreenToClient(hwnd, x, y){
		VarSetCapacity(pt, 16)
		NumPut(x,pt,0)
		NumPut(y,pt,4)
		DllCall("ScreenToClient", "uint", hwnd, "Ptr", &pt)
		x := NumGet(pt, 0, "long")
		y := NumGet(pt, 4, "long")
		
		return {x: x, y: y}
	}

	GetScrollBarVisibility(hwnd){
		static WS_HSCROLL := 0x00100000
		static WS_VSCROLL := 0x00200000

		ret := DllCall("GetWindowLong", "uint", hwnd, "int", -16)
		out := {}
		out.x := (ret & WS_HSCROLL) > 0
		out.y := (ret & WS_VSCROLL) > 0
		return out
	}

	SetDesc(str){
		if (this.debug){
			this.debug.Value := str
		}
	}

}
