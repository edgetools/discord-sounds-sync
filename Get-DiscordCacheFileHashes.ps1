param($cache_file_names_and_paths)

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

function read_hashed_files_from_completed_jobs($completed_jobs) {
    $completed_jobs | Receive-Job | ForEach-Object { [pscustomobject]@{ FileName = $_.FileName; FilePath = $_.FilePath; FileHash = $_.FileHash } }
}

function remove_completed_jobs($completed_jobs) {
    $completed_jobs | Remove-Job
}

function should_run_hashfile_process_loop($total_jobs_count, $should_start_more_jobs) {
    if (($total_jobs_count -eq 0) -and ($should_start_more_jobs -eq $false)) {
        return $false
    } else {
        return $true
    }
}

$cache_file_names_and_paths_stack = [System.Collections.Stack]::new($cache_file_names_and_paths)

$job_prefix = generate_job_prefix

$hashed_files_list = [System.Collections.ArrayList]@()

$should_run_hashfile_process_loop = $true

while ($should_run_hashfile_process_loop -eq $true) {
    $jobs = get_jobs $job_prefix
    
    $running_jobs = get_running_jobs $jobs
    
    $maximum_parallel_jobs_count = 10
    
    $should_start_more_jobs = should_start_more_jobs $running_jobs.Count $maximum_parallel_jobs_count $cache_file_names_and_paths_stack.Count
    
    if ($should_start_more_jobs -eq $true) {
        $number_of_jobs_to_start = number_of_jobs_to_start $running_jobs.Count $maximum_parallel_jobs_count $cache_file_names_and_paths_stack.Count
    
        for ($i = 0; $i -lt $number_of_jobs_to_start; $i++) {
            $cache_file_name_and_path = $cache_file_names_and_paths_stack.Pop()
            $job_name = format_job_name $job_prefix $cache_file_name_and_path.FileName
            Write-Debug "Starting job $job_name"
            start_hash_job $job_name $cache_file_name_and_path.FileName $cache_file_name_and_path.FilePath
        }
    }
    
    $completed_jobs = get_completed_jobs $jobs
    
    $should_process_completed_jobs = should_process_completed_jobs $completed_jobs.Count
    
    if ($should_process_completed_jobs -eq $true) {
        $hashed_files_from_completed_jobs = read_hashed_files_from_completed_jobs $completed_jobs
        $hashed_files_list.Add($hashed_files_from_completed_jobs) | Out-Null
        remove_completed_jobs $completed_jobs
        $hashed_files_from_completed_jobs | ForEach-Object { Write-Debug "Hashed file $($_.FileName)" }
    }

    $should_run_hashfile_process_loop = should_run_hashfile_process_loop $jobs.Count $should_start_more_jobs

    Start-Sleep -Milliseconds 100
}

Write-Output $hashed_files_list.ToArray()
