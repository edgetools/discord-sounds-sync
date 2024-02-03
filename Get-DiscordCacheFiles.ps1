function get_cache_dir_path() {
    Join-Path $env:APPDATA -ChildPath 'discord\Cache\Cache_Data'
}

function get_cache_file_names_and_paths($cache_dir_path) {
    Get-ChildItem -Path $cache_dir_path -Filter 'f_*' -File | ForEach-Object { [PSCustomObject]@{ FileName = $_.Name; FilePath = $_.FullName } }
}

$cache_dir_path = get_cache_dir_path

Write-Output (get_cache_file_names_and_paths $cache_dir_path)