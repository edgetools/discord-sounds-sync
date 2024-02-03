param($target_hashes, $hashed_files)

$found_files_output = [System.Collections.ArrayList]@()

foreach ($target_hash in $target_hashes) {
    $found_files = @($hashed_files | Where-Object { $_.FileHash -ceq $target_hash.FileHash })
    if ($found_files.Count -gt 0) {
        foreach ($found_file in $found_files) {
            $found_file_object = [PSCustomObject]@{
                FileName = $found_file.FileName
                FilePath = $found_file.FilePath
                FileHash = $found_file.FileHash
                TargetType = $target_hash.Name
            }
            $found_files_output.Add($found_file_object) | Out-Null
        }
    }
}

Write-Output $found_files_output.ToArray() -NoEnumerate
