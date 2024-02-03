# [CmdletBinding()]
# param(
#     [Parameter(Mandatory = $true)]
#     [string] $SourceDir,

#     [string] $KnownFilesPath = '.\known_files.json',

#     [ValidateSet('Call1', 'Call2', 'EndCall', 'JoinChannel', 'LeaveChannel', 'Notification', 'StreamStarted', 'StreamEnded')]
#     [string] $SoundType
# )

$DebugPreference = 'Continue'

function load_database_from_file() {
    $database_file_path = '.\database.ps1xml'
    if ((Test-Path -Path $database_file_path -PathType Leaf) -eq $True) {
        $database_file = Import-Clixml $database_file_path
        return Write-Output $database_file -NoEnumerate
    }
}

function save_database_to_file() {
    param($database)
    $database_file_path = '.\database.ps1xml'
    $database | Export-Clixml $database_file_path
}

function load_cache_items() {
    param($Items)

    $cache_dir = Join-Path $env:APPDATA -ChildPath 'discord\Cache\Cache_Data'

    # Get-ChildItem -Path $cache_dir -Filter 'f_*' -File | ForEach-Object {
    #     $Items[$_.BaseName] = @{
    #         Path = $_.FullName
    #     }
    # }

    Get-ChildItem -Path $cache_dir -Filter 'f_*' -File | Select-Object -First 10 | ForEach-Object {
        if ($null -ne $Items) {
            if ($null -eq ($Items[$_.BaseName])) {
                $Items[$_.BaseName] = @{
                    Path = $_.FullName
                }
            }
        }
    }
}

function calculate_item_hashes() {
    param($Items)

    function get_random_string($Length) {
        $charset = [char]'A'..[char]'Z' + [char]'a'..[char]'z' | ForEach-Object { [char]$_ }
        $charset += 0..9
        -join ($charset | Get-Random -Count $Length)
    }
    
    function generate_job_prefix() {
        # abcd123-
        (get_random_string 7) + '-'
    }
    
    function format_job_name($Prefix, $ItemName) {
        "$Prefix$ItemName"
    }
    
    function start_hash_job($JobName, $ItemName, $ItemPath) {
        Start-Job -Name $JobName -ScriptBlock {
            param($ItemName, $ItemPath)
            $filehash = Get-FileHash -Path $ItemPath -Algorithm MD5 | Select-Object -ExpandProperty Hash
            [pscustomobject]@{
                ItemName = $ItemName
                ItemHash = $filehash
            }
        } -ArgumentList $ItemName, $ItemPath | Out-Null
    }
    
    function get_jobs($Prefix) {
        Get-Job -Name "$Prefix*"
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
    
    function read_hashes_from_completed_jobs($completed_jobs) {
        $hashed_items = @()
        $hashed_items += $completed_jobs | Receive-Job | ForEach-Object { [pscustomobject]@{ ItemName = $_.ItemName; ItemHash = $_.ItemHash } }
        return Write-Output $hashed_items -NoEnumerate
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

    function find_items_without_hashes() {
        param($Items)

        $items_without_hashes = @{}

        foreach ($cached_item in $Items.GetEnumerator()) {
            if ($null -eq $cached_item.Value.Hash) {
                $items_without_hashes[$cached_item.Key] = $cached_item.Value
            }
        }

        Write-Output $items_without_hashes -NoEnumerate
    }

    $items_without_hashes = find_items_without_hashes $Items
    
    $items_to_hash = [System.Collections.Stack]::new($items_without_hashes.Keys)
    
    $job_prefix = generate_job_prefix
    
    $should_run_hashfile_process_loop = $true
    
    while ($should_run_hashfile_process_loop -eq $true) {
        $jobs = get_jobs $job_prefix
        
        $running_jobs = get_running_jobs $jobs
        
        $maximum_parallel_jobs_count = 10
        
        $should_start_more_jobs = should_start_more_jobs $running_jobs.Count $maximum_parallel_jobs_count $items_to_hash.Count
        
        if ($should_start_more_jobs -eq $true) {
            $number_of_jobs_to_start = number_of_jobs_to_start $running_jobs.Count $maximum_parallel_jobs_count $items_to_hash.Count
        
            for ($i = 0; $i -lt $number_of_jobs_to_start; $i++) {
                $item_to_hash_name = $items_to_hash.Pop()
                $item_to_hash_path = $Items[$item_to_hash_name].Path
                $job_name = format_job_name $job_prefix $item_to_hash_name
                Write-Debug "Starting job $job_name"
                start_hash_job $job_name $item_to_hash_name $item_to_hash_path
            }
        }
        
        $completed_jobs = get_completed_jobs $jobs
        
        $should_process_completed_jobs = should_process_completed_jobs $completed_jobs.Count
        
        if ($should_process_completed_jobs -eq $true) {
            $hashed_items = read_hashes_from_completed_jobs $completed_jobs
            foreach ($hashed_item in $hashed_items) {
                $Items[$hashed_item.ItemName].Hash = $hashed_item.ItemHash
                Write-Debug "Hashed file $($hashed_item.ItemName)"
            }
            remove_completed_jobs $completed_jobs
        }
    
        $should_run_hashfile_process_loop = should_run_hashfile_process_loop $jobs.Count $should_start_more_jobs
    
        Start-Sleep -Milliseconds 100
    }
}

$database = load_database_from_file

if ($null -eq $database) {
    $database = @{
        Items = @{}
        SourceFiles = @{}
        FileTypes = @(
            @{
                Name = 'Call1'
                Hash = '84A1B4E11D634DBFA1E5DD97A96DE3AD'
            },
            @{
                Name = 'Call2'
                Hash = 'C6E92752668DDE4EEE5923D70441579F'
            },
            @{
                Name = 'EndCall'
                Hash = '7E125DC075EC6E5AE796E4C3AB83ABB3'
            },
            @{
                Name = 'JoinChannel'
                Hash = '5DD43C946894005258D85770F0D10CFF'
            },
            @{
                Name = 'LeaveChannel'
                Hash = '4FCFEB2CBA26459C4750E60F626CEBDC'
            },
            @{
                Name = 'Notification'
                Hash = 'DD920C06A01E5BB8B09678581E29D56F'
            },
            @{
                Name = 'StreamStarted'
                Hash = '9CA817F41727EDC1B2F1BC4F1911107C'
            },
            @{
                Name = 'StreamEnded'
                Hash = '4E30F98AA537854F79F49A76AF822BBC'
            }
        )
    }
}

load_cache_items $database.Items

calculate_item_hashes $database.Items

save_database_to_file $database

$database

# calculate_item_hashes $database.Items

# $files_database = [System.Collections.Generic.List[psobject]]@()

# $known_files = Get-Content $KnownFilesPath -Raw | ConvertFrom-Json

# foreach ($known_file in $known_files) {
#     $new_entry = [PSCustomObject]@{
#         KnownFileName = $known_file.Name
#         KnownFileHash = $known_file.ItemHash
#     }
#     $files_database.Add($new_entry)
# }

# Write-Output $files_database -NoEnumerate