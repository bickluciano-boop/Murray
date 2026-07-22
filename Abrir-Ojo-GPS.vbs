Option Explicit

Dim shell, fso, base, command
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
base = fso.GetParentFolderName(WScript.ScriptFullName)
command = "pyw -3 """ & base & "\ojo_gps_app.py"""
shell.Run command, 0, False
