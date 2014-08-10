; Helper functions
class CWindow {
	WindowStatus := { IsMinimized: 0, IsMaximized: 0, Width: 0, Height: 0 }
	ChildWindows := []
	
	__New(title := "", options := "", parent := 0){
		this.Parent := parent
		if (this.Parent){
			options .= " +Parent" . this.Parent.Gui.Hwnd
		}
		this.Gui := GuiCreate(title, options, this)
		if (this.Parent){
			this.Parent.ChildWindows[this.Gui.Hwnd] := this
		}
	}
	
	/*
	__Get(aName){
		; IMPORTANT! SINGLE equals sign (=) is a CASE INSENSITIVE comparison!
		if (aName = "hwnd" && IsObject(this.Gui)){
			return this.Gui.Hwnd
		} else if (aName = "gui"){
			return this.Gui
		}
		;else if (aName = "options"){
		;	return this._Options
		;}
	}
	*/
	
	; Define interface
	ChildMinimized(hwnd){
		
	}

	ChildMaximized(hwnd){
		
	}

	ChildRestored(hwnd){
		
	}

	OnMinimize(width, height){
		this.WindowStatus.IsMinimized := 1
		this.WindowStatus.IsMaximized := 0
		if (this.Parent){
			this.Parent.ChildMinimized(this.Gui.Hwnd)
		}
	}
	
	OnMaximize(width, height){
		if (!this.WindowStatus.IsMaximized && !this.WindowStatus.IsMinimized){
			this.OnResize()
		}
		this.WindowStatus.IsMinimized := 0
		this.WindowStatus.IsMaximized := 1
		if (this.Parent){
			this.Parent.ChildMaximized(this.Gui.Hwnd)
		}
	}
	
	OnRestore(width, height){
		if (this.WindowStatus.IsMaximized){
			this.OnResize()
		}
		this.WindowStatus.IsMinimized := 0
		this.WindowStatus.IsMaximized := 0
		if (this.Parent){
			this.Parent.ChildRestored(this.Gui.Hwnd)
		}
	}

	OnClose(){
		if(this.Parent){
			this.Parent.ChildClosed(this.Gui.Hwnd)
		}
	}
	
	ChildClosed(hwnd){
		this.ChildWindows.Remove(hwnd)
		this.OnReSize()
	}

	; OnResize is different from OnSize in that it should only trigger when the dimensions actually changed, or the shape of the contents changed.
	; This should not include minimze / restore
	OnResize(){
		; Dimensions have physically changed
	}
	
	; eventinfo = http://msdn.microsoft.com/en-gb/library/windows/desktop/ms632646(v=vs.85).aspx
	OnSize(gui := 0, eventInfo := 0, width := 0, height := 0){
		if (eventinfo == 0x0){
			; Event 0x0 - The window has been resized, but neither the SIZE_MINIMIZED nor SIZE_MAXIMIZED value applies.
			if (this.WindowStatus.IsMinimized || this.WindowStatus.IsMaximized){
				; Restore
				this.OnRestore(width, height)
			} else {
				if ( (width && this.WindowStatus.Width != width) || (height && this.WindowStatus.Height != height) ){
					; Dimensions have changed (Or new window)
					this.WindowStatus.Width := width
					this.WindowStatus.Height := height
					this.OnResize()
				}
			}
		} else if (eventinfo == 0x1){
			; Event 0x1 - The window has been minimized.
			if (!this.WindowStatus.IsMinimized){
				this.OnMinimize(width, height)
			}
		} else if(eventinfo == 0x2){
			; Event 0x2 - The window has been maximized.
			if (!this.WindowStatus.IsMaximized){
				this.OnMaximize(width, height)
			}
		}
	}
	
	; Like Gui.Show, but relative to the viewport (ie 0,0 is top left of canvas, not top left of current view)
	; Also uses assoc array (ie {x: 0, y: 0} instead of a string
	ShowRelative(options := 0){
		if (!options){
			options := {x: 0, y: 0, w: 200, h: 50}
		}
		if (this.Parent){
			offset := this.GetWindowOffSet(this.Parent.Gui.Hwnd)
		} else {
			offset := {x: 0, y: 0}
		}
		str := ""
		ctr := 0
		For key, value in options {
			if (key = "x"){
				value += offset.x
			} else if (key = "y"){
				value += offset.y
			}
			if (ctr){
				str .= " "
			}
			str .= key . value
			ctr++
		}
		this.Gui.Show(str)
	}
	
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

	; Get the offset of the canvas of a window due to scrollbar position
	GetWindowOffSet(hwnd){
		ret := {x: 0, y: 0}
		info := this.GetScrollInfos(hwnd)
		if (info[0] == 0){
			; No x scroll bar
			ret.x := 0
		} else {
			ret.x := info[0].nPos * -1
		}
		
		if (info[1] == 0){
			; No y scroll bar
			ret.y := 0
		} else {
			ret.y := info[1].nPos * -1
		}
		
		return ret
	}
	
	; Wrapper for GetParent DllCall
	GetParent(hwnd){
		return DllCall("GetParent", "Ptr", hwnd)
	}
	
	; Gets position of a child window relative to it's parent's RECT
	GetClientPos(){
		pos := this.GetPos(this.Gui.Hwnd)
		offset := this.ScreenToClient(this.Parent.Gui.Hwnd, x, y)
		pos.x += offset.x
		pos.y += offset.y
		return pos
	}
}
