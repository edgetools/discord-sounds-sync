param($custom_sounds_dir)

$custom_sounds_files = .\Get-CustomSoundFiles.ps1 $custom_sounds_dir
$custom_sounds_hashes = .\Get-FileHashes.ps1 $custom_sounds_files

$known_sounds = Get-Content '.\known_sounds.json' -Raw | ConvertFrom-Json


$cache_files = .\Get-DiscordCacheFiles.ps1
$cache_files_hashes = .\Get-FileHashes.ps1 $cache_files

