# Constants

Set-Variable APP_NAME -Option Constant -Value "encode_mpeg4part2_to_vp9"
Set-Variable DIVX_FILE_EXTENSION -Option Constant -Value "*.avi"
Set-Variable LOG_DATE_FORMAT -Option Constant -Value "dd/MM/yyyy HH:mm:ss:fff tt"
Set-Variable LOG_ERROR_COLOR -Option Constant -Value Red
Set-Variable LOG_INFO_COLOR -Option Constant -Value DarkGray
Set-Variable ENCODER_VIDEO_MINIMUM_RATE -Option Constant -Value "500k"
Set-Variable ENCODER_VIDEO_MAXIMUM_RATE -Option Constant -Value "1900k"
Set-Variable ENCODER_VIDEO_AVERAGE_RATE -Option Constant -Value "1100k"
Set-Variable ENCODER_AUDIO_RATE -Option Constant -Value "64k"

# Instructions

Function Get-WorkspaceFolders([string] $InstructionMessage, [string] $PathSeparator)
{
    $FoldersToBeParsed = Read-Host -Prompt $InstructionMessage
    $ListFolders = $FoldersToBeParsed -split "$PathSeparator"

    return $ListFolders
}

Function Get-LogPath()
{
    return "$ENV:AppData\$APP_NAME.log"
}

Function Write-LogMessage()
{
    param(
        [Parameter(Mandatory=$true)] [string] $Message
    )

    Try {
        $Date = (Get-Date).ToString($LOG_DATE_FORMAT)
        $Content = "$Date - $Message"

        Add-Content -Path $(Get-LogPath) -Value $Content
        Write-Host -ForegroundColor $LOG_INFO_COLOR $Content
    } Catch {
        Write-Host -ForegroundColor $LOG_ERROR_COLOR (
            "Error: " + $_.Exception.Message
        )
    }
}

Function Get-FullNameWithoutExtension([io.fileinfo] $File)
{
    return $File.FullName.Remove($File.FullName.Length - $File.Extension.Length)
}

Function Use-EncodeToVP9([io.fileinfo] $File, $FileNumber)
{
    $EncodingCommand = "ffmpeg " +
        "-nostdin " +
        "-init_hw_device qsv=hw " +
        "-filter_hw_device hw " +
        '-i "' + $File.FullName + '" ' +
        "-c:a libopus " +
        "-b:a $ENCODER_AUDIO_RATE " +
        "-vf 'hwupload=extra_hw_frames=64,format=qsv' " +
        "-c:v vp9_qsv " +
        "-profile:v profile0 " +
        "-speed 0 " +
        "-b:v $ENCODER_VIDEO_AVERAGE_RATE " +
        "-minrate $ENCODER_VIDEO_MINIMUM_RATE " +
        "-maxrate $ENCODER_VIDEO_MAXIMUM_RATE " +
        "-preset veryslow " +
        '"' +
        ((Get-FullNameWithoutExtension $File) + '.webm') +
        '"'
    
    Write-LogMessage ("[$FileNumber] Encoding command : " + $EncodingCommand)
    Invoke-Expression $EncodingCommand
}

# App

Function Use-RunApp()
{
    Write-LogMessage "Starting a new encoding session"
    Write-LogMessage ('Log file location : "' + $(Get-LogPath) + '"')

    $Paths = Get-WorkspaceFolders 'List of folders where all encoding for MPEG-4 Part 2 (DivX) videos is performed (seperated by a ;)' ";"

    Write-LogMessage ('Directories to be processed : "' + $($Paths -join '" "') + '"')

    $Paths | Foreach-Object {
        $CurrentPath = $_

        Write-LogMessage ('Start of processing for the directory : "' + $CurrentPath + '"')
        
        $VideosToEncode = Get-ChildItem $CurrentPath -Filter $DIVX_FILE_EXTENSION
        
        $VideosToEncode | Foreach-Object {
            $File = $_
            $FileNumber = ($VideosToEncode.IndexOf($File) + 1);

            if ($File -is [io.fileinfo]) {
                Write-LogMessage ('[' + $FileNumber + '/' + $VideosToEncode.Length + '] Starting conversion for "' + $File + '" ...')
                Use-EncodeToVP9 $File ("" + $FileNumber + '/' + $VideosToEncode.Length)
                Write-LogMessage ('[' + $FileNumber + '/' + $VideosToEncode.Length + '] Conversion completed for "' + $File + '"')
            }
        }

        Write-LogMessage ('Complete conversion of all files inside "' + $CurrentPath + '"')
    }


    Write-LogMessage 'Convertion complete for "' + $($Paths -join '" "') + '".'
}

Use-RunApp
