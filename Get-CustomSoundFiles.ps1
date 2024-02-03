param($custom_sounds_dir_path)

function get_custom_sounds_file_names_and_paths($dir_path) {
    Get-ChildItem -Path $dir_path -Filter '*.wav' -File | ForEach-Object { [PSCustomObject]@{ FileName = $_.BaseName; FilePath = $_.FullName } }
}

function get_known_sounds($known_sounds_file_path) {
    Get-Content -Path $known_sounds_file_path -Raw | ConvertFrom-Json
}

$known_sounds = get_known_sounds '.\known_sounds.json'

$custom_sounds_file_names_and_paths = get_custom_sounds_file_names_and_paths $custom_sounds_dir_path

$found_known_custom_sounds = [System.Collections.ArrayList]@()

foreach ($custom_sound in $custom_sounds_file_names_and_paths) {
    $found_known_sound = $known_sounds | Where-Object { $_.Name -eq $custom_sound.FileName }
    if ($null -ne $found_known_sound) {
        $found_known_custom_sounds.Add([PSCustomObject]@{
            FileName = $custom_sound.FileName
            FilePath = $custom_sound.FilePath
            TargetHash = $found_known_sound.FileHash
            TargetType = $found_known_sound.Name
        }) | Out-Null
    }
}

Write-Output $found_known_custom_sounds.ToArray() -NoEnumerate
