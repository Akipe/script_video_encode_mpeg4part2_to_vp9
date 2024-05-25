Set-Variable APP_NAME -Option Constant -Value "convert_avi_vp9"

Set-Variable DIVX_FILE_EXTENSION -Option Constant -Value "*.avi"

Set-Variable LOG_DATE_FORMAT -Option Constant -Value "dd/MM/yyyy HH:mm:ss:fff tt"
Set-Variable LOG_ERROR_COLOR -Option Constant -Value Red
Set-Variable LOG_INFO_COLOR -Option Constant -Value DarkGray

Set-Variable CONVERSION_VIDEO_MINIMUM_RATE -Option Constant -Value "500k"
Set-Variable CONVERSION_VIDEO_MAXIMUM_RATE -Option Constant -Value "1900k"
Set-Variable CONVERSION_VIDEO_AVERAGE_RATE -Option Constant -Value "1100k"
Set-Variable CONVERSION_AUDIO_RATE -Option Constant -Value "64k"

Set-Variable PATH_SEPARATOR -Option Constant -Value ";"

Function Get-DirectoriesToConvert()
{
    $PathsInstruction = Read-Host -Prompt ("Directory to convert all files (seperates by " + $PATH_SEPARATOR + ")")
    $ListPaths = $PathsInstruction -split "$PATH_SEPARATOR"
    return $ListPaths
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
        Write-Host -ForegroundColor $LOG_ERROR_COLOR ("Error: " + $_.Exception.Message)
    }
}

Function Use-ConvertToVP9([io.fileinfo] $File)
{
    ffmpeg `
	-nostdin `
        -init_hw_device qsv=hw `
        -filter_hw_device hw `
        -i $File.FullName `
        -c:a libopus `
        -b:a $CONVERSION_AUDIO_RATE `
        -vf 'hwupload=extra_hw_frames=64,format=qsv' `
        -c:v vp9_qsv `
        -profile:v profile0 `
        -speed 0 `
        -b:v $CONVERSION_VIDEO_AVERAGE_RATE `
        -minrate $CONVERSION_VIDEO_MINIMUM_RATE `
        -maxrate $CONVERSION_VIDEO_MAXIMUM_RATE `
        -preset veryslow `
        ($File.FullName.Remove($File.FullName.Length - $File.Extension.Length) + '.webm')

    # ffmpeg -init_hw_device qsv=hw -filter_hw_device hw -i $_.FullName -c:a libopus -b:a 64k -vf 'hwupload=extra_hw_frames=64,format=qsv' -c:v vp9_qsv -profile:v profile0 -speed 0 -b:v 1100k -minrate 500k -maxrate 1900k -preset veryslow ($_.FullName.Remove($_.FullName.Length - $_.Extension.Length) + '.webm')
}

Function Use-RunApp()
{
    Write-LogMessage "Starting new conversion"
    Write-LogMessage ('Writing logs at "' + $(Get-LogPath) + '"')

    $Paths = Get-DirectoriesToConvert

    Write-LogMessage ('Directories to process : "' + $($Paths -join '" "') + '"')

    $Paths | Foreach-Object {
        $CurrentPath = $_

        Write-LogMessage ('Path to process : "' + $CurrentPath + '"')
        
        Get-ChildItem $CurrentPath -Filter $DIVX_FILE_EXTENSION | Foreach-Object {
            $File = $_

            if ($File -is [io.fileinfo]) {
                Write-LogMessage ('Starting conversion of "' + $File + '" ...')
        
                Use-ConvertToVP9 $File
        
                Write-LogMessage ('Conversion complete of "' + $File + '"')
            }
        }

        Write-LogMessage ('End of conversion of "' + $CurrentPath + '"')
    }


    Write-LogMessage "Convertion finished"
}

Use-RunApp
