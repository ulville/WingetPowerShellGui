Set WinScriptHost = CreateObject("WScript.Shell")
scriptDir = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
batFile = scriptDir + "\run-ps1.bat"
' WScript.Echo( Chr(34) & batfile & Chr(34) & " " & Chr(34) & WScript.Arguments.Item(0) & Chr(34) )
WinScriptHost.Run Chr(34) & batfile & Chr(34) & " " & Chr(34) & WScript.Arguments.Item(0) & Chr(34), 0
Set WinScriptHost = Nothing