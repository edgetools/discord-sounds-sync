
function get_cache_dir_path() {
    Join-Path $env:APPDATA -ChildPath 'discord\Cache\Cache_Data'
}

function get_cache_file_names_and_paths($cache_dir_path) {
    Get-ChildItem -Path $cache_dir_path -Filter 'f_*' -File | ForEach-Object { [PSCustomObject]@{ FileName = $_.Name; FilePath = $_.FullName } }
}

function get_random_string($length) {
    $charset = [char]'A'..[char]'Z' + [char]'a'..[char]'z' | ForEach-Object { [char]$_ }
    $charset += 0..9
    -join ($charset | Get-Random -Count $length)
}

function generate_job_prefix() {
    # abcd123-
    (get_random_string 7) + '-'
}

function format_job_name($prefix, $filename) {
    "$prefix$filename"
}

function start_hash_job($jobname, $filename, $filepath) {
    Start-Job -Name $jobname -ScriptBlock {
        param($filename, $filepath)
        $filehash = Get-FileHash -Path $filepath -Algorithm MD5 | Select-Object -ExpandProperty Hash
        [pscustomobject]@{
            FileName = $filename
            FilePath = $filepath
            FileHash = $filehash
        }
    } -ArgumentList $filename, $filepath | Out-Null
}

function get_jobs($prefix) {
    Get-Job -Name "$prefix*"
}

function get_completed_jobs($jobs) {
    $jobs | Where-Object { $_.State -eq 'Completed' }
}

function get_running_jobs($jobs) {
    $jobs | Where-Object { $_.State -eq 'Running' }
}

function should_start_more_jobs($jobs_running_count, $maximum_parallel_jobs_count, $remaining_file_count) {
    if (($jobs_running_count -lt $maximum_parallel_jobs_count) -and ($remaining_file_count -gt 0)) {
        return $true
    } else {
        return $false
    }
}

function number_of_jobs_to_start($jobs_running_count, $maximum_parallel_jobs_count, $remaining_file_count) {
    $number_of_jobs_to_start = $maximum_parallel_jobs_count - $jobs_running_count
    if ($number_of_jobs_to_start -gt $remaining_file_count) {
        $remaining_file_count
    } else {
        $number_of_jobs_to_start
    }
}

function should_process_completed_jobs($completed_jobs_count) {
    if ($completed_jobs_count -gt 0) {
        return $true
    } else {
        return $false
    }
}

function receive_completed_jobs($completed_jobs) {
    $completed_jobs | Receive-Job | ForEach-Object { [pscustomobject]@{ FileName = $_.FileName; FilePath = $_.FilePath; FileHash = $_.FileHash } }
}

$cache_dir_path = get_cache_dir_path
$cache_file_names_and_paths_stack = [System.Collections.Stack]::new((get_cache_file_names_and_paths $cache_dir_path | Select-Object -First 3))

$job_prefix = generate_job_prefix

$jobs = get_jobs $job_prefix

$running_jobs = get_running_jobs $jobs

$maximum_parallel_jobs_count = 5

$should_start_more_jobs = should_start_more_jobs $running_jobs.Count $maximum_parallel_jobs_count $cache_file_names_and_paths_stack.Count

if ($should_start_more_jobs -eq $true) {
    $number_of_jobs_to_start = number_of_jobs_to_start $running_jobs.Count $maximum_parallel_jobs_count $cache_file_names_and_paths_stack.Count

    for ($i = 0; $i -lt $number_of_jobs_to_start; $i++) {
        $cache_file_name_and_path = $cache_file_names_and_paths_stack.Pop()
        $job_name = format_job_name $job_prefix $cache_file_name_and_path.FileName
        start_hash_job $job_name $cache_file_name_and_path.FileName $cache_file_name_and_path.FilePath
    }
}

$completed_jobs = get_completed_jobs $jobs

$hashed_files = [System.Collections.ArrayList]@()

$should_process_completed_jobs = should_process_completed_jobs $completed_jobs.Count

if ($should_process_completed_jobs -eq $true) {
    $received_jobs = receive_completed_jobs $completed_jobs
    $hashed_files.Add($received_jobs) | Out-Null
}

$hashed_files
