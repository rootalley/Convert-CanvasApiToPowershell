# PowerShell clients for the Canvas LMS API

## About
This project parses the Swagger specification for the [Instructure Canvas learning management system API] (https://canvas.instructure.com/doc/api/) to generate a PowerShell client for Canvas. Use at your own risk, or contribute to the project and make it better!

Forked from the [CanvasApis](https://github.com/squid808/CanvasApis) project by [Spencer Varney (squid808)](https://github.com/squid808). Kudos to Spencer!

### Is the Canvas API included?
No. You'll have to generate it yourself for now.

## How To Use
Clone this repository. Open the Convert-CanvasApiToPowershell.ps1 file, and call Convert-CanvasApiToPowershell. The cmdlet will return the generated document so you can do with it whatever you'd like, for instance:

```
PS C:> . .\Convert-CanvasApiToPowershell.ps1
PS C:> $Generated = Convert-CanvasApiToPowershell
PS C:> $Generated | Out-File ".\CanvasApi.ps1"
#or
PS C:> $Generated | Set-Clipboard
```

Then run one of the methods, and it *should* work. If not, this is open source. Let me know or fix it yourself :)

## What are the files here?

##### Convert-CanvasApiToPowershell.ps1
This script automates the creation of a Powershell client for the Instructure Canvas learning management system. It parses the [Canvas Swagger API Specificaqtion](https://canvas.instructure.com/doc/api/api-docs.json) and converts the data into PowerShell cmdlets.

At the time of writing, the result should be considered 'usable'. If not, this is open source. Let me know or fix it yourself :)

##### CanvasApiMain.ps1
This script contains the primary authentication bits and API calls for the main Canvas API. This will be combined in to the generated document.

##### CanvasDataApi.ps1
This script contains wrappers for the Canvas Data API and some companion functions that can be used to ease the burden of working with the Canvas Data APIs.

Good luck, and enjoy!

##### Notes about uploading files
Apparently to upload files for things like the SIS import you may need to handle the uploading outside of the generic methods provided by PowerShell; this is to allow the uploading of both params and files for a multipart/form-data request. For an example on how to handle this, please see a manually corrected version of Post-CanvasSisImports in this [Gist for Post-CanvasSisImports](https://gist.github.com/squid808/4cf31d1419a0a4771bb271eb6a32366a). Again, please note that this kind of method handling would be needed for any functions wherein you are uploading files, though I have not tested any others.

If you only need to upload a file with no params, you can simply use Invoke-Webrequest with the -InFile param.
