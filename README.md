# NetworkInterfaceSwitcher
A command line utility for macOS that will switch the system's network interface priority.

## Building:
You can download a precompiled executable from the Github releases page. If you would like to build it yourself, a makefile is included.  

`make release`  

If you'd like the tool to run from anywhere on the command line, copy it to `/usr/local/bin`.

## Parameters:

### Switch
`-s Ethernet`  
Specify a network interface to swith to. Can be an exact match, or can match an element in a specified lookup file.

### Toggle
`-t toggle.txt`  
Toggle between the network interfaces in the toggle file. NetworkSwitcher will find the interface in the file with the highest priority, and switch to the next interface in the file. All interfaces specified in the toggle file must have exact matches.

### Lookup 
`-l lookup.txt`  
Specify a lookup file that defines shortcuts that can be used to shorhand the -s parameter. See lookup.txt for an example.