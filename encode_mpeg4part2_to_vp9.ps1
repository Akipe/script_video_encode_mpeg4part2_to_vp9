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
$Fun_Get_WorkspaceFolders = ${function:Get-WorkspaceFolders}.ToString()

Function Get-LogPath()
{
    return "$ENV:AppData\$APP_NAME.log"
}
$Fun_Get_LogPath = ${function:Get-LogPath}.ToString()

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
        # Write-Host $Content
    } Catch {
        Write-Host -ForegroundColor $LOG_ERROR_COLOR (
            "Error: " + $_.Exception.Message
        )
    }
}
$Fun_Write_LogMessage = ${function:Write-LogMessage}.ToString()

Function Get-FullNameWithoutExtension([io.fileinfo] $File)
{
    return $File.FullName.Remove($File.FullName.Length - $File.Extension.Length)
}
$Fun_Get_FullNameWithoutExtension = ${function:Get-FullNameWithoutExtension}.ToString()

Function Use-EncodeToVP9([io.fileinfo] $File, $FileNumber)
{
    $EncodingCommand = "ffmpeg " +
        "-nostdin " +
        "-init_hw_device qsv=hw " +
        "-filter_hw_device hw " +
        "-i '" + $File.FullName + "' " +
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
        "'" +
        ((Get-FullNameWithoutExtension $File) + '.webm') +
        "'"
    
    Write-LogMessage ("[File $FileNumber] Encoding command : " + $EncodingCommand)
    Invoke-Expression $EncodingCommand
}
$Fun_Use_EncodeToVP9 = ${function:Use-EncodeToVP9}.ToString()

# App

Function Use-RunApp()
{
    Write-LogMessage "Starting a new encoding session"
    Write-LogMessage ('Log file location : "' + $(Get-LogPath) + '"')
    $EncoderParallel = Read-Host -Prompt "How many parallel encodings do you want ?"
    Write-LogMessage ('Number of parallel encodings : "' + $EncoderParallel + '"')

    $Paths = Get-WorkspaceFolders 'List of folders where all encoding for MPEG-4 Part 2 (DivX) videos is performed (seperated by a ;)' ";"

    Write-LogMessage ('Directories to be processed : "' + $($Paths -join '" "') + '"')

    $Paths | Foreach-Object {
        $CurrentPath = $_

        Write-LogMessage ('Start of processing for the directory : "' + $CurrentPath + '"')
        
        $VideosToEncode = Get-ChildItem $CurrentPath -Filter $DIVX_FILE_EXTENSION
        
        $VideosToEncode | Foreach-Object -ThrottleLimit $EncoderParallel -Parallel {
            $File = $_

            $FileNumber = (($using:VideosToEncode).IndexOf($File) + 1);
            
            Set-Variable APP_NAME -Option Constant -Value $using:APP_NAME
            Set-Variable DIVX_FILE_EXTENSION -Option Constant -Value $using:DIVX_FILE_EXTENSION
            Set-Variable LOG_DATE_FORMAT -Option Constant -Value $using:LOG_DATE_FORMAT
            Set-Variable LOG_ERROR_COLOR -Option Constant -Value $using:LOG_INFO_COLOR
            Set-Variable LOG_INFO_COLOR -Option Constant -Value DarkGray
            Set-Variable ENCODER_VIDEO_MINIMUM_RATE -Option Constant -Value $using:ENCODER_VIDEO_MINIMUM_RATE
            Set-Variable ENCODER_VIDEO_MAXIMUM_RATE -Option Constant -Value $using:ENCODER_VIDEO_MAXIMUM_RATE
            Set-Variable ENCODER_VIDEO_AVERAGE_RATE -Option Constant -Value $using:ENCODER_VIDEO_AVERAGE_RATE
            Set-Variable ENCODER_AUDIO_RATE -Option Constant -Value $using:ENCODER_AUDIO_RATE

            ${function:Get-WorkspaceFolders} = $using:Fun_Get_WorkspaceFolders
            ${function:Get-LogPath} = $using:Fun_Get_LogPath
            ${function:Write-LogMessage} = $using:Fun_Write_LogMessage
            ${function:Get-FullNameWithoutExtension} = $using:Fun_Get_FullNameWithoutExtension
            ${function:Use-EncodeToVP9} = $using:Fun_Use_EncodeToVP9

            if ($File -is [io.fileinfo]) {
                Write-LogMessage ('[File ' + $FileNumber + '] Starting conversion for "' + $File + '" ...')
                Use-EncodeToVP9 $File $FileNumber
                Write-LogMessage ('[File ' + $FileNumber + '] Conversion completed for "' + $File + '"')
            }
        }

        Write-LogMessage ('Complete conversion of all files inside "' + $CurrentPath + '"')
    }


    Write-LogMessage 'Convertion complete for "' + $($Paths -join '" "') + '".'
}

Use-RunApp
