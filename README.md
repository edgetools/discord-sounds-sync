# overview

finds discord notification sounds in the local cache and overwrites them

# behavior

upon running, the discord file cache will be MD5 hashed and any known files will be identified

each known file will then be overwritten by a corresponding custom file from the `CustomItemsDirPath`

if a custom file is not provided, the original file will be copied into the `CustomItemsDirPath` to allow for editing

# supported custom item types

each custom item must match one of these filenames:

`Call1.wav`

`Call2.wav`

`EndCall.wav`

`JoinCall.wav`

`LeaveChannel.wav`

`Notification.wav`

`StreamStarted.wav`

`StreamEnded.wav`

# usage

## running for the first time

specify the `CustomItemsDirPath`

```
.\discord-sounds-sync.ps1 -CustomItemsDirPath DIR_PATH
```

example:

```
.\discord-sounds-sync.ps1 -CustomItemsDirPath 'C:\my_custom_sounds_path'
```

## using the database cache

after the first time being ran, settings and file hashes will be cached to `$env:LOCALAPPDATA\edgetools\discord-sounds-sync\database.ps1xml`

additional runs will not require the `CustomItemsDirPath` option

```
.\discord-sounds-sync.ps1
```

## recreating the database cache

to re-create the database cache, enable switch `RecreateDB` along with `CustomItemsDirPath`

```
.\discord-sounds-sync.ps1 -CustomItemsDirPath DIR_PATH -RecreateDB
```

## clearing the discord cache

to clear the discord cache, add switch `-ClearCache`

```
.\discord-sounds-sync.ps1 -ClearCache
```
